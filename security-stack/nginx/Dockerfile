# ═══════════════════════════════════════════════════════════
# Nginx + ModSecurity (WAF) для защиты от OWASP Top 10
# ═══════════════════════════════════════════════════════════
FROM owasp/modsecurity-crs:nginx-alpine

LABEL maintainer="security-team"
LABEL description="Nginx WAF with ModSecurity + OWASP CRS"

USER root

# Установка дополнительных утилей
RUN apk add --no-cache curl tzdata openssl

# Создаём директории
RUN mkdir -p /var/log/nginx /var/log/modsecurity /etc/nginx/ssl

# Генерируем self-signed сертификат
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/server.key \
    -out /etc/nginx/ssl/server.crt \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=Security/CN=security.local"

# Копируем конфигурацию
COPY conf.d/ /etc/nginx/templates/conf.d/
COPY modsecurity/ /etc/nginx/modsecurity/

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
