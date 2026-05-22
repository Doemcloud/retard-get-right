# Security Stack — Docker Deployment

Комплексная система безопасности в Docker контейнерах.

## Компоненты

| Сервис | Роль | Порты |
|--------|------|-------|
| **Wazuh Manager** | SIEM + FIM + Логирование | 1514, 1515, 514, 55000 |
| **Wazuh Indexer** | OpenSearch (хранилище) | 9200 |
| **Wazuh Dashboard** | Web UI | 443 |
| **Suricata** | IDS/IPS | host network |
| **MinIO** | Бэкапы | 9000, 9001 |
| **Samba DC** | AD Domain Controller | 53, 88, 389, 445, 636 |
| **Nginx WAF** | OWASP Top 10 защита | 80, 8443 |

## Быстрый старт

```bash
# 1. Клонировать/скопировать папку security-stack
cd security-stack

# 2. Настроить пароли в .env
nano .env

# 3. Запустить
chmod +x scripts/deploy.sh
sudo ./scripts/deploy.sh start
```

## Доступ к сервисам

| Сервис | URL | Логин |
|--------|-----|-------|
| Wazuh Dashboard | https://localhost | admin / (из .env) |
| MinIO Console | http://localhost:9001 | minioadmin / (из .env) |
| Wazuh API | https://localhost:55000 | wazuh / (из .env) |

## Структура файлов

```
security-stack/
├── docker-compose.yml          # Основной compose файл
├── .env                        # Пароли и настройки
├── wazuh/
│   ├── config/ossec.conf       # Конфиг Wazuh (FIM, логи, active response)
│   └── rules/local_rules.xml   # Правила OWASP Top 10 для Wazuh
├── suricata/
│   ├── config/suricata.yaml    # Конфиг Suricata IDS/IPS
│   └── rules/owasp-top10.rules # Правила обнаружения атак
├── nginx/
│   ├── Dockerfile              # Nginx + ModSecurity
│   ├── conf.d/default.conf     # Nginx конфиг с rate limiting
│   └── modsecurity/            # ModSecurity + OWASP CRS правила
├── samba/config/smb.conf       # Samba AD DC конфиг
└── scripts/
    ├── deploy.sh               # Скрипт развёртывания
    └── backup.sh               # Автоматические бэкапы в MinIO
```

## OWASP Top 10 — Покрытие

| # | Угроза | Защита |
|---|--------|--------|
| A01 | Broken Access Control | ModSecurity + Nginx rules + Wazuh rules |
| A02 | Cryptographic Failures | TLS 1.2/1.3 only, Suricata weak TLS detection |
| A03 | Injection (SQLi, XSS, CMDi) | ModSecurity CRS + Suricata + Wazuh |
| A04 | Insecure Design | ModSecurity mass assignment rules |
| A05 | Security Misconfiguration | Nginx headers + file blocking + Wazuh |
| A06 | Vulnerable Components | Wazuh vulnerability detection |
| A07 | Auth Failures | Rate limiting + Wazuh brute force detection + Active Response |
| A08 | Software Integrity | Wazuh FIM (File Integrity Monitoring) |
| A09 | Logging Failures | Wazuh + Suricata + Nginx централизованное логирование |
| A10 | SSRF | ModSecurity + Suricata SSRF rules |

## Управление

```bash
# Статус сервисов
./scripts/deploy.sh status

# Остановить
./scripts/deploy.sh stop

# Перезапустить
./scripts/deploy.sh restart

# Просмотр логов Wazuh
docker logs wazuh-manager -f

# Просмотр алертов Suricata
docker exec suricata tail -f /var/log/suricata/fast.log

# Ручной бэкап
docker exec backup-agent /bin/sh /backup.sh
```

## Требования

- Docker 20.10+
- Docker Compose 2.0+
- RAM: минимум 8 GB (рекомендуется 16 GB)
- Disk: минимум 50 GB
- OS: Linux (для Suricata в host network режиме)

## Безопасность

- Все пароли хранятся в `.env` — **не коммитить в git!**
- Добавьте `.env` в `.gitignore`
- В продакшне замените self-signed сертификаты на реальные
- Настройте firewall для ограничения доступа к портам управления
