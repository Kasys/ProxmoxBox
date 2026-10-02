CTID=102

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Reload repo
bash "${SCRIPT_DIR}/../reload_repo.sh"

# Put config files
pct push $CTID "$SCRIPT_DIR/prometheus.yml" "/etc/prometheus/prometheus.yml"

pct exec $CTID -- bash <<'EOF'
systemctl restart prometheus
EOF