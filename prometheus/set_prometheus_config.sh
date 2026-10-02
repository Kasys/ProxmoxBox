CTID=102

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "${LOAD_FROM_REPO+x}" ]; then
    # Reload repo
    bash "${SCRIPT_DIR}/../reload_repo.sh"
fi

# Put config files
pct push $CTID "$SCRIPT_DIR/prometheus.yml" "/etc/prometheus/prometheus.yml"

pct exec $CTID -- bash <<'EOF'
systemctl restart prometheus
EOF