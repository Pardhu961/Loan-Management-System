# Enterprise Loan Management System (LMS)

A modern full-stack Digital Lending and Loan Servicing Platform built with Next.js, TypeScript, Tailwind CSS, and Prisma ORM.

## Core System Modules

1. **Customer Onboarding & KYC**: Single customer view (SCV), deduplication, CKYC/Tier 3, PAN/Aadhaar masking.
2. **Loan Applications & Form Builder**: Dynamic multi-step questionnaires, product configuration (HL, PL, VL, BL, GL).
3. **Parties & Collateral**: Co-applicants, personal/corporate guarantors, asset valuation, and LTV computation.
4. **Credit Bureau Integration**: Real-time CIBIL / Experian reporting, score bands, and delinquency analysis.
5. **Credit Assessment Workbench**: Financial ratio analysis (FOIR/DTI), policy deviation management, and Credit Appraisal Memo (CAM).
6. **Approval Matrix & Committee**: Multi-tier Delegation of Authority (DoA) limits, conditions precedent/subsequent.
7. **Sanction Management**: Regulatory Sanction Letter & Key Fact Statement (KFS) generation with customer acceptance.
8. **Disbursements**: Pre-disbursement checks, beneficiary penny drop verification, and NEFT/RTGS/IMPS banking rails payout.
9. **Loan Accounts & Servicing**: Automated reducing-balance amortization schedule generation, eNACH mandate auto-debit.
10. **Repayments, Delinquency & Recovery**: Automated waterfall payment allocation, SMA-0/1/2 DPD bucketing, restructuring, and legal recovery.
11. **Closure & Digital NOC**: Exact foreclosure quote computation, lien release, and QR-verifiable digital NOC certificate.

---

## 🚀 Quick Start (Podman Deployment — Rootless & Daemonless)

First-class support for **Podman** on Windows (WSL2), Linux, and macOS:

### Windows Automation Launchers:
- **Command Prompt**:
  `cmd
  podman-run.bat
  `
- **PowerShell**:
  `powershell
  .\podman-run.ps1
  `
*(Supports: start, kube-start, stop, estart, logs, status, seed, eset)*

### Linux / macOS Automation Launcher:
`ash
chmod +x podman-run.sh
./podman-run.sh
`

### Direct CLI Options:
`ash
# Option 1: Podman Compose
podman compose -f podman-compose.yml up --build -d

# Option 2: Native Podman Pod (Kubernetes YAML)
podman build -t localhost/loan-ms-app:latest -f frontend/Containerfile frontend
podman play kube podman-pod.yaml
`

For complete rootless configuration, SELinux guidelines, and architecture details, see [PODMAN.md](PODMAN.md).

---

## 🐳 Quick Start (Docker Deployment)

Launch the entire stack with Docker Desktop or Docker Engine:

### Windows (1-Click Launcher):
`cmd
run.bat
`
*(Supports: un.bat start, un.bat stop, un.bat restart, un.bat logs, un.bat seed, un.bat reset)*

### Linux / macOS:
`ash
docker compose up --build -d
`

---

## 🔑 Default Access Credentials

- **Web Application Portal**: [http://localhost:3000](http://localhost:3000)
- **Health Check**: [http://localhost:3000/api/health](http://localhost:3000/api/health)
- **PostgreSQL Database**: localhost:5432 (db: loan_ms_db, user: postgres)
- **Default Master Admin**: dmin@fintechlms.in / LmsAdmin@2026

For detailed setup, container management, and troubleshooting, see [PODMAN.md](PODMAN.md), [DOCKER.md](DOCKER.md), and [DEPLOYMENT.md](DEPLOYMENT.md).
