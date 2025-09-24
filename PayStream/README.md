# PayStream - Continuous Payment Streaming Protocol

PayStream is an innovative smart contract built on the Stacks blockchain that enables continuous, automated payment streaming between parties. It provides a seamless way to distribute payments over time with block-level precision, eliminating the need for manual recurring transactions.

## Features

- **Continuous Payment Streams**: Automated token distribution on a per-block basis
- **Real-Time Value Transfer**: Payments flow continuously without manual intervention
- **Flexible Stream Configuration**: Customizable payment rates and durations
- **Built-in Escrow System**: Secure fund locking with guaranteed payment execution
- **Low Protocol Fees**: Configurable fees (default 3%) to maintain protocol sustainability
- **Dual-Party Control**: Both streamers and recipients can manage stream lifecycle

## Core Concepts

### Payment Streams
A payment stream represents continuous token flow from a streamer to a recipient over a specified period. Each stream contains:
- **Tokens per Block**: Amount of micro-STX distributed each block
- **Stream Duration**: Total number of blocks the stream remains active
- **Total Allocation**: Complete token amount locked for the entire stream period

### Participant Balances
Internal balance management system that provides:
- Efficient token allocation for multiple streams
- Reduced transaction costs through batch operations
- Seamless integration with the streaming mechanism

## Usage Guide

### For Streamers (Payers)

1. **Fund Your Account**
   ```clarity
   (fund-account amount)
   ```
   Deposit STX tokens into protocol account to enable stream creation.

2. **Initiate Payment Stream**
   ```clarity
   (initiate-payment-stream recipient tokens-per-block stream-duration)
   ```
   - `recipient`: Principal address receiving the stream
   - `tokens-per-block`: Micro-STX distributed per block
   - `stream-duration`: Number of blocks for stream duration

3. **Terminate Stream**
   ```clarity
   (terminate-payment-stream stream-id)
   ```
   End an active stream early and recover unreleased tokens.

### For Recipients (Payees)

1. **Withdraw Stream Tokens**
   ```clarity
   (withdraw-stream-tokens stream-id)
   ```
   Claim available tokens from an active payment stream.

### General Functions

1. **Drain Account**
   ```clarity
   (drain-account amount)
   ```
   Withdraw STX tokens from your protocol account balance.

2. **View Stream Data**
   ```clarity
   (get-stream-data stream-id)
   ```
   Retrieve complete information about a specific payment stream.

3. **Calculate Withdrawable Amount**
   ```clarity
   (calculate-withdrawable-tokens stream-id)
   ```
   Determine tokens available for withdrawal from a stream.

## Technical Specifications

### Protocol Parameters
- **Protocol Fee**: 3% (300 basis points) - adjustable by protocol owner
- **Minimum Stream Value**: 1000 micro-STX
- **Maximum Protocol Fee**: 20% (2000 basis points)

### Error Codes
- `u600`: Owner-only function accessed by unauthorized user
- `u601`: Payment stream does not exist
- `u602`: Insufficient balance for requested operation
- `u603`: Invalid parameters provided
- `u604`: Payment stream has been terminated
- `u605`: Unauthorized access to stream operation

### Data Structures

#### Payment Streams
```clarity
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
```

#### Participant Balances
```clarity
{
    participant: principal,
    available-balance: uint
}
```

## Security Features

- **Access Control**: Strict permission validation for all stream operations
- **Fund Protection**: Secure escrow system with automatic token distribution
- **Input Validation**: Comprehensive parameter checking and bounds enforcement
- **Safe Termination**: Proper settlement of all outstanding payments on stream closure
- **Owner Limitations**: Restricted administrative functions with safety constraints

## Use Cases

- **Salary Distribution**: Continuous employee compensation over time
- **Subscription Payments**: Automated recurring service payments
- **Contractor Payments**: Progressive payment for ongoing work
- **Rental Agreements**: Automated property lease payments
- **Investment Distributions**: Regular return payments to investors
- **Content Creator Funding**: Continuous support for creators and artists

## Advanced Features

### Block-Level Precision
Payment calculations are performed at the block level, ensuring precise and predictable token distribution over time.

### Stream Lifecycle Management
Complete control over payment streams from initiation to termination, with automatic settlement of all outstanding amounts.

### Flexible Termination
Both streamers and recipients can terminate streams, providing protection and flexibility for all parties involved.

## Protocol Administration

The protocol owner (contract deployer) has limited administrative capabilities:
- Adjust protocol fee rates (maximum 20%)
- Modify minimum stream value requirements
- Monitor protocol-wide streaming activity

**Important**: Protocol owners cannot access participant funds or interfere with active streams.

## Getting Started

1. Deploy the PayStream contract to the Stacks blockchain
2. Fund protocol account using `fund-account`
3. Create first payment stream using `initiate-payment-stream`
4. Recipients can withdraw tokens as they become available over time

### Gas Optimization
- Efficient storage patterns for reduced transaction costs
- Batch operations through internal balance management
- Optimized calculations for real-time token availability
