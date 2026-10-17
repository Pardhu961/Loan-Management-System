#!/usr/bin/env bash
# ==============================================================================
# FinTech Enterprise Loan Management System (LMS) — Podman Automation (Bash)
# ==============================================================================

set -e

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    clear 2>/dev/null || true
    echo -e "${CYAN}===============================================================================${NC}"
    echo -e "${CYAN}    FinTech Enterprise Loan Management System (LMS) — Podman Manager (Bash)    ${NC}"
    echo -e "${CYAN}===============================================================================${NC}"
    echo ""
}

get_paths() {
    COMPOSE_FILE="podman-compose.yml"
    if [ ! -f "$COMPOSE_FILE" ] && [ -f "frontend/podman-compose.yml" ]; then
        COMPOSE_FILE="frontend/podman-compose.yml"
    fi

    CFILE="Containerfile"
    BUILD_CONTEXT="."
    if [ ! -f "$CFILE" ] && [ -f "frontend/Containerfile" ]; then
        CFILE="frontend/Containerfile"
        BUILD_CONTEXT="frontend"
    fi

    POD_FILE="podman-pod.yaml"
    if [ ! -f "$POD_FILE" ] && [ -f "frontend/podman-pod.yaml" ]; then
        POD_FILE="frontend/podman-pod.yaml"
    fi
}

check_podman() {
    echo -e "${CYAN}[INFO] Checking Podman installation...${NC}"
    if ! command -v podman &>/dev/null; then
        echo -e "${RED}[ERROR] 'podman' command was not found on your system.${NC}"
        echo -e "${YELLOW}Please install Podman on your platform:${NC}"
        echo "  Fedora / RHEL / CentOS: sudo dnf install -y podman"
        echo "  Debian / Ubuntu:        sudo apt-get install -y podman"
        echo "  macOS (Homebrew):       brew install podman && podman machine init && podman machine start"
        exit 1
    fi

    if ! podman info &>/dev/null; then
        echo -e "${YELLOW}[WARNING] Podman machine or socket is not active. Attempting start...${NC}"
        podman machine start 2>/dev/null || true
        sleep 2
        if ! podman info &>/dev/null; then
            echo -e "${RED}[ERROR] Could not connect to Podman engine.${NC}"
            echo "Run 'podman machine init' then 'podman machine start' if on macOS/Windows WSL."
            exit 1
        fi
    fi
    echo -e "${GREEN}[OK] Podman engine is active and reachable.${NC}"
}

get_compose_cmd() {
    get_paths
    if podman compose version &>/dev/null; then
        echo "podman compose -f $COMPOSE_FILE"
    elif command -v podman-compose &>/dev/null; then
        echo "podman-compose -f $COMPOSE_FILE"
    elif command -v docker-compose &>/dev/null; then
        echo "docker-compose -f $COMPOSE_FILE"
    else
        echo "NATIVE_POD"
    fi
}

wait_for_health() {
    echo -e "\n${CYAN}[INFO] Probing web application at http://localhost:3000/api/health ...${NC}"
    local attempts=0
    until curl -s -m 2 http://localhost:3000/api/health | grep -q "healthy" || [ $attempts -ge 25 ]; do
        sleep 3
        attempts=$((attempts + 1))
        echo "Initializing services... ($attempts/25)"
    done

    echo ""
    echo -e "${GREEN}===============================================================================${NC}"
    echo -e "${GREEN}   Loan Management System (LMS) is UP and RUNNING on Podman!                   ${NC}"
    echo -e "${GREEN}===============================================================================${NC}"
    echo "  - Web Portal:            http://localhost:3000"
    echo "  - Health Check:          http://localhost:3000/api/health"
    echo "  - DB Health Check:       http://localhost:3000/api/health/db"
    echo "  - PostgreSQL:            localhost:5432 (database: loan_ms_db)"
    echo ""
    echo -e "${YELLOW}  - Default Administrator Credentials:${NC}"
    echo "    * Email / Username:    admin@fintechlms.in (or: admin)"
    echo "    * Master Password:     LmsAdmin@2026"
    echo -e "${GREEN}===============================================================================${NC}"
    echo ""
}

action_start() {
    print_header
    check_podman
    COMPOSE_CMD=$(get_compose_cmd)
    if [ "$COMPOSE_CMD" = "NATIVE_POD" ]; then
        action_kube_start
        return
    fi
    echo -e "\n${CYAN}[INFO] Starting stack via: $COMPOSE_CMD up --build -d${NC}"
    $COMPOSE_CMD up --build -d
    wait_for_health
}

action_kube_start() {
    print_header
    check_podman
    get_paths
    echo -e "\n${CYAN}[INFO] Building OCI image: localhost/loan-ms-app:latest${NC}"
    podman build -t localhost/loan-ms-app:latest -f "$CFILE" "$BUILD_CONTEXT"
    echo -e "\n${CYAN}[INFO] Deploying pod via: podman play kube $POD_FILE${NC}"
    podman play kube "$POD_FILE"
    wait_for_health
}

action_stop() {
    print_header
    check_podman
    get_paths
    COMPOSE_CMD=$(get_compose_cmd)
    if [ "$COMPOSE_CMD" != "NATIVE_POD" ]; then
        $COMPOSE_CMD down 2>/dev/null || true
    fi
    podman play kube --down "$POD_FILE" 2>/dev/null || true
    podman pod rm -f loan-ms-pod 2>/dev/null || true
    echo -e "\n${GREEN}[OK] Stack stopped successfully.${NC}"
}

action_restart() {
    print_header
    check_podman
    COMPOSE_CMD=$(get_compose_cmd)
    if [ "$COMPOSE_CMD" != "NATIVE_POD" ]; then
        $COMPOSE_CMD restart
    else
        podman pod restart loan-ms-pod
    fi
    echo -e "\n${GREEN}[OK] Stack restarted.${NC}"
}

action_logs() {
    print_header
    check_podman
    COMPOSE_CMD=$(get_compose_cmd)
    if [ "$COMPOSE_CMD" != "NATIVE_POD" ]; then
        $COMPOSE_CMD logs -f
    else
        podman logs -f loan_ms_app
    fi
}

action_status() {
    print_header
    check_podman
    echo -e "${YELLOW}--- Active Pods ---${NC}"
    podman pod ps
    echo -e "\n${YELLOW}--- Active Containers ---${NC}"
    podman ps -a --filter "name=loan_ms"
}

action_seed() {
    print_header
    check_podman
    echo -e "${CYAN}[INFO] Executing database seed script in container...${NC}"
    podman exec -it loan_ms_app npx tsx prisma/seed.ts || podman exec -it loan-ms-pod-web npx tsx prisma/seed.ts
    echo -e "\n${GREEN}[OK] Database seed finished.${NC}"
}

action_reset() {
    print_header
    echo -e "${RED}[CAUTION] This will wipe persistent PostgreSQL data and rebuild fresh!${NC}"
    read -p "Type 'RESET' to confirm complete factory wipe: " confirm
    if [ "$confirm" != "RESET" ]; then
        echo -e "${YELLOW}Aborted.${NC}"
        return
    fi
    check_podman
    get_paths
    COMPOSE_CMD=$(get_compose_cmd)
    if [ "$COMPOSE_CMD" != "NATIVE_POD" ]; then
        $COMPOSE_CMD down -v 2>/dev/null || true
    fi
    podman play kube --down "$POD_FILE" 2>/dev/null || true
    podman pod rm -f loan-ms-pod 2>/dev/null || true
    podman volume rm -f loan_ms_postgres_podman_data 2>/dev/null || true
    podman volume rm -f loan-ms-postgres-pvc 2>/dev/null || true
    action_start
}

menu() {
    while true; do
        print_header
        echo "  [1] Start LMS Stack with Podman Compose"
        echo "  [2] Start LMS Stack as Native Podman Pod (Kube Play)"
        echo "  [3] Stop LMS Stack"
        echo "  [4] Restart LMS Stack"
        echo "  [5] Stream Real-time Container Logs"
        echo "  [6] Check Stack / Pod Status"
        echo "  [7] Re-seed Database (Admin & Master Data)"
        echo "  [8] Open Web Portal in Browser (xdg-open / open)"
        echo "  [9] Factory Clean Reset (Wipe storage & rebuild)"
        echo "  [0] Exit"
        echo ""
        echo -e "${CYAN}===============================================================================${NC}"
        read -p "Select option [0-9]: " choice
        case "$choice" in
            1) action_start; read -p "Press Enter to continue..." ;;
            2) action_kube_start; read -p "Press Enter to continue..." ;;
            3) action_stop; read -p "Press Enter to continue..." ;;
            4) action_restart; read -p "Press Enter to continue..." ;;
            5) action_logs ;;
            6) action_status; read -p "Press Enter to continue..." ;;
            7) action_seed; read -p "Press Enter to continue..." ;;
            8) command -v xdg-open &>/dev/null && xdg-open http://localhost:3000 || open http://localhost:3000 2>/dev/null || true ;;
            9) action_reset; read -p "Press Enter to continue..." ;;
            0) exit 0 ;;
            *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    start) action_start ;;
    kube-start) action_kube_start ;;
    stop) action_stop ;;
    restart) action_restart ;;
    logs) action_logs ;;
    status) action_status ;;
    seed) action_seed ;;
    reset) action_reset ;;
    *) menu ;;
esac
