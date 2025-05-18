#!/bin/bash
# install-tomcat11-userdata.sh — User Data: Install Apache Tomcat 11.0.7 on RHEL 8+ (EC2 Ready)
# Paste in EC2 "User Data" — runs as root on first boot
# Logs: See /var/log/user-data.log for errors & troubleshooting

exec > /var/log/user-data.log 2>&1
set -euo pipefail
IFS=$'\n\t'

#### 1) CONFIGURATION VARIABLES ####
TOMCAT_VERSION="11.0.7"
TOMCAT_BASE_URL="https://dlcdn.apache.org/tomcat/tomcat-11/v${TOMCAT_VERSION}/bin"
INSTALL_DIR="/opt/tomcat"
TOMCAT_USER="tomcat"
TOMCAT_GROUP="tomcat"
KEYS_URL="https://dlcdn.apache.org/tomcat/tomcat-11/KEYS"

CORE_TGZ="apache-tomcat-${TOMCAT_VERSION}.tar.gz"
CORE_ASC="${CORE_TGZ}.asc"
CORE_SHA="${CORE_TGZ}.sha512"

#### 2) SET SELINUX TO PERMISSIVE (DEMO/DEV ONLY) ####
# ❗ For production, properly configure SELinux or use custom policies!
if command -v setenforce &>/dev/null; then
  setenforce 0 || true
  sed -i 's/^SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
fi

#### 3) INSTALL PREREQUISITES ####
dnf install -y java-17-openjdk-devel curl tar gnupg2
dnf install -y git vim tree 

# Ensure groupadd/useradd/sha512sum exist
dnf install -y shadow-utils coreutils

#### 4) JAVA_HOME DETECTION ####
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"
echo "JAVA_HOME set to $JAVA_HOME"

#### 5) CREATE tomcat USER & GROUP (IDEMPOTENT) ####
getent group "${TOMCAT_GROUP}" >/dev/null || groupadd --system "${TOMCAT_GROUP}"

id -u "${TOMCAT_USER}" >/dev/null 2>&1 || useradd --system \
  --gid "${TOMCAT_GROUP}" \
  --shell /sbin/nologin \
  --home "${INSTALL_DIR}" \
  "${TOMCAT_USER}"

#### 6) DOWNLOAD & VERIFY TOMCAT ####
cd /tmp
for file in "${CORE_TGZ}" "${CORE_ASC}" "${CORE_SHA}"; do
  if [ ! -f "${file}" ]; then
    curl -sSL "${TOMCAT_BASE_URL}/${file}" -o "${file}"
  fi
done

curl -sSL "${KEYS_URL}" -o KEYS

gpg2 --import KEYS || true  # Import, but don't fail if already imported
gpg2 --verify "${CORE_ASC}" "${CORE_TGZ}"
sha512sum -c "${CORE_SHA}"

#### 7) INSTALL & SET PERMISSIONS ####
mkdir -p "${INSTALL_DIR}"
tar xzf "${CORE_TGZ}" -C "${INSTALL_DIR}" --strip-components=1

chown -R "${TOMCAT_USER}:${TOMCAT_GROUP}" "${INSTALL_DIR}"
find "${INSTALL_DIR}" -type d -exec chmod 750 {} \;
find "${INSTALL_DIR}" -type f -exec chmod 640 {} \;
chmod +x "${INSTALL_DIR}/bin/"*.sh

# Grant ec2-user group access for /opt/tomcat
usermod -aG "${TOMCAT_GROUP}" ec2-user || true
echo "  → Note: ec2-user must re-login (or run 'newgrp ${TOMCAT_GROUP}') to pick up group membership."

#### 8) CREATE systemd SERVICE ####
cat > /etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Apache Tomcat 11
After=network.target

[Service]
Type=forking
User=${TOMCAT_USER}
Group=${TOMCAT_GROUP}
Environment="JAVA_HOME=${JAVA_HOME}"
Environment="CATALINA_HOME=${INSTALL_DIR}"
Environment="CATALINA_BASE=${INSTALL_DIR}"
Environment="CATALINA_PID=${INSTALL_DIR}/temp/tomcat.pid"
ExecStart=${INSTALL_DIR}/bin/startup.sh
ExecStop=${INSTALL_DIR}/bin/shutdown.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

#### 9) ENABLE & START TOMCAT ####
systemctl daemon-reload
systemctl enable --now tomcat

#### 10) STATUS OUTPUT ####
echo "==> Tomcat installed. Status:"
systemctl status tomcat --no-pager

#### 11) SECURITY GROUP REMINDER (AWS) ####
echo "==> REMINDER: Ensure port 8080 is open in your EC2 security group for web access."

#### 12) USER LOGOUT WARNING ####
echo "==> If using 'ec2-user', you must log out and back in (or 'newgrp tomcat') to access /opt/tomcat as a group member."

# END OF SCRIPT
