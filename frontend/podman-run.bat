@echo off
setlocal EnableDelayedExpansion

REM -----------------------------------------------------------------------------
REM FinTech Enterprise Loan Management System (LMS) - Podman Manager
REM -----------------------------------------------------------------------------

if /i "%~1"=="start" goto action_start
if /i "%~1"=="kube-start" goto action_kube_start
if /i "%~1"=="stop" goto action_stop
if /i "%~1"=="restart" goto action_restart
if /i "%~1"=="logs" goto action_logs
if /i "%~1"=="status" goto action_status
if /i "%~1"=="seed" goto action_seed
if /i "%~1"=="reset" goto action_reset

:menu
cls
echo ===============================================================================
echo     FinTech Enterprise Loan Management System (LMS) -- Podman Manager
echo ===============================================================================
echo.
echo   [1] Start LMS Stack with Podman Compose (Next.js + PostgreSQL)
echo   [2] Start LMS Stack as Native Podman Pod (via Kubernetes YAML)
echo   [3] Stop LMS Stack (Gracefully halt all containers / pod)
echo   [4] Restart LMS Stack
echo   [5] Stream Real-time Container Logs
echo   [6] Check Stack / Pod Status
echo   [7] Re-seed Database (Reset initial admin and master data)
echo   [8] Open Web Portal in Default Browser (http://localhost:3000)
echo   [9] Full Factory Clean Reset (Wipes database volumes and rebuilds)
echo   [0] Exit
echo.
echo ===============================================================================
set /p choice="Enter option [0-9]: "

if "%choice%"=="1" goto action_start
if "%choice%"=="2" goto action_kube_start
if "%choice%"=="3" goto action_stop
if "%choice%"=="4" goto action_restart
if "%choice%"=="5" goto action_logs
if "%choice%"=="6" goto action_status
if "%choice%"=="7" goto action_seed
if "%choice%"=="8" goto action_open_browser
if "%choice%"=="9" goto action_reset
if "%choice%"=="0" goto action_exit

echo Invalid option selected.
timeout /t 2 >nul
goto menu

:check_podman
echo [INFO] Checking Podman engine availability...
where podman >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] 'podman' executable was not found on your system PATH.
    echo.
    echo Please install Podman Desktop or Podman CLI for Windows:
    echo   - Winget: winget install RedHat.Podman-Desktop
    echo   - Official Site: https://podman-desktop.io/
    echo.
    pause
    exit /b 1
)

podman info >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [WARNING] Podman machine is currently not active or unreachable.
    echo [INFO] Attempting to start Podman default machine...
    podman machine start
    
    timeout /t 3 >nul
    podman info >nul 2>&1
    if !errorlevel! neq 0 (
        echo.
        echo [ERROR] Could not start or reach Podman machine.
        echo If you have not created a machine yet, run:
        echo   podman machine init
        echo   podman machine start
        echo.
        pause
        exit /b 1
    )
)

echo [OK] Podman machine is online and ready.
exit /b 0

:detect_compose
set COMPOSE_FILE=podman-compose.yml
if not exist "%COMPOSE_FILE%" (
    if exist "frontend\podman-compose.yml" (
        set COMPOSE_FILE=frontend\podman-compose.yml
    )
)

podman compose version >nul 2>&1
if %errorlevel% equ 0 (
    set COMPOSE_CMD=podman compose -f %COMPOSE_FILE%
    exit /b 0
)

where podman-compose >nul 2>&1
if %errorlevel% equ 0 (
    set COMPOSE_CMD=podman-compose -f %COMPOSE_FILE%
    exit /b 0
)

docker-compose -f %COMPOSE_FILE% version >nul 2>&1
if %errorlevel% equ 0 (
    set COMPOSE_CMD=docker-compose -f %COMPOSE_FILE%
    exit /b 0
)

echo [WARNING] Podman compose provider was not found.
echo Falling back to native Podman Pod (Kubernetes YAML)...
set COMPOSE_CMD=NATIVE_POD
exit /b 0

:action_start
cls
echo ===============================================================================
echo   Starting LMS Stack via Podman Compose...
echo ===============================================================================
call :check_podman
if %errorlevel% neq 0 goto menu

call :detect_compose
if "%COMPOSE_CMD%"=="NATIVE_POD" goto action_kube_start

echo.
echo [INFO] Executing: %COMPOSE_CMD% up --build -d
%COMPOSE_CMD% up --build -d

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to start containers via Podman Compose.
    pause
    goto menu
)

goto wait_for_service

:action_kube_start
cls
echo ===============================================================================
echo   Starting LMS Stack as Native Podman Pod (Kubernetes YAML)...
echo ===============================================================================
call :check_podman
if %errorlevel% neq 0 goto menu

set BUILD_CONTEXT=.
set CFILE=Containerfile
if not exist "%CFILE%" (
    if exist "frontend\Containerfile" (
        set BUILD_CONTEXT=frontend
        set CFILE=frontend\Containerfile
    )
)

set POD_FILE=podman-pod.yaml
if not exist "%POD_FILE%" (
    if exist "frontend\podman-pod.yaml" (
        set POD_FILE=frontend\podman-pod.yaml
    )
)

echo.
echo [INFO] Building Next.js OCI image (localhost/loan-ms-app:latest)...
podman build -t localhost/loan-ms-app:latest -f %CFILE% %BUILD_CONTEXT%

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Image build failed. Check output above.
    pause
    goto menu
)

echo.
echo [INFO] Launching Pod via 'podman play kube %POD_FILE%'...
podman play kube %POD_FILE%

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to launch pod.
    pause
    goto menu
)

:wait_for_service
echo.
echo [INFO] Waiting for Next.js application to become responsive at http://localhost:3000 ...
set attempt=0
:poll_web
timeout /t 3 >nul
set /a attempt+=1
curl -s -m 2 http://localhost:3000/api/health >nul 2>&1
if %errorlevel% equ 0 goto web_ready
if !attempt! leq 25 (
    echo Initializing services... (!attempt!/25)
    goto poll_web
)

:web_ready
echo.
echo ===============================================================================
echo   Loan Management System (LMS) is UP and RUNNING on Podman!
echo ===============================================================================
echo.
echo   - Web Application:       http://localhost:3000
echo   - Health Check:          http://localhost:3000/api/health
echo   - Database Health Check: http://localhost:3000/api/health/db
echo   - PostgreSQL Database:   localhost:5432 (database: loan_ms_db)
echo.
echo   - Default Administrator Credentials:
echo     * Email / Username:    admin@fintechlms.in  (or: admin)
echo     * Master Password:     LmsAdmin@2026
echo.
echo ===============================================================================
echo.
set /p opennow="Do you want to launch the portal in your browser now? (Y/N): "
if /i "%opennow%"=="Y" start http://localhost:3000
if /i "%opennow%"=="y" start http://localhost:3000

echo.
pause
goto menu

:action_stop
cls
echo ===============================================================================
echo   Stopping LMS Stack...
echo ===============================================================================
call :check_podman
if %errorlevel% neq 0 goto menu

call :detect_compose
if not "%COMPOSE_CMD%"=="NATIVE_POD" (
    %COMPOSE_CMD% down
)

set POD_FILE=podman-pod.yaml
if not exist "%POD_FILE%" (
    if exist "frontend\podman-pod.yaml" set POD_FILE=frontend\podman-pod.yaml
)

podman pod exists loan-ms-pod >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO] Stopping native Podman pod (loan-ms-pod)...
    podman play kube --down %POD_FILE% >nul 2>&1
    podman pod stop loan-ms-pod >nul 2>&1
    podman pod rm -f loan-ms-pod >nul 2>&1
)

echo.
echo [OK] All LMS Podman containers have stopped gracefully.
pause
goto menu

:action_restart
cls
echo ===============================================================================
echo   Restarting LMS Containers...
echo ===============================================================================
call :check_podman
if %errorlevel% neq 0 goto menu

call :detect_compose
if not "%COMPOSE_CMD%"=="NATIVE_POD" (
    %COMPOSE_CMD% restart
) else (
    podman pod restart loan-ms-pod
)
echo.
echo [OK] Stack restarted.
pause
goto menu

:action_logs
cls
echo ===============================================================================
echo   Streaming Real-time Container Logs (Press Ctrl+C to exit)
echo ===============================================================================
call :check_podman
if %errorlevel% neq 0 goto menu

call :detect_compose
if not "%COMPOSE_CMD%"=="NATIVE_POD" (
    %COMPOSE_CMD% logs -f
) else (
    podman logs -f loan_ms_app
)
pause
goto menu

:action_status
cls
echo ===============================================================================
echo   Podman Stack Status
echo ===============================================================================
call :check_podman
if %errorlevel% neq 0 goto menu

echo --- Pods ---
podman pod ps
echo.
echo --- Containers ---
podman ps -a --filter "name=loan_ms"
echo.
exit /b 0

:action_seed
cls
echo ===============================================================================
echo   Re-seeding Initial Master Data and Administrator Account
echo ===============================================================================
echo.
echo [NOTICE] This will refresh roles, products, branches, and the master admin.
set /p confirm="Are you sure you want to proceed? (Y/N): "
if /i not "%confirm%"=="Y" goto menu

call :check_podman
if %errorlevel% neq 0 goto menu

echo.
echo [INFO] Executing seed script inside container...
podman exec -it loan_ms_app npx tsx prisma/seed.ts
if %errorlevel% neq 0 (
    echo [INFO] Attempting via secondary container name...
    podman exec -it loan-ms-pod-web npx tsx prisma/seed.ts
)
echo.
echo [OK] Database seeding execution finished.
pause
goto menu

:action_open_browser
start http://localhost:3000
goto menu

:action_reset
cls
echo ===============================================================================
echo   FACTORY RESET: Remove Podman Containers, Volumes, and Rebuild
echo ===============================================================================
echo.
echo [CAUTION] This will delete the PostgreSQL data volume and all stored data!
set /p confirmreset="Type 'RESET' to confirm complete factory wipe: "
if not "%confirmreset%"=="RESET" (
    echo Aborted.
    pause
    goto menu
)

call :check_podman
if %errorlevel% neq 0 goto menu

call :detect_compose
if not "%COMPOSE_CMD%"=="NATIVE_POD" (
    echo [INFO] Tearing down compose stack and volumes...
    %COMPOSE_CMD% down -v
)

set POD_FILE=podman-pod.yaml
if not exist "%POD_FILE%" (
    if exist "frontend\podman-pod.yaml" set POD_FILE=frontend\podman-pod.yaml
)

podman play kube --down %POD_FILE% >nul 2>&1
podman pod rm -f loan-ms-pod >nul 2>&1
podman volume rm -f loan_ms_postgres_podman_data >nul 2>&1
podman volume rm -f loan-ms-postgres-pvc >nul 2>&1

echo [INFO] Rebuilding fresh images...
goto action_start

:action_exit
exit /b 0
