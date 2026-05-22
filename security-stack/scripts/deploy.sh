#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DEPLOY SCRIPT — Security Stack
# Запускает всю систему безопасности в Docker
# ═══════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔══════════════════════════════════════════╗"
echo "║     Security Stack Deployment Tool       ║"
echo "╚══════════════════════════════════════════╝"

# ─────────────────────────────────────
# Проверка зависимостей
# ─────────────────────────────────────
check_deps() {
    echo "[*] Checking dependencies..."
    for cmd in docker docker-compose; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "[ERROR] $cmd is not installed"
            exit 1
        fi
    done

    # Проверка версии Docker
    DOCKER_VERSION=$(docker --version | grep -oP '\d+\.\d+' | head -1)
    echo "[OK] Docker $DOCKER_VERSION found"

    # Проверка прав
    if ! docker info &>/dev/null; then
        echo "[ERROR] Cannot connect to Docker daemon. Run as root or add user to docker group"
        exit 1
    fi
}

# ─────────────────────────────────────
# Настройка системы
# ─────────────────────────────────────
setup_system() {
    echo "[*] Configuring system settings..."

    # Необходимо для OpenSearch/Wazuh Indexer
    if [ "$(sysctl -n vm.max_map_count)" -lt 262144 ]; then
        echo "[*] Setting vm.max_map_count=262144"
        sysctl -w vm.max_map_count=262144
        echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    fi

    # Настройка лимитов
    if ! grep -q "* soft nofile 65536" /etc/security/limits.conf; then
        echo "* soft nofile 65536" >> /etc/security/limits.conf
        echo "* hard nofile 65536" >> /etc/security/limits.conf
    fi

    echo "[OK] System settings configured"
}

# ─────────────────────────────────────
# Генерация SSL сертификатов
# ─────────────────────────────────────
generate_certs() {
    echo "[*] Generating SSL certificates..."
    mkdir -p "$PROJECT_DIR/nginx/ssl"

    if [ ! -f "$PROJECT_DIR/nginx/ssl/server.crt" ]; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$PROJECT_DIR/nginx/ssl/server.key" \
            -out "$PROJECT_DIR/nginx/ssl/server.crt" \
            -subj "/C=RU/ST=Moscow/L=Moscow/O=Security/CN=security.local" \
            2>/dev/null
        echo "[OK] SSL certificate generated"
    else
        echo "[OK] SSL certificate already exists"
    fi
}

# ─────────────────────────────────────
# Запуск стека
# ─────────────────────────────────────
start_stack() {
    echo "[*] Starting security stack..."
    cd "$PROJECT_DIR"

    # Сборка образов
    echo "[*] Building custom images..."
    docker-compose build --no-cache nginx-waf

    # Запуск в правильном порядке
    echo "[*] Starting infrastructure services..."
    docker-compose up -d wazuh-indexer
    echo "[*] Waiting for Wazuh Indexer to be ready (60s)..."
    sleep 60

    echo "[*] Starting Wazuh Manager..."
    docker-compose up -d wazuh-manager
    sleep 30

    echo "[*] Starting remaining services..."
    docker-compose up -d

    echo "[OK] All services started"
}

# ─────────────────────────────────────
# Проверка статуса
# ─────────────────────────────────────
check_status() {
    echo ""
    echo "[*] Checking service status..."
    cd "$PROJECT_DIR"
    docker-compose ps

    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║           Access Information             ║"
    echo "╠══════════════════════════════════════════╣"
    echo "║ Wazuh Dashboard:  https://localhost:443  ║"
    echo "║ MinIO Console:    http://localhost:9001  ║"
    echo "║ Wazuh API:        https://localhost:55000║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "Default credentials are in .env file"
}

# ─────────────────────────────────────
# Остановка стека
# ─────────────────────────────────────
stop_stack() {
    echo "[*] Stopping security stack..."
    cd "$PROJECT_DIR"
    docker-compose down
    echo "[OK] Stack stopped"
}

# ─────────────────────────────────────
# Полная очистка
# ─────────────────────────────────────
clean_stack() {
    echo "[WARNING] This will remove all containers and volumes!"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        cd "$PROJECT_DIR"
        docker-compose down -v --remove-orphans
        echo "[OK] Stack cleaned"
    fi
}

# ─────────────────────────────────────
# Главное меню
# ─────────────────────────────────────
case "${1:-}" in
    start)
        check_deps
        setup_system
        generate_certs
        start_stack
        check_status
        ;;
    stop)
        stop_stack
        ;;
    status)
        check_status
        ;;
    clean)
        clean_stack
        ;;
    restart)
        stop_stack
        sleep 5
        start_stack
        check_status
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart|clean}"
        echo ""
        echo "  start   — Deploy and start all services"
        echo "  stop    — Stop all services"
        echo "  status  — Show service status and access info"
        echo "  restart — Restart all services"
        echo "  clean   — Remove all containers and volumes"
        exit 1
        ;;
esac
