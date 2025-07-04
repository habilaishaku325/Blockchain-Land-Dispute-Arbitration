# 🏛️ Blockchain Land Dispute Arbitration

A decentralized platform for resolving land ownership disputes through evidence-based arbitration on the Stacks blockchain.

## 🌟 Features

- 📋 **Dispute Creation**: File land ownership disputes with stake requirements
- 🔍 **Evidence Submission**: Both parties can submit supporting evidence
- ⚖️ **Decentralized Arbitration**: Registered arbitrators vote on disputes
- 💰 **Stake-based Resolution**: Winner takes all staked funds
- 🏆 **Reputation System**: Arbitrators build reputation through participation

## 🚀 Getting Started

### Prerequisites

- Clarinet installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd land-arbitration
clarinet check
```

## 📖 Usage

### For Disputants

#### 1. Create a Dispute 🆕
```clarity
(contract-call? .land-arbitration create-dispute 'ST2DEFENDANT "LAND001" "Boundary dispute over northern fence" u1000000)
```

#### 2. Defendant Stakes Funds 💵
```clarity
(contract-call? .land-arbitration add-defendant-stake u1 u1000000)
```

#### 3. Submit Evidence 📄
```clarity
(contract-call? .land-arbitration submit-evidence u1 "Survey document from 2020 showing clear boundaries")
```

#### 4. Start Arbitration Process ⚡
```clarity
(contract-call? .land-arbitration start-arbitration u1)
```

### For Arbitrators

#### 1. Register as Arbitrator 👨‍⚖️
```clarity
(contract-call? .land-arbitration register-arbitrator)
```

#### 2. Cast Vote on Dispute 🗳️
```clarity
(contract-call? .land-arbitration cast-vote u1 "claimant" "Evidence clearly supports claimant's boundary claim")
```

#### 3. Finalize Dispute (after sufficient votes) ✅
```clarity
(contract-call? .land-arbitration finalize-dispute u1)
```

## 🔍 Query Functions

### Get Dispute Information
```clarity
(contract-call? .land-arbitration get-dispute u1)
```

### Check Arbitrator Details
```clarity
(contract-call? .land-arbitration get-arbitrator-by-address 'ST1ARBITRATOR)
```

### View Vote Details
```clarity
(contract-call? .land-arbitration get-vote u1 u1)
```

## 📊 Contract States

- **open**: Dispute created, waiting for defendant stake
- **evidence**: Both parties staked, evidence submission phase
- **arbitration**: Evidence complete, arbitrators voting
- **resolved**: Final decision made, funds distributed

## 💡 Key Parameters

- **Minimum Stake**: 1,000,000 microSTX (1 STX)
- **Required Votes**: Minimum 3 arbitrator votes for resolution
- **Evidence Limit**: Up to 5 pieces of evidence per party

## 🛡️ Security Features

- Stake requirements prevent spam disputes
- Multi-arbitrator voting ensures fair decisions
- Reputation system incentivizes honest arbitration
- Time-locked evidence submission phases

## 🏗️ Architecture

The contract manages three main entities:
- **Disputes**: Core dispute records with evidence and voting
- **Arbitrators**: Registered judges with reputation tracking  
- **Stakes**: Financial commitments from disputing parties

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Test with Clarinet
4. Submit pull request

## 📜 License

MIT License - see LICENSE file for details

---

*Built with ❤️ on Stacks blockchain for transparent land dispute resolution*
