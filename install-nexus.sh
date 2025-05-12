#!/usr/bin/env bash
#
# install-nexus.sh — Sonatype Nexus Repository OSS installer for RHEL/CentOS
## 1. Make the script executable (only once)
#chmod +x install-nexus.sh

# 2. Run it with sudo
#sudo ./install-nexus.sh
# Requirements:
#   • RHEL/CentOS 7, 8, or 9 (any systemd-based RPM distro should work)
#   • 2 GB RAM minimum (4 GB+ recommended for production)
#   • 2 CPU cores minimum
#   • 10 GB free disk for binaries + data
#   • Java 11 or Java 17 (we’ll install OpenJDK 17)
#   • curl, tar, yum (dnf works too), systemd
#   • root or sudo privileges
#   • Internet access to download Nexus bundle
#
# Example usage:
#   chmod +x install-nexus.sh
#   sudo ./install-nexus.sh
#
# Pitfalls to watch:
#   • SELinux: enforcing may block startup—see SELinux section below
#   • Firewall: open TCP/8081 to reach the UI
#   • Java conflicts: ensure `java -version` shows OpenJDK 17
#
set -euo pipefail

### 1) CONFIGURE THESE VARIABLES ###
NEXUS_VERSION="3.75.1-01"                                           # Nexus version
INSTALL_DIR="/opt"                                                  # Where binaries go
NEXUS_USER="nexus"                                                  # Dedicated system user
NEXUS_GROUP="nexus"                                                 # Dedicated group
DOWNLOAD_URL="https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz"
TMP_TARBALL="/tmp/nexus-${NEXUS_VERSION}.tar.gz"                     # Temp download path
DATA_DIR="/opt/sonatype-work"                                       # Where Nexus stores repos
#####################################

echo ">>> [1/8] Installing Java (OpenJDK 17)..."
# Nexus 3.75+ requires Java 11 or 17. We choose 17 for long-term support.
# On RHEL 9 you may need `dnf` instead of `yum`.
yum install -y java-17-openjdk-devel

echo ">>> [2/8] Creating nexus user & group..."
# Running Nexus as root is like giving car keys to a toddler — dangerous.
getent group "${NEXUS_GROUP}" >/dev/null || groupadd --system "${NEXUS_GROUP}"
id -u "${NEXUS_USER}" >/dev/null 2>&1 || \
  useradd --system -g "${NEXUS_GROUP}" \
          -d "${INSTALL_DIR}/nexus-${NEXUS_VERSION}" \
          -s /sbin/nologin "${NEXUS_USER}"

echo ">>> [3/8] Downloading Nexus ${NEXUS_VERSION}..."
# -f: fail on HTTP error; -S: show errors; -L: follow redirects
curl -fSL "${DOWNLOAD_URL}" -o "${TMP_TARBALL}"

echo ">>> [4/8] Extracting Nexus to ${INSTALL_DIR}..."
tar -xzf "${TMP_TARBALL}" -C "${INSTALL_DIR}"
# The archive unpacks into INSTALL_DIR/nexus-${NEXUS_VERSION}

echo ">>> [5/8] Setting up directories & permissions..."
# Create data directory for blob stores & configs
mkdir -p "${DATA_DIR}"
# chown both binaries and data to nexus:nexus
chown -R "${NEXUS_USER}:${NEXUS_GROUP}" \
    "${INSTALL_DIR}/nexus-${NEXUS_VERSION}" \
    "${DATA_DIR}"

echo ">>> [6/8] Creating stable symlink: /opt/nexus → nexus-${NEXUS_VERSION}"
# Symlink lets future upgrades be a one-liner: extract + ln -sfn
ln -sfn "${INSTALL_DIR}/nexus-${NEXUS_VERSION}" "${INSTALL_DIR}/nexus"

echo ">>> [7/8] Configuring Nexus to run as ${NEXUS_USER}..."
# Set the run_as_user in bin/nexus.rc so systemd can switch users
sed -i \
  -e "s|#run_as_user=.*|run_as_user=\"${NEXUS_USER}\"|" \
  "${INSTALL_DIR}/nexus/bin/nexus.rc"

echo ">>> [8/8] Creating & enabling systemd service..."
cat > /etc/systemd/system/nexus.service <<EOF
[Unit]
Description=Sonatype Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536                  # allow many file handles
ExecStart=${INSTALL_DIR}/nexus/bin/nexus start
ExecStop=${INSTALL_DIR}/nexus/bin/nexus stop
User=${NEXUS_USER}
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable at boot, and start now
systemctl daemon-reload
systemctl enable nexus
systemctl start nexus

echo
echo "✅ Nexus Repository OSS ${NEXUS_VERSION} is now running!"
echo "👉 Access the UI at: http://<YOUR-SERVER-IP>:8081"
echo
echo "📖 Next steps:"
echo "   • Open TCP/8081 in your firewall: firewall-cmd --permanent --add-port=8081/tcp && firewall-cmd --reload"
echo "   • (SELinux) If Nexus fails to start, try:"
echo "       chcon -R -t container_file_t /opt/nexus*"
echo "   • Browse the logs: tail -f /opt/sonatype-work/log/*.log"

