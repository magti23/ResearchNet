# ResearchNet

**ResearchNet** is a Clarity smart contract enabling a decentralized, consortium-based scientific research platform. It allows academic institutions to collaborate on research studies, facilitate peer review processes, and manage funding allocations transparently.

## 🧪 Overview

ResearchNet enables:

- Registration of accredited academic institutions
- Submission and management of collaborative research studies
- Weighted faculty peer reviews based on expertise
- Institutional consensus evaluation
- Publishing of approved studies
- Controlled funding commitment and release

---

## 📚 Features

### 🔹 Academic Partnerships
- Register accredited institutions with faculty thresholds and funding custodians.
- Institutions are validated and tracked through unique `institution-id`s.

### 🔹 Research Proposal System
- Principal investigators submit research studies involving multiple institutions.
- Includes metadata like hypothesis, field, funding structure, and deadlines.
- Requires a consortium fee (2 STX) per proposal.

### 🔹 Decentralized Peer Review
- Faculty members from partner institutions review research using weighted input.
- Peer reviews are timestamped and restricted to avoid duplicity.

### 🔹 Consensus & Publishing
- Each institution’s reviews are tallied for consensus.
- Studies are only publishable if peer review thresholds and deadlines are satisfied.

### 🔹 Funding Management
- Institutions lock funds based on preset allocation plans.
- Funds are released post-approval, based on predefined criteria.

---

## 🛠️ Public Functions

- `establish-academic-partnership(...)`: Register a new academic institution.
- `submit-research-proposal(...)`: Submit a research study for collaboration.
- `submit-peer-review(...)`: Faculty members submit peer reviews.
- `publish-research-findings(study-id)`: Finalize study and release funds.
- `commit-research-funding(...)`: Commit funding from an institution.

---

## 🔍 Read-only Queries

- `get-study-details(study-id)`
- `get-institution-info(institution-id)`
- `get-institutional-review(study-id, institution-id)`
- `get-faculty-review(study-id, institution-id, reviewer)`
- `can-faculty-review(study-id, institution-id, faculty)`

---

## 🧪 Example Use Case

1. Institution A registers via `establish-academic-partnership`.
2. A researcher from Institution A submits a study proposal with collaborators.
3. Faculty from the listed institutions submit peer reviews.
4. Upon deadline and consensus, the study is published and funds are released.

---

## ⚠️ Error Codes

- `err-pi-only (u300)`: Action restricted to principal investigator.
- `err-not-faculty (u301)`: Reviewer does not meet faculty threshold.
- `err-invalid-study (u302)`: Study ID not found or invalid.
- `err-study-expired (u303)`: Review window closed.
- `err-already-reviewed (u304)`: Duplicate review detected.
- `err-insufficient-consensus (u305)`: Threshold not met for approval.
- `err-study-not-approved (u306)`: Study failed peer review.
- `err-institution-not-registered (u307)`: Invalid institution ID.
- `err-invalid-funding (u308)`: Funding value or structure invalid.
