# Blockchain-Enabled Gig Worker Payments

A decentralized payment system for gig workers built on the Stacks blockchain using Clarity smart contracts.

## Overview

This project implements a blockchain-based payment system that enables secure, transparent, and automated payments for gig workers. The system ensures fair compensation, dispute resolution, and trust between clients and workers through smart contracts.

## Features

### Core Functionality
- **Job Posting & Management**: Clients can post jobs with detailed requirements and escrow payments
- **Worker Registration**: Gig workers can register and build reputation profiles
- **Escrow System**: Automatic escrow of payments until job completion
- **Dispute Resolution**: Built-in mechanisms for handling payment disputes
- **Reputation Tracking**: Rating system for both clients and workers
- **Automated Payments**: Smart contract-based payment release upon job completion

### Security Features
- **Decentralized Trust**: No central authority controlling payments
- **Transparent Transactions**: All payments and ratings recorded on-chain
- **Escrow Protection**: Funds locked until job requirements are met
- **Time-locked Releases**: Automatic payment release after specified periods

## Smart Contracts

### 1. Gig Job Manager Contract
Handles job postings, worker assignments, and job lifecycle management:
- Job creation with escrow deposits
- Worker application and selection process  
- Job status tracking and completion verification
- Payment release mechanisms

### 2. Worker Registry Contract
Manages worker profiles, ratings, and reputation:
- Worker registration and profile management
- Skill verification and certification
- Rating and review system
- Reputation score calculations

## Architecture

```
Client Posts Job → Escrow Payment → Worker Applies → Job Assignment
     ↓
Job Completion → Verification → Payment Release → Rating Update
```

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) - For local development
- [Node.js](https://nodejs.org/) - For running tests
- Stacks wallet for deployment

### Installation
```bash
git clone <repository-url>
cd gig-worker-payments
npm install
```

### Development
```bash
clarinet check          # Verify contract syntax
clarinet test           # Run contract tests  
clarinet console        # Interactive testing
```

## Usage

### For Clients
1. Post a job with requirements and payment amount
2. Review worker applications and select preferred worker
3. Monitor job progress through smart contract events
4. Approve completion and release payment
5. Rate the worker's performance

### For Workers
1. Register profile with skills and experience
2. Browse available jobs and submit applications
3. Complete assigned work according to specifications
4. Request payment release upon completion
5. Build reputation through consistent quality work

## Contract Functions

### Job Management
- `create-job`: Post new job with escrow
- `apply-for-job`: Worker applies for available job
- `assign-job`: Client assigns job to selected worker
- `complete-job`: Mark job as completed
- `release-payment`: Release escrowed funds

### Worker Management
- `register-worker`: Register new worker profile
- `update-profile`: Update worker information
- `rate-worker`: Submit worker rating
- `get-worker-reputation`: Retrieve worker reputation score

## Testing

Run the test suite:
```bash
npm test
```

Individual contract tests:
```bash
clarinet test tests/gig-job-manager_test.ts
clarinet test tests/worker-registry_test.ts
```

## Deployment

Deploy to Stacks testnet:
```bash
clarinet deploy --testnet
```

## Contributing

1. Fork the repository
2. Create feature branch
3. Make changes and add tests
4. Ensure all tests pass
5. Submit pull request

## License

This project is licensed under the MIT License.

## Contact

For questions or support, please open an issue in the repository.