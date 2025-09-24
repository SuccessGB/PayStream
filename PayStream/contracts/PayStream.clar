;; PayStream - Continuous Payment Streaming Protocol
;; A smart contract for seamless payment streams and automated value transfer on Stacks

;; Constants
(define-constant protocol-owner tx-sender)
(define-constant err-owner-only (err u600))
(define-constant err-stream-not-found (err u601))
(define-constant err-balance-insufficient (err u602))
(define-constant err-invalid-params (err u603))
(define-constant err-stream-terminated (err u604))
(define-constant err-unauthorized (err u605))

;; Data Variables
(define-data-var protocol-fee-percentage uint u300) ;; 3% protocol fee
(define-data-var minimum-stream-value uint u1000) ;; Minimum 1000 micro-STX per stream

;; Data Maps
(define-map payment-streams
    { stream-id: uint }
    {
        streamer: principal,
        recipient: principal,
        tokens-per-block: uint,
        total-allocation: uint,
        start-block: uint,
        final-block: uint,
        released-tokens: uint,
        stream-live: bool
    }
)

(define-map participant-balances
    { participant: principal }
    { available-balance: uint }
)

(define-map stream-tracker
    { tracker-active: bool }
    { stream-count: uint }
)

;; Initialize stream tracker
(map-set stream-tracker { tracker-active: true } { stream-count: u0 })

;; Read-only functions

(define-read-only (get-stream-data (stream-id uint))
    (map-get? payment-streams { stream-id: stream-id })
)

(define-read-only (get-participant-balance (participant principal))
    (default-to u0 (get available-balance (map-get? participant-balances { participant: participant })))
)

(define-read-only (get-protocol-fee-percentage)
    (var-get protocol-fee-percentage)
)

(define-read-only (get-minimum-stream-value)
    (var-get minimum-stream-value)
)

(define-read-only (calculate-withdrawable-tokens (stream-id uint))
    (match (map-get? payment-streams { stream-id: stream-id })
        stream-data
        (let
            (
                (current-block stacks-block-height)
                (start-block (get start-block stream-data))
                (final-block (get final-block stream-data))
                (tokens-per-block (get tokens-per-block stream-data))
                (released-tokens (get released-tokens stream-data))
                (stream-live (get stream-live stream-data))
            )
            (if (and stream-live (>= current-block start-block))
                (let
                    (
                        (elapsed-blocks (if (>= current-block final-block)
                                       (- final-block start-block)
                                       (- current-block start-block)))
                        (total-earned (* elapsed-blocks tokens-per-block))
                    )
                    (if (>= total-earned released-tokens)
                        (ok (- total-earned released-tokens))
                        (ok u0)
                    )
                )
                (ok u0)
            )
        )
        (err err-stream-not-found)
    )
)

;; Public functions

(define-public (fund-account (amount uint))
    (let
        (
            (current-balance (get-participant-balance tx-sender))
        )
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set participant-balances 
            { participant: tx-sender } 
            { available-balance: (+ current-balance amount) }
        )
        (ok true)
    )
)

(define-public (drain-account (amount uint))
    (let
        (
            (current-balance (get-participant-balance tx-sender))
        )
        (asserts! (>= current-balance amount) err-balance-insufficient)
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-set participant-balances 
            { participant: tx-sender } 
            { available-balance: (- current-balance amount) }
        )
        (ok true)
    )
)

(define-public (initiate-payment-stream (recipient principal) (tokens-per-block uint) (stream-duration uint))
    (let
        (
            (stream-id (+ (default-to u0 (get stream-count (map-get? stream-tracker { tracker-active: true }))) u1))
            (total-allocation (* tokens-per-block stream-duration))
            (streamer-balance (get-participant-balance tx-sender))
        )
        ;; Validate inputs
        (asserts! (>= total-allocation (var-get minimum-stream-value)) err-invalid-params)
        (asserts! (> tokens-per-block u0) err-invalid-params)
        (asserts! (> stream-duration u0) err-invalid-params)
        (asserts! (>= streamer-balance total-allocation) err-balance-insufficient)
        
        ;; Lock tokens from streamer balance
        (map-set participant-balances 
            { participant: tx-sender } 
            { available-balance: (- streamer-balance total-allocation) }
        )
        
        ;; Create payment stream
        (map-set payment-streams
            { stream-id: stream-id }
            {
                streamer: tx-sender,
                recipient: recipient,
                tokens-per-block: tokens-per-block,
                total-allocation: total-allocation,
                start-block: stacks-block-height,
                final-block: (+ stacks-block-height stream-duration),
                released-tokens: u0,
                stream-live: true
            }
        )
        
        ;; Update stream tracker
        (map-set stream-tracker { tracker-active: true } { stream-count: stream-id })
        
        (ok stream-id)
    )
)

(define-public (withdraw-stream-tokens (stream-id uint))
    (match (map-get? payment-streams { stream-id: stream-id })
        stream-data
        (let
            (
                (recipient (get recipient stream-data))
                (withdrawable-result (calculate-withdrawable-tokens stream-id))
            )
            (asserts! (is-eq tx-sender recipient) err-unauthorized)
            (asserts! (get stream-live stream-data) err-stream-terminated)
            
            (match withdrawable-result
                withdrawable-amount
                (if (> withdrawable-amount u0)
                    (let
                        (
                            (protocol-fee (/ (* withdrawable-amount (var-get protocol-fee-percentage)) u10000))
                            (net-withdrawal (- withdrawable-amount protocol-fee))
                            (current-released (get released-tokens stream-data))
                        )
                        ;; Transfer to recipient
                        (try! (as-contract (stx-transfer? net-withdrawal tx-sender recipient)))
                        
                        ;; Transfer protocol fee to owner
                        (try! (as-contract (stx-transfer? protocol-fee tx-sender protocol-owner)))
                        
                        ;; Update stream released amount
                        (map-set payment-streams
                            { stream-id: stream-id }
                            (merge stream-data { released-tokens: (+ current-released withdrawable-amount) })
                        )
                        
                        (ok net-withdrawal)
                    )
                    (ok u0)
                )
                error-code
                error-code
            )
        )
        err-stream-not-found
    )
)

(define-public (terminate-payment-stream (stream-id uint))
    (match (map-get? payment-streams { stream-id: stream-id })
        stream-data
        (let
            (
                (streamer (get streamer stream-data))
                (recipient (get recipient stream-data))
                (total-allocation (get total-allocation stream-data))
                (released-tokens (get released-tokens stream-data))
            )
            (asserts! (or (is-eq tx-sender streamer) (is-eq tx-sender recipient)) err-unauthorized)
            (asserts! (get stream-live stream-data) err-stream-terminated)
            
            ;; Process any pending withdrawal for recipient
            (match (calculate-withdrawable-tokens stream-id)
                withdrawable-amount
                (if (> withdrawable-amount u0)
                    (let
                        (
                            (protocol-fee (/ (* withdrawable-amount (var-get protocol-fee-percentage)) u10000))
                            (net-withdrawal (- withdrawable-amount protocol-fee))
                        )
                        (try! (as-contract (stx-transfer? net-withdrawal tx-sender recipient)))
                        (try! (as-contract (stx-transfer? protocol-fee tx-sender protocol-owner)))
                        (map-set payment-streams
                            { stream-id: stream-id }
                            (merge stream-data { released-tokens: (+ released-tokens withdrawable-amount) })
                        )
                        true
                    )
                    true
                )
                error-code
                false
            )
            
            ;; Return unreleased tokens to streamer
            (let
                (
                    (final-released (get released-tokens (unwrap-panic (map-get? payment-streams { stream-id: stream-id }))))
                    (remaining-tokens (- total-allocation final-released))
                    (streamer-balance (get-participant-balance streamer))
                )
                (if (> remaining-tokens u0)
                    (map-set participant-balances 
                        { participant: streamer } 
                        { available-balance: (+ streamer-balance remaining-tokens) }
                    )
                    true
                )
            )
            
            ;; Mark stream as terminated
            (map-set payment-streams
                { stream-id: stream-id }
                (merge stream-data { stream-live: false })
            )
            
            (ok true)
        )
        err-stream-not-found
    )
)

;; Owner functions

(define-public (adjust-protocol-fee (new-fee-percentage uint))
    (begin
        (asserts! (is-eq tx-sender protocol-owner) err-owner-only)
        (asserts! (<= new-fee-percentage u2000) err-invalid-params) ;; Max 20% fee
        (var-set protocol-fee-percentage new-fee-percentage)
        (ok true)
    )
)

(define-public (adjust-minimum-stream-value (new-minimum uint))
    (begin
        (asserts! (is-eq tx-sender protocol-owner) err-owner-only)
        (var-set minimum-stream-value new-minimum)
        (ok true)
    )
)