#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-}"
rotate="${2:-}"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run this script as the WSL root user." >&2
    exit 1
fi

if [[ -z "$repo_root" || ! -f "$repo_root/.env.example" ]]; then
    echo "Usage: $0 /path/to/repository [--rotate]" >&2
    exit 2
fi

env_path="$repo_root/.env"
if [[ -e "$env_path" && "$rotate" != "--rotate" ]]; then
    echo "$env_path already exists; use --rotate to replace its local credentials." >&2
    exit 3
fi

database="airflow_demo"
role="airflow_demo"
database_password="$(openssl rand -hex 24)"
minio_password="$(openssl rand -hex 24)"
airflow_admin_password="$(openssl rand -hex 24)"

role_exists="$(runuser -u postgres -- psql -XAtqc "SELECT 1 FROM pg_roles WHERE rolname = '$role'" postgres)"
if [[ "$role_exists" != "1" ]]; then
    runuser -u postgres -- psql -X --set=ON_ERROR_STOP=1 postgres \
        --command="CREATE ROLE $role LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD '$database_password';"
else
    runuser -u postgres -- psql -X --set=ON_ERROR_STOP=1 postgres \
        --command="ALTER ROLE $role WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD '$database_password';"
fi

database_exists="$(runuser -u postgres -- psql -XAtqc "SELECT 1 FROM pg_database WHERE datname = '$database'" postgres)"
if [[ "$database_exists" != "1" ]]; then
    runuser -u postgres -- createdb --owner="$role" --encoding=UTF8 "$database"
fi

runuser -u postgres -- psql -X --set=ON_ERROR_STOP=1 postgres <<SQL
ALTER DATABASE $database OWNER TO $role;
REVOKE ALL ON DATABASE $database FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE $database TO $role;
SQL

runuser -u postgres -- psql -X --set=ON_ERROR_STOP=1 "$database" <<SQL
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE, CREATE ON SCHEMA public TO $role;
SQL

umask 077
temp_env="$(mktemp)"
trap 'rm -f "$temp_env"' EXIT
cat >"$temp_env" <<ENV
# Generated locally. This file is ignored by Git; never commit or share it.
AIRFLOW_METADATA_URL=postgresql://$role:$database_password@host.docker.internal:5432/$database?sslmode=require
MINIO_ROOT_USER=lakehouse_demo
MINIO_ROOT_PASSWORD=$minio_password
AIRFLOW_ADMIN_PASSWORD=$airflow_admin_password
DIGITALOCEAN_REGION=sgp1
DIGITALOCEAN_SIZE=s-4vcpu-8gb
DIGITALOCEAN_SSH_KEY_FINGERPRINT=
ENV
install -m 600 "$temp_env" "$env_path"

echo "Provisioned dedicated PostgreSQL database '$database' and restricted role '$role'."
echo "Wrote local-only credentials to $env_path without displaying them."
