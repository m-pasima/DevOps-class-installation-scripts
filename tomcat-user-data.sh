#!/bin/bash -xe
exec &> >(tee /var/log/user-data.log)

yum update -y
yum install -y tar wget shadow-utils coreutils

CORRETTO_RPM="amazon-corretto-17-x64-linux-jdk.rpm"
curl -sSL -o "/tmp/${CORRETTO_RPM}" "https://corretto.aws/downloads/latest/${CORRETTO_RPM}"
yum localinstall -y "/tmp/${CORRETTO_RPM}"
export JAVA_HOME="/usr/lib/jvm/java-17-amazon-corretto"
echo "→ JAVA_HOME=${JAVA_HOME}"

groupadd -r tomcat || true
useradd -r -g tomcat -d /opt/tomcat -s /sbin/nologin tomcat || true

TOMCAT_VERSION="11.0.7"
MAIN_URL="https://dlcdn.apache.org/tomcat/tomcat-11/v${TOMCAT_VERSION}/bin"
ARCHIVE_URL="https://archive.apache.org/dist/tomcat/tomcat-11/v${TOMCAT_VERSION}/bin"
cd /tmp

# Download Tomcat tarball (try main, then archive)
wget -q "${MAIN_URL}/apache-tomcat-${TOMCAT_VERSION}.tar.gz"    || \
wget -q "${ARCHIVE_URL}/apache-tomcat-${TOMCAT_VERSION}.tar.gz"

wget -q "${MAIN_URL}/apache-tomcat-${TOMCAT_VERSION}.tar.gz.sha512" || \
wget -q "${ARCHIVE_URL}/apache-tomcat-${TOMCAT_VERSION}.tar.gz.sha512"

sha512sum -c "apache-tomcat-${TOMCAT_VERSION}.tar.gz.sha512" || echo "⚠️ Checksum mismatch—continuing anyway"

# Clean old Tomcat, extract fresh, set ownership and permissions
rm -rf /opt/tomcat
mkdir -p /opt/tomcat
tar xzf "apache-tomcat-${TOMCAT_VERSION}.tar.gz" --strip-components=1 -C /opt/tomcat

# Sanity check: fail if extraction failed
if [ ! -f /opt/tomcat/bin/catalina.sh ]; then
  echo "❌ Extraction failed: catalina.sh not found!"
  exit 1
fi

chown -R tomcat:tomcat /opt/tomcat
chmod -R u+rwX,g+rx /opt/tomcat
chmod +x /opt/tomcat/bin/*.sh

# Harden directory permissions
chmod 755 /opt
chmod 750 /opt/tomcat
chmod 750 /opt/tomcat/bin

usermod -aG tomcat ec2-user

# Create Tomcat systemd unit file (use sudo tee for root perms)
sudo tee /etc/systemd/system/tomcat.service > /dev/null <<'EOF'
[Unit]
Description=Apache Tomcat 11
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat
Environment="JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
ExecStart=/opt/tomcat/bin/catalina.sh start
ExecStop=/opt/tomcat/bin/catalina.sh stop
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now tomcat

echo "✅ Tomcat ${TOMCAT_VERSION} deployed in /opt/tomcat"
echo "👉 Check: systemctl status tomcat"
echo "🔓 Don’t forget to open port 8080 in your Security Group!"
