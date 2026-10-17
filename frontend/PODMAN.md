# Enterprise Loan Management System (LMS) — Podman Deployment Guide

This guide details running the FinTech Loan Management System locally or on an enterprise server using **Podman** (Pod Manager), an OCI-compliant, daemonless, and rootless container engine.

---

## 1. Why Podman for FinTech LMS?

- **Rootless by Default**: Eliminates the security risk of a root daemon. Containers execute within unprivileged user namespaces (`subuid`/`subgid`), satisfying stringent banking and financial infrastructure security policies.
- **Daemonless Architecture**: Podman interacts directly with the Linux kernel and `crun`/`runc` instead of relying on a continuously running background system daemon.
- **Native Pod & Kubernetes Architecture**: Podman natively organizes multi-container applications into **Pods** (sharing localhost network, IPC, and UTS namespaces) and can directly run Kubernetes manifests using `podman play kube`.
- **Systemd & Enterprise Integration**: Podman services can be easily converted to systemd service units for automated production reboot resilience without third-party orchestrators.

---

## 2. Prerequisites & Installation

### Windows 10 / 11 (with WSL2):
1. Install **Podman Desktop** or **Podman CLI**:
   ```powershell
   winget install RedHat.Podman-Desktop
   # Or CLI only:
   winget install RedHat.Podman
   ```
2. Initialize and start the Podman WSL2 machine:
   ```powershell
   podman machine init
   podman machine start
   ```

### Linux (RHEL / Fedora / CentOS / AlmaLinux / Rocky Linux):
```bash
sudo dnf install -y podman podman-compose
```

### Linux (Ubuntu / Debian):
```bash
sudo apt-get update && sudo apt-get install -y podman podman-compose
```

### macOS:
```bash
brew install podman
podman machine init
podman machine start
```

---

## 3. Quick Start with Interactive Automation Scripts

The project includes pre-built interactive CLI controllers for all platforms:

| Platform | Script | Command |
| :--- | :--- | :--- |
| **Windows (CMD / Batch)** | `podman-run.bat` | `podman-run.bat` |
| **Windows (PowerShell)** | `podman-run.ps1` | `.\podman-run.ps1` |
| **Linux / macOS / WSL** | `podman-run.sh` | `./podman-run.sh` |

### Supported Direct CLI Commands:
- `podman-run.bat start` — Build images and start PostgreSQL + Next.js with Podman Compose
- `podman-run.bat kube-start` — Build image and launch as native Podman Pod via `podman play kube`
- `podman-run.bat stop` — Gracefully stop all containers / pods
- `podman-run.bat restart` — Restart existing containers
- `podman-run.bat logs` — Stream live container logs
- `podman-run.bat status` — Show running containers, pods, and port bindings
- `podman-run.bat seed` — Re-execute initial master data & administrator seeding
- `podman-run.bat reset` — Factory reset (wipe volume & rebuild fresh)

---

## 4. Method A: Podman Compose (`podman-compose.yml`)

Podman 4.x and 5.x support Compose specifications directly:

### 1. Build and Start the Stack:
```bash
podman compose -f podman-compose.yml up --build -d
```
*(If using standalone `podman-compose`: `podman-compose -f podman-compose.yml up --build -d`)*

### 2. Follow Real-Time Logs:
```bash
podman compose -f podman-compose.yml logs -f web
```

### 3. Check Service Status:
```bash
podman compose -f podman-compose.yml ps
```

### 4. Stop the Stack:
```bash
podman compose -f podman-compose.yml down
```

---

## 5. Method B: Native Podman Pod (`podman play kube`)

Podman's marquee capability allows running the full stack inside a shared Pod namespace with standard Kubernetes YAML:

### 1. Build Next.js Container Image:
```bash
podman build -t localhost/loan-ms-app:latest -f Containerfile .
```

### 2. Deploy Native Pod with Kubernetes YAML:
```bash
podman play kube podman-pod.yaml
```

### 3. Inspect the Pod:
```bash
podman pod ps
podman pod inspect loan-ms-pod
```

### 4. Stream Logs:
```bash
podman logs -f loan_ms_app
```

### 5. Tear Down the Pod:
```bash
podman play kube --down podman-pod.yaml
```

> [!NOTE]
> **Pod Network Advantage**: In a Podman Pod, both `postgres` and `web` share `127.0.0.1` (`localhost`). The web container connects directly to `localhost:5432` without needing complex bridge DNS lookups.

---

## 6. npm Scripts Integration

You can also use npm commands configured in `package.json`:

```bash
# Build OCI image with Podman
npm run podman:build

# Launch with Podman Compose
npm run podman:up

# Stream real-time logs
npm run podman:logs

# Stop Podman Compose stack
npm run podman:down

# Launch as native Podman Pod (Kube YAML)
npm run podman:kube:play

# Stop native Podman Pod
npm run podman:kube:down
```

---

## 7. Architecture & Container Layout

| Service | Container Name | Base Image | Internal Port | Host Port | Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`postgres`** | `loan_ms_postgres` | `docker.io/library/postgres:16-alpine` | `5432` | `5432` | PostgreSQL database with persistent volume |
| **`web`** | `loan_ms_app` | `docker.io/library/node:22-alpine` (multi-stage) | `3000` | `3000` | Next.js app + Prisma ORM + Financial API routes |

### Automated Startup & Database Synchronization:
When `web` starts up, its entrypoint script (`docker-entrypoint.sh`):
1. **Connectivity Check**: Probes PostgreSQL with exponential backoff until it is ready.
2. **Schema Synchronization**: Executes `prisma db push --accept-data-loss` to synchronize all 30+ tables and relations.
3. **Smart Auto-Seeding**: Checks if any users exist in the database. If the database is fresh (0 users), it automatically executes `prisma/seed.ts` to provision initial branches, roles, loan products, and the administrator account. If users already exist, it preserves existing loan portfolio data.
4. **Starts Next.js**: Boots the Next.js server bound to `0.0.0.0:3000`.

---

## 8. Rootless & Security Hardening

### SELinux Volume Relabeling (`:Z` Flag):
On SELinux-enforcing systems (Fedora, RHEL, CentOS), bind mounts require SELinux context relabeling. In `podman-compose.yml`, persistent volume mounts use the `:Z` flag:
```yaml
volumes:
  - postgres_podman_data:/var/lib/postgresql/data:Z
```
This instructs Podman to automatically configure the container SELinux MCS label to allow read/write access.

### Short-Name Resolution:
To avoid interactive CLI prompts asking which container registry to pull from, image names are fully qualified with `docker.io/library/` (e.g. `docker.io/library/node:22-alpine` and `docker.io/library/postgres:16-alpine`).

---

## 9. Default Access Credentials

Once the containers are up:

- **Web Application Portal**: [http://localhost:3000](http://localhost:3000)
- **Health Check**: [http://localhost:3000/api/health](http://localhost:3000/api/health)
- **Database Health Check**: [http://localhost:3000/api/health/db](http://localhost:3000/api/health/db)
- **Default Master Admin Email**: `admin@fintechlms.in` (or username: `admin`)
- **Default Master Password**: `LmsAdmin@2026`

---

## 10. Operations & Troubleshooting

### Run Database Seed Manually:
```bash
podman exec -it loan_ms_app npx tsx prisma/seed.ts
```

### Launch Prisma Studio inside Podman:
```bash
podman exec -it loan_ms_app npx prisma studio --port 5555 --browser none
```

### Direct PostgreSQL psql Shell:
```bash
podman exec -it loan_ms_postgres psql -U postgres -d loan_ms_db
```

### Factory Clean Reset:
To purge all volumes, databases, and re-create from scratch:
```bash
# With podman compose:
podman compose -f podman-compose.yml down -v
podman compose -f podman-compose.yml up --build -d

# Or with podman-run:
./podman-run.bat reset
```

### Common Issues & Solutions:
1. **`error: cannot connect to the Podman socket`**:
   - Run `podman machine start` to verify the WSL2/VM backend is active.
2. **Port Conflict on `5432` or `3000`**:
   - If a local PostgreSQL or node instance is already running on port 5432 or 3000, change the host port binding in `podman-compose.yml` (e.g., `"5433:5432"`).
3. **WSL2 Memory Limitations**:
   - On Windows, configure `%USERPROFILE%\.wslconfig` with:
     ```ini
     [wsl2]
     memory=4GB
     processors=4
     ```
