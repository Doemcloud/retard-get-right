#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Docker Installation Script for Kali Linux
# Запускать: sudo bash install-docker.sh
# ═══════════════════════════════════════════════════════════

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[-]${NC} $1"; exit 1; }

# Проверка root
[ "$EUID" -ne 0 ] && err "Run as root: sudo bash $0"

log "Starting Docker installation on Kali Linux..."

# ─────────────────────────────────────
# 1. Удаление старых версий
# ─────────────────────────────────────
log "Removing old Docker versions..."
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# ─────────────────────────────────────
# 2. Установка зависимостей
# ─────────────────────────────────────
log "Installing dependencies..."
apt-get update -qq
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common

# ─────────────────────────────────────
# 3. Добавление Docker GPG ключа
# ─────────────────────────────────────
log "Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# ─────────────────────────────────────
# 4. Добавление репозитория
# Kali основан на Debian, используем bookworm
# ─────────────────────────────────────
log "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian bookworm stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# ─────────────────────────────────────
# 5. Установка Docker
# ─────────────────────────────────────
log "Installing Docker Engine..."
apt-get update -qq
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# ─────────────────────────────────────
# 6. Запуск и автозапуск Docker
# ─────────────────────────────────────
log "Starting Docker service..."
systemctl enable docker
systemctl start docker

# ─────────────────────────────────────
# 7. Добавление пользователя в группу docker
# ─────────────────────────────────────
REAL_USER="${SUDO_USER:-$USER}"
if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
    log "Adding $REAL_USER to docker group..."
    usermod -aG docker "$REAL_USER"
    warn "You need to log out and back in for group changes to take effect"
    warn "Or run: newgrp docker"
fi

# ─────────────────────────────────────
# 8. Настройка системы для Wazuh/OpenSearch
# ─────────────────────────────────────
log "Configuring system settings for Wazuh..."
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" >> /etc/sysctl.conf

# Лимиты файловых дескрипторов
cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 65536
* hard nofile 65536
* soft nproc 4096
* hard nproc 4096
EOF

# ─────────────────────────────────────
# 9. Проверка установки
# ─────────────────────────────────────
log "Verifying installation..."
docker --version
docker compose version

# Тест
docker run --rm hello-world 2>&1 | grep -q "Hello from Docker" && \
    log "Docker is working correctly!" || \
    err "Docker test failed"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Docker installed successfully!       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo "  1. Run: newgrp docker   (or re-login)"
echo "  2. cd security-stack"
echo "  3. sudo bash scripts/deploy.sh start"
