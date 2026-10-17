# FinTech Enterprise Loan Management System (LMS)

A comprehensive, enterprise-grade Loan Management System built with **Next.js 16**, **React 19**, **Prisma ORM**, and **PostgreSQL**. Featuring complete lifecycle management: customer onboarding, KYC/AML verification, loan products configuration, credit risk assessment, multi-stage approval workflows, disbursement gatekeeping, flexible repayment schedules, restructuring, charges & fee adjustments, legal recovery, and automated accounting reconciliation.

---

## 🚀 Quick Start with Podman (Recommended)

This project provides full, first-class support for **Podman** (rootless & daemonless OCI container engine).

### 1. Interactive Automation Managers:

- **Windows (Command Prompt / Batch)**:
  ```cmd
  podman-run.bat
  ```
- **Windows (PowerShell)**:
  ```powershell
  .\podman-run.ps1
  ```
- **Linux / macOS / WSL (Bash)**:
  ```bash
  chmod +x podman-run.sh
  ./podman-run.sh
  ```

### 2. Podman Compose:
```bash
# Build and launch Next.js and PostgreSQL in detached mode
podman compose -f podman-compose.yml up --build -d

# Stream real-time logs
podman compose -f podman-compose.yml logs -f

# Stop containers
podman compose -f podman-compose.yml down
```

### 3. Native Podman Pod (Kubernetes YAML):
```bash
# Build OCI image
podman build -t localhost/loan-ms-app:latest -f Containerfile .

# Launch native pod with shared localhost networking
podman play kube podman-pod.yaml

# Stop pod
podman play kube --down podman-pod.yaml
```

📖 **Detailed Podman documentation, rootless configuration, and SELinux setup**: See [PODMAN.md](file:///g:/Coding/VS%20code/Loan%20ms/frontend/PODMAN.md).

---

## 🐳 Quick Start with Docker

If you prefer Docker Desktop or Docker Engine:

```bash
# Launch with Docker Compose
docker compose up --build -d

# Stop stack
docker compose down
```

---

## 💻 Local Development (without Containers)

### 1. Install Dependencies
```bash
npm install
```

### 2. Configure Environment
Copy `.env.example` to `.env` and configure your PostgreSQL connection:
```bash
cp .env.example .env
```

### 3. Synchronize Schema & Seed Baseline Data
```bash
# Push Prisma schema to PostgreSQL
npx prisma db push

# Seed initial roles, branches, products, and system administrator
npm run prisma:seed
```

### 4. Run Development Server
```bash
npm run dev
```
Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## 🔑 Default Administrator Credentials

Once initialized and seeded:

| Parameter | Value |
| :--- | :--- |
| **URL** | [http://localhost:3000](http://localhost:3000) |
| **Username / Email** | `admin@fintechlms.in` (or: `admin`) |
| **Password** | `LmsAdmin@2026` |
| **Role** | System Administrator (Full Access) |

---

## 🛠 Available npm Scripts

| Script | Description |
| :--- | :--- |
| `npm run dev` | Starts Next.js development server with hot-reloading |
| `npm run build` | Generates Prisma client and builds Next.js production bundle |
| `npm run start` | Starts Next.js production server |
| `npm run prisma:seed` | Seeds database with default master data and administrator |
| `npm run prisma:push` | Pushes Prisma schema changes directly to PostgreSQL |
| `npm run prisma:studio` | Opens visual Prisma Studio database GUI |
| `npm run podman:build` | Builds OCI image using Podman and `Containerfile` |
| `npm run podman:up` | Boots PostgreSQL and Web services using Podman Compose |
| `npm run podman:down` | Stops Podman Compose stack |
| `npm run podman:logs` | Streams live container logs from Podman |
| `npm run podman:kube:play` | Deploys native Podman Pod using `podman-pod.yaml` |
| `npm run podman:kube:down` | Tears down native Podman Pod |

---

## 🏛 System Architecture & Technology Stack

- **Framework**: [Next.js](https://nextjs.org/) (App Router, Server Components & Route Handlers)
- **UI Library**: [React 19](https://react.dev/), Tailwind CSS, Lucide Icons, Recharts
- **ORM & Database**: [Prisma ORM](https://www.prisma.io/) with PostgreSQL 16+
- **Containerization**: Podman (`Containerfile`, `podman-compose.yml`, `podman-pod.yaml`) & Docker
- **Security**: Rootless execution, SELinux `:Z` labeling, RBAC permission matrix, audit trail logging
