#!/usr/bin/env bash
# install-tomcat11.sh — Install Apache Tomcat 11.0.7 on Amazon Linux / RHEL unregistered
# Requirements:
#   • Must run as root (or via sudo)
#   • curl, tar, sha512sum, gpg2, systemctl, yum
#   • Network access to https://dlcdn.apache.org and https://corretto.aws
# Logs → stdout (or redirect to /var/log/install-tomcat.log)
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

CORRETTO_RPM="amazon-corretto-17-x64-linux-jdk.rpm"
CORRETTO_URL="https://corretto.aws/downloads/latest/${CORRETTO_RPM}"

#### 2) INSTALL PREREQS & AMAZON CORRETTO 17 ####
echo "==> Installing prerequisites + Amazon Corretto 17..."
yum install -y tar wget gnupg2 shadow-utils coreutils

# Download & install Corretto
curl -sSL -o "/tmp/${CORRETTO_RPM}" "${CORRETTO_URL}"
yum localinstall -y "/tmp/${CORRETTO_RPM}"

# Set JAVA_HOME
export JAVA_HOME="/usr/lib/jvm/java-17-amazon-corretto"
echo "→ JAVA_HOME=${JAVA_HOME}"

#### 3) CREATE tomcat USER & GROUP ####
echo "==> Creating tomcat user/group..."
getent group "${TOMCAT_GROUP}" &>/dev/null || groupadd --system "${TOMCAT_GROUP}"
id -u "${TOMCAT_USER}" &>/dev/null || useradd --system \
  --gid "${TOMCAT_GROUP}" \
  --home "${INSTALL_DIR}" \
  --shell /sbin/nologin \
  "${TOMCAT_USER}"

#### 4) DOWNLOAD & VERIFY TOMCAT ####
echo "==> Downloading Tomcat ${TOMCAT_VERSION}..."
cd /tmp
for F in "${CORE_TGZ}" "${CORE_ASC}" "${CORE_SHA}"; do
  [ -f "$F" ] || curl -sSL "${TOMCAT_BASE_URL}/${F}" -o "$F"
done

echo "==> Fetching KEYS..."
curl -sSL "${KEYS_URL}" -o KEYS

echo "==> Verifying PGP signature..."
gpg2 --batch --quiet --import KEYS || true
gpg2 --batch --quiet --verify "${CORE_ASC}" "${CORE_TGZ}" \
  || echo "⚠️ PGP verify failed, continuing..."

echo "==> Verifying SHA-512 checksum..."
sha512sum -c "${CORE_SHA}" \
  || echo "⚠️ SHA-512 check failed, continuing..."

#### 5) INSTALL & LOCK DOWN ####
echo "==> Installing to ${INSTALL_DIR}..."
mkdir -p "${INSTALL_DIR}"
tar xzf "${CORE_TGZ}" -C "${INSTALL_DIR}" --strip-components=1

echo "==> Setting ownership & perms..."
chown -R "${TOMCAT_USER}:${TOMCAT_GROUP}" "${INSTALL_DIR}"
find "${INSTALL_DIR}" -type d -exec chmod 750 {} +
find "${INSTALL_DIR}" -type f -exec chmod 640 {} +
chmod +x "${INSTALL_DIR}/bin/"*.sh

#### 6) GRANT ec2-user READ/TRAVERSE ACCESS ####
echo "==> Adding ec2-user to tomcat group & fixing traverse perms..."
usermod -aG "${TOMCAT_GROUP}" ec2-user || true
# grant 'execute' bit on dirs so group members can cd into them
find "${INSTALL_DIR}" -type d -exec chmod g+rx {} +

echo "  → Note: ec2-user must logout/login or run 'newgrp tomcat' to pick up new group."

#### 7) CREATE systemd UNIT ####
echo "==> Writing systemd unit..."
cat > /etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Apache Tomcat ${TOMCAT_VERSION}
After=network.target

[Service]
Type=forking
User=${TOMCAT_USER}
Group=${TOMCAT_GROUP}
Environment="JAVA_HOME=${JAVA_HOME}"
Environment="CATALINA_HOME=${INSTALL_DIR}"
Environment="CATALINA_BASE=${INSTALL_DIR}"
Environment="CATALINA_PID=${INSTALL_DIR}/temp/tomcat.pid"
ExecStart=${INSTALL_DIR}/bin/catalina.sh start
ExecStop=${INSTALL_DIR}/bin/catalina.sh stop
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

#### 8) ENABLE & START ####
echo "==> Enabling & starting Tomcat..."
systemctl daemon-reload
systemctl enable --now tomcat

echo "✅ Tomcat ${TOMCAT_VERSION} installed at ${INSTALL_DIR}"
echo "👉 Verify with 'systemctl status tomcat'"
echo "🔓 Remember to open port 8080 in your Security Group!"

