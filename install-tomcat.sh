#!/usr/bin/env bash
# install-tomcat11.sh — Install Apache Tomcat 11.0.7 on Amazon Linux / RHEL
# Requirements:
#   • Must run as root (or via sudo)
#   • curl, tar, sha512sum, gpg2, systemctl, yum
#   • Network access to https://dlcdn.apache.org
#   • Java 17+ (installed by this script)
#   • Firewall Rules: Open port 8080 in firewalld or your AWS SG. 
#   • Pitfall: Linux only recognizes your new group membership at login-time. 
#   • You’ll need to log out and back in (or run newgrp tomcat) before ec2-user can actually browse /opt/tomcat.
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

#### 2) INSTALL JAVA 17+ WITH JDK (for Red Hat) ####
echo "==> Installing Java 17 OpenJDK with development tools (includes 'jar')..."

sudo dnf install -y java-17-openjdk-devel

# Auto-detect JAVA_HOME and export it
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"
echo "JAVA_HOME set to $JAVA_HOME"


#### 3) CREATE tomcat USER & GROUP ####
echo "==> Creating ${TOMCAT_USER} system user/group..."
getent group "${TOMCAT_GROUP}" >/dev/null \
  || groupadd --system "${TOMCAT_GROUP}"

id -u "${TOMCAT_USER}" >/dev/null 2>&1 \
  || useradd --system \
             --gid "${TOMCAT_GROUP}" \
             --shell /sbin/nologin \
             --home "${INSTALL_DIR}" \
             "${TOMCAT_USER}"

#### 4) DOWNLOAD & VERIFY TOMCAT ####
cd /tmp
echo "==> Downloading Tomcat ${TOMCAT_VERSION}..."
for file in "${CORE_TGZ}" "${CORE_ASC}" "${CORE_SHA}"; do
  curl -sSL "${TOMCAT_BASE_URL}/${file}" -o "${file}"
done

echo "==> Downloading KEYS for PGP verification..."
curl -sSL "${KEYS_URL}" -o KEYS

echo "==> Importing KEYS into GPG..."
gpg2 --import KEYS

echo "==> Verifying PGP signature..."
gpg2 --verify "${CORE_ASC}" "${CORE_TGZ}"

echo "==> Verifying SHA-512 checksum..."
sha512sum -c "${CORE_SHA}"

#### 5) INSTALL & LOCK DOWN PERMISSIONS ####
echo "==> Installing Tomcat to ${INSTALL_DIR}..."
mkdir -p "${INSTALL_DIR}"
tar xzf "${CORE_TGZ}" -C "${INSTALL_DIR}" --strip-components=1

echo "==> Setting ownership & permissions..."
chown -R "${TOMCAT_USER}:${TOMCAT_GROUP}" "${INSTALL_DIR}"
# Directories 750 → owner=rwx, group=r-x
find "${INSTALL_DIR}" -type d -exec chmod 750 {} \;
# Files 640 → owner=rw, group=r
find "${INSTALL_DIR}" -type f -exec chmod 640 {} \;
chmod +x "${INSTALL_DIR}/bin/"*.sh

#### 5.1) GRANT ec2-user READ/EXEC ACCESS ####
echo "==> Adding ec2-user to '${TOMCAT_GROUP}' group..."
usermod -aG "${TOMCAT_GROUP}" ec2-user
echo "  → Note: ec2-user must re-login (or run 'newgrp ${TOMCAT_GROUP}') to pick up group membership."

#### 6) CREATE systemd UNIT ####
echo "==> Writing systemd service file..."
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

#### 7) ENABLE & START TOMCAT ####
echo "==> Reloading systemd, enabling & starting Tomcat..."
systemctl daemon-reload
systemctl enable --now tomcat

echo "==> Done! Tomcat status:"
systemctl status tomcat --no-pager
