# Citation Tracker Smart Contract

A Clarity smart contract for tracking and managing academic citations on the Stacks blockchain.

## Overview

This smart contract enables a decentralized citation management system for academic work. The contract allows researchers to register their works, cite other works, and track citation metrics. It also includes verification mechanisms and a reward system to incentivize proper citation practices.

## Features

### Work Registration
- Register academic works with title, field, and abstract
- Each work is associated with its author's Stacks address
- Automatic tracking of publication timestamp

### Citation Management
- Add citations between works with context information
- Citations include a weight factor (1-10) to indicate significance
- Protection against self-citation
- Only the author of a citing work can add citations

### Citation Metrics
- Track citation count for each work
- Maintain author statistics (total works, citations received)
- Calculate field-specific metrics
- Approximate h-index calculation

### Verification System
- Authorized verifiers can validate work authorship
- Only the contract owner can add or remove verifiers
- Verified works receive reputation bonuses

### Reward Mechanism
- Authors earn reward points when their works are cited
- Reward points scale with citation weight
- Authors can claim accumulated rewards

## Contract Functions

### Public Functions

#### Registration and Citation
- `register-work`: Register a new academic work
- `add-citation`: Add a citation between two works

#### Verification
- `verify-work`: Verify authorship of a work (verifiers only)
- `add-verifier`: Add a new verifier (contract owner only)
- `remove-verifier`: Remove a verifier (contract owner only)

#### Rewards
- `claim-rewards`: Claim accumulated citation rewards

### Read-Only Functions

#### Information Retrieval
- `get-work-details`: Get details about a specific work
- `get-citation-details`: Get details about a specific citation
- `get-citation-count`: Get the number of citations for a work
- `get-author-stats`: Get statistics for an author
- `get-field-metrics`: Get metrics for a specific field
- `get-reward-points`: Get reward points for an author
- `get-h-index`: Calculate approximate h-index for an author
- `is-verifier`: Check if an address is an authorized verifier
- `get-citations-for-work`: Get all citations for a work (as cited or citing)

## How To Use

### 1. Register Your Work

```clarity
(contract-call? .citation-tracker register-work 
  "work-20240509-001" 
  "Advances in Blockchain Citation Systems" 
  "Computer Science" 
  u"This paper explores the application of blockchain technology to academic citation tracking...")
```

### 2. Add Citation to Another Work

```clarity
(contract-call? .citation-tracker add-citation
  "my-work-id"           ;; Your work that's doing the citing
  "work-being-cited-id"  ;; Work you're citing
  (some u"This work provides fundamental concepts for our research")
  u5)                    ;; Citation weight (1-10)
```

### 3. Verify a Work (for authorized verifiers)

```clarity
(contract-call? .citation-tracker verify-work "work-id-to-verify")
```

### 4. Claim Rewards

```clarity
(contract-call? .citation-tracker claim-rewards)
```

### 5. View Metrics

```clarity
(contract-call? .citation-tracker get-citation-count "work-id")
(contract-call? .citation-tracker get-author-stats tx-sender)
(contract-call? .citation-tracker get-h-index tx-sender)
```

## Error Codes

- `u100`: Not authorized
- `u101`: Already exists
- `u102`: Does not exist
- `u103`: Self-citation not allowed
- `u104`: Invalid parameters

## Contract Data Structure

### Maps

- `academic-works`: Stores information about academic works
- `citation-records`: Tracks citation relationships between works
- `citation-counts`: Maintains citation count per work
- `author-stats`: Tracks statistics for each author
- `field-metrics`: Monitors metrics for each academic field
- `citation-rewards`: Manages reward points for authors
- `allowed-verifiers`: List of authorized verification entities

## Implementation Notes

The contract includes several implementation optimizations:

1. **Improved Error Handling**: All functions include proper assertion checks to validate parameters and authorization.

2. **Optimized H-Index Calculation**: A simplified h-index approximation is used to avoid recursion issues in Clarity.

3. **Consistent Variable Naming**: Map names use descriptive prefixes (e.g., `academic-works`, `citation-records`) to avoid naming conflicts.

4. **Proper Optional Type Handling**: All optional values from `map-get?` operations are handled with `is-some` and `is-none` checks.

5. **Efficient Data Access**: Local variables are used to avoid redundant map lookups.

## Security Considerations

- Only the work's author can create citations from that work
- Verification process ensures authenticity of registered works
- Contract owner controls verifier privileges
- All functions include appropriate authorization checks