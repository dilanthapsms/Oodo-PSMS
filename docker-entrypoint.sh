#!/bin/bash
set -e

# Generate Odoo config from environment variables (set in Dokploy)
cat > /etc/odoo/odoo.conf <<CONF
[options]
addons_path = /opt/odoo/addons,/mnt/extra-addons
data_dir = /var/lib/odoo
http_interface = 0.0.0.0
http_port = 8069
gevent_port = 8072
admin_passwd = ${ADMIN_PASSWD:-admin}
db_host = ${DB_HOST:-db}
db_port = ${DB_PORT:-5432}
db_user = ${DB_USER:-odoo}
db_password = ${DB_PASSWORD:-odoo}
proxy_mode = True
workers = ${ODOO_WORKERS:-0}
max_cron_threads = 1
list_db = ${LIST_DB:-True}
limit_time_cpu = 600
limit_time_real = 1200
limit_memory_soft = 1073741824
limit_memory_hard = 1610612736
CONF

# Wait for PostgreSQL
until pg_isready -h "${DB_HOST:-db}" -p "${DB_PORT:-5432}" -U "${DB_USER:-odoo}" >/dev/null 2>&1; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done

exec python3 /opt/odoo/odoo-bin -c /etc/odoo/odoo.conf "$@"
