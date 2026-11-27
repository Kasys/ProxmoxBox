#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
CTID=101
HOSTNAME=grafana
IP=192.168.213.60/24
GATEWAY=192.168.213.254
BRIDGE=vmbr0
PASSWORD=${PASSWORD:?Set PASSWORD environment variable}

# Storage names depend on your Proxmox installation
TEMPLATE_STORAGE=local
ROOTFS_STORAGE=local-lvm

# Download Debian template
pveam update

TEMPLATE=$(pveam available --section system | grep "debian-12-standard" | grep "amd64" | tail -1 | awk '{print $2}')

if [ -z "$TEMPLATE" ]; then
    echo "No Debian template found"
    exit 1
fi

pveam download $TEMPLATE_STORAGE $TEMPLATE

# Convert filename into Proxmox template volume ID
TEMPLATE="$TEMPLATE_STORAGE:vztmpl/$TEMPLATE"

# Remove existing container
if pct status $CTID &>/dev/null; then
    echo "Removing existing container $CTID"

    pct stop $CTID || true
    pct destroy $CTID
fi

# Create LXC
pct create $CTID $TEMPLATE \
    --hostname $HOSTNAME \
    --password $PASSWORD \
    --cores 2 \
    --memory 2048 \
    --swap 512 \
    --rootfs $ROOTFS_STORAGE:8 \
    --net0 name=eth0,bridge=$BRIDGE,ip=$IP,gw=$GATEWAY \
    --features nesting=1 \
    --unprivileged 1 \
    --onboot 1

# Start container
pct start $CTID

# Wait until container is running
sleep 5

# Install Grafana
pct exec "$CTID" -- env PASSWORD="$PASSWORD" bash <<'EOF'
apt update
apt install -y apt-transport-https wget gnupg

wget -q -O /usr/share/keyrings/grafana.key \
https://apt.grafana.com/gpg.key

echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" \
> /etc/apt/sources.list.d/grafana.list

apt update
apt install -y grafana

cat >> /etc/grafana/grafana.ini <<EOC

[security]
admin_user = admin
admin_password = $PASSWORD
EOC
EOF

# Create provisioning directories
pct exec "$CTID" -- mkdir -p /etc/grafana/provisioning/datasources
pct exec "$CTID" -- mkdir -p /etc/grafana/provisioning/dashboards
pct exec "$CTID" -- mkdir -p /var/lib/grafana/dashboards

# Push datasource configuration
pct push "$CTID" \
    "$SCRIPT_DIR/provisioning/datasources/prometheus.yml" \
    "/etc/grafana/provisioning/datasources/prometheus.yml"

# Push dashboard provider configuration
pct push "$CTID" \
    "$SCRIPT_DIR/provisioning/dashboards/dashboards.yml" \
    "/etc/grafana/provisioning/dashboards/dashboards.yml"

# Push dashboard
pct push "$CTID" \
    "$SCRIPT_DIR/provisioning/dashboards/system-monitoring.json" \
    "/var/lib/grafana/dashboards/system-monitoring.json"

# Set permissions
pct exec "$CTID" -- chown -R grafana:grafana /etc/grafana/provisioning
pct exec "$CTID" -- chown -R grafana:grafana /var/lib/grafana/dashboards

pct exec "$CTID" -- bash <<'EOF'
systemctl enable grafana-server
systemctl start grafana-server
EOF

echo "Grafana installed!"
echo "Open: http://$IP:3000"