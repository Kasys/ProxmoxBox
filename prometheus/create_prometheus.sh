#!/bin/bash
set -e

# Configuration
CTID=102
HOSTNAME=prometheus
IP=192.168.213.61/24
GATEWAY=192.168.213.254
BRIDGE=vmbr0
PASSWORD=${PASSWORD:?Set PASSWORD environment variable}

# Storage names depend on your Proxmox installation
TEMPLATE_STORAGE=local
ROOTFS_STORAGE=local-lvm

# Download Debian template
pveam update

TEMPLATE=$(pveam available --section system | grep "debian-12-standard" | tail -1 | awk '{print $2}')

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

sleep 5

# Install Prometheus
pct exec $CTID -- bash <<'EOF'
apt update
apt install -y prometheus

systemctl enable prometheus
systemctl start prometheus
EOF

echo "Prometheus installed!"
echo "Open: http://$IP:9090"