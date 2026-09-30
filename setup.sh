#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting Proxmox setup..."

echo "Creating Grafana..."
"$SCRIPT_DIR/grafana/create_grafana.sh"

echo "Grafana finished."

echo "Creating Prometheus..."
"$SCRIPT_DIR/prometheus/create_prometheus.sh"

echo "Prometheus finished."

echo "Setup complete."