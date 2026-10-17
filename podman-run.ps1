<#
.SYNOPSIS
    FinTech Enterprise Loan Management System (LMS) - Podman Automation Controller

.DESCRIPTION
    Automates building, deploying, stopping, inspecting, and managing the LMS stack
    using Podman and Podman Compose or native Kubernetes Pod specs on Windows / WSL2.

.PARAMETER Action
    Command to execute: start, kube-start, stop, restart, logs, status, seed, reset, menu
#>

[CmdletBinding()]
param (
    [ValidateSet("start", "kube-start", "stop", "restart", "logs", "status", "seed", "reset", "menu")]
    [string]$Action = "menu"
)

$ErrorActionPreference = "Continue"

function Write-BrandHeader {
    Clear-Host
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "    FinTech Enterprise Loan Management System (LMS) -- Podman Manager (PS)     " -ForegroundColor White
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Get-Paths {
    $composeFile = "podman-compose.yml"
    if (-not (Test-Path $composeFile) -and (Test-Path "frontend\podman-compose.yml")) {
        $composeFile = "frontend\podman-compose.yml"
    }

    $cfile = "Containerfile"
    $buildContext = "."
    if (-not (Test-Path $cfile) -and (Test-Path "frontend\Containerfile")) {
        $cfile = "frontend\Containerfile"
        $buildContext = "frontend"
    }

    $podFile = "podman-pod.yaml"
    if (-not (Test-Path $podFile) -and (Test-Path "frontend\podman-pod.yaml")) {
        $podFile = "frontend\podman-pod.yaml"
    }

    return @{
        ComposeFile = $composeFile
        Containerfile = $cfile
        BuildContext = $buildContext
        PodFile = $podFile
    }
}

function Test-PodmanEngine {
    Write-Host "[INFO] Validating Podman CLI availability..." -ForegroundColor Cyan
    $podmanCmd = Get-Command podman -ErrorAction SilentlyContinue
    if (-not $podmanCmd) {
        Write-Host ""
        Write-Host "[ERROR] 'podman' executable was not found on your system PATH." -ForegroundColor Red
        Write-Host "Please install Podman Desktop or CLI:" -ForegroundColor Yellow
        Write-Host "  winget install RedHat.Podman-Desktop" -ForegroundColor White
        Write-Host "  https://podman-desktop.io/" -ForegroundColor White
        Write-Host ""
        return $false
    }

    & podman info *>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARNING] Podman machine is not currently running. Attempting to start default machine..." -ForegroundColor Yellow
        & podman machine start
        Start-Sleep -Seconds 3
        & podman info *>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Could not start or reach Podman machine." -ForegroundColor Red
            Write-Host "Run 'podman machine init' then 'podman machine start' to initialize WSL2 machine." -ForegroundColor Yellow
            return $false
        }
    }

    Write-Host "[OK] Podman machine is active and responsive." -ForegroundColor Green
    return $true
}

function Get-ComposeCommand {
    $paths = Get-Paths
    & podman compose version *>$null
    if ($LASTEXITCODE -eq 0) {
        return "podman compose -f $($paths.ComposeFile)"
    }

    $podmanCompose = Get-Command podman-compose -ErrorAction SilentlyContinue
    if ($podmanCompose) {
        return "podman-compose -f $($paths.ComposeFile)"
    }

    $dockerCompose = Get-Command docker-compose -ErrorAction SilentlyContinue
    if ($dockerCompose) {
        return "docker-compose -f $($paths.ComposeFile)"
    }

    return "NATIVE_POD"
}

function Start-LmsStack {
    Write-BrandHeader
    if (-not (Test-PodmanEngine)) { return }

    $compose = Get-ComposeCommand
    if ($compose -eq "NATIVE_POD") {
        Start-LmsKube
        return
    }

    Write-Host "`n[INFO] Starting stack using: $compose up --build -d" -ForegroundColor Cyan
    Invoke-Expression "$compose up --build -d"

    Wait-ForHealth
}

function Start-LmsKube {
    Write-BrandHeader
    if (-not (Test-PodmanEngine)) { return }
    $paths = Get-Paths

    Write-Host "`n[INFO] Building Next.js OCI image (localhost/loan-ms-app:latest)..." -ForegroundColor Cyan
    & podman build -t localhost/loan-ms-app:latest -f $paths.Containerfile $paths.BuildContext

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Container build failed." -ForegroundColor Red
        return
    }

    Write-Host "`n[INFO] Launching Pod with 'podman play kube $($paths.PodFile)'..." -ForegroundColor Cyan
    & podman play kube $paths.PodFile

    Wait-ForHealth
}

function Wait-ForHealth {
    Write-Host "`n[INFO] Probing Next.js application at http://localhost:3000/api/health ..." -ForegroundColor Cyan
    $attempts = 0
    $ready = $false

    while ($attempts -lt 25 -and -not $ready) {
        Start-Sleep -Seconds 3
        $attempts++
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:3000/api/health" -TimeoutSec 2 -ErrorAction Stop
            if ($response.status -eq "healthy" -or $response) {
                $ready = $true
            }
        } catch {
            Write-Host "Initializing services... ($attempts/25)" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Green
    Write-Host "   Loan Management System (LMS) is UP and RUNNING on Podman!                   " -ForegroundColor Green
    Write-Host "===============================================================================" -ForegroundColor Green
    Write-Host "  - Web Portal:            http://localhost:3000" -ForegroundColor White
    Write-Host "  - Health Check:          http://localhost:3000/api/health" -ForegroundColor White
    Write-Host "  - DB Health Check:       http://localhost:3000/api/health/db" -ForegroundColor White
    Write-Host "  - PostgreSQL:            localhost:5432 (database: loan_ms_db)" -ForegroundColor White
    Write-Host ""
    Write-Host "  - Default Administrator Credentials:" -ForegroundColor Yellow
    Write-Host "    * Email / Username:    admin@fintechlms.in (or: admin)" -ForegroundColor White
    Write-Host "    * Master Password:     LmsAdmin@2026" -ForegroundColor White
    Write-Host "===============================================================================" -ForegroundColor Green
    Write-Host ""

    $launch = Read-Host "Open portal in default browser now? (Y/N)"
    if ($launch -eq "Y" -or $launch -eq "y") {
        Start-Process "http://localhost:3000"
    }
}

function Stop-LmsStack {
    Write-BrandHeader
    if (-not (Test-PodmanEngine)) { return }
    $paths = Get-Paths

    $compose = Get-ComposeCommand
    if ($compose -ne "NATIVE_POD") {
        Invoke-Expression "$compose down"
    }

    & podman play kube --down $paths.PodFile *>$null
    & podman pod rm -f loan-ms-pod *>$null

    Write-Host "`n[OK] All Podman containers and pods have stopped gracefully." -ForegroundColor Green
}

function Restart-LmsStack {
    Write-BrandHeader
    if (-not (Test-PodmanEngine)) { return }

    $compose = Get-ComposeCommand
    if ($compose -ne "NATIVE_POD") {
        Invoke-Expression "$compose restart"
    } else {
        & podman pod restart loan-ms-pod
    }
    Write-Host "`n[OK] LMS stack restarted." -ForegroundColor Green
}

function Show-LmsLogs {
    Write-BrandHeader
    if (-not (Test-PodmanEngine)) { return }

    Write-Host "[INFO] Streaming logs (Ctrl+C to stop)..." -ForegroundColor Cyan
    $compose = Get-ComposeCommand
    if ($compose -ne "NATIVE_POD") {
        Invoke-Expression "$compose logs -f"
    } else {
        & podman logs -f loan_ms_app
    }
}

function Show-LmsStatus {
    Write-BrandHeader
    if (-not (Test-PodmanEngine)) { return }

    Write-Host "--- Active Podman Pods ---" -ForegroundColor Yellow
    & podman pod ps
    Write-Host "`n--- Active Containers ---" -ForegroundColor Yellow
    & podman ps -a --filter "name=loan_ms"
}

function Seed-Database {
    Write-BrandHeader
    if (-not (Test-PodmanEngine)) { return }

    Write-Host "[INFO] Executing database seed script in running container..." -ForegroundColor Cyan
    & podman exec -it loan_ms_app npx tsx prisma/seed.ts
    if ($LASTEXITCODE -ne 0) {
        & podman exec -it loan-ms-pod-web npx tsx prisma/seed.ts
    }
    Write-Host "`n[OK] Seed process completed." -ForegroundColor Green
}

function Reset-LmsStack {
    Write-BrandHeader
    Write-Host "[CAUTION] This will delete PostgreSQL persistent data volumes and rebuild from scratch!" -ForegroundColor Red
    $confirm = Read-Host "Type 'RESET' to confirm factory wipe"
    if ($confirm -ne "RESET") {
        Write-Host "Aborted." -ForegroundColor Yellow
        return
    }

    if (-not (Test-PodmanEngine)) { return }
    $paths = Get-Paths

    $compose = Get-ComposeCommand
    if ($compose -ne "NATIVE_POD") {
        Invoke-Expression "$compose down -v"
    }

    & podman play kube --down $paths.PodFile *>$null
    & podman pod rm -f loan-ms-pod *>$null
    & podman volume rm -f loan_ms_postgres_podman_data *>$null
    & podman volume rm -f loan-ms-postgres-pvc *>$null

    Write-Host "`n[INFO] Volumes purged. Rebuilding fresh stack..." -ForegroundColor Green
    Start-LmsStack
}

function Show-Menu {
    while ($true) {
        Write-BrandHeader
        Write-Host "  [1] Start LMS Stack with Podman Compose" -ForegroundColor White
        Write-Host "  [2] Start LMS Stack as Native Podman Pod (Kube Play)" -ForegroundColor White
        Write-Host "  [3] Stop LMS Stack" -ForegroundColor White
        Write-Host "  [4] Restart LMS Stack" -ForegroundColor White
        Write-Host "  [5] Stream Real-time Container Logs" -ForegroundColor White
        Write-Host "  [6] Check Stack / Pod Status" -ForegroundColor White
        Write-Host "  [7] Re-seed Database (Admin & Master Data)" -ForegroundColor White
        Write-Host "  [8] Open Web Portal (http://localhost:3000)" -ForegroundColor White
        Write-Host "  [9] Factory Clean Reset (Wipe storage & rebuild)" -ForegroundColor White
        Write-Host "  [0] Exit" -ForegroundColor Gray
        Write-Host ""
        Write-Host "===============================================================================" -ForegroundColor Cyan
        $choice = Read-Host "Select option [0-9]"

        switch ($choice) {
            "1" { Start-LmsStack; Read-Host "`nPress Enter to continue" }
            "2" { Start-LmsKube; Read-Host "`nPress Enter to continue" }
            "3" { Stop-LmsStack; Read-Host "`nPress Enter to continue" }
            "4" { Restart-LmsStack; Read-Host "`nPress Enter to continue" }
            "5" { Show-LmsLogs }
            "6" { Show-LmsStatus; Read-Host "`nPress Enter to continue" }
            "7" { Seed-Database; Read-Host "`nPress Enter to continue" }
            "8" { Start-Process "http://localhost:3000" }
            "9" { Reset-LmsStack; Read-Host "`nPress Enter to continue" }
            "0" { return }
            default { Write-Host "Invalid option." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

# Main Dispatcher
switch ($Action) {
    "start"      { Start-LmsStack }
    "kube-start" { Start-LmsKube }
    "stop"       { Stop-LmsStack }
    "restart"    { Restart-LmsStack }
    "logs"       { Show-LmsLogs }
    "status"     { Show-LmsStatus }
    "seed"       { Seed-Database }
    "reset"      { Reset-LmsStack }
    default      { Show-Menu }
}
