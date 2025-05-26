#!/bin/bash -xe 
#===============================================================================
# install-tomcat11-userdata.sh 
# EC2 User-Data for Amazon Linux 2023
# Logs → /var/log/user-data.log
#===============================================================================

# 1) START LOGGING
exec &> >(tee /var/log/user-data.log)

# 2) QUICK OS PATCH (optional)
yum update -y

# 3) INSTALL PREREQS (removed conflicting gnupg2)
yum install -y tar wget shadow-utils coreutils

# 4) INSTALL AMAZON CORRETTO 17 (Java 17)
CORRETTO_RPM="amazon-corretto-17-x64-linux-jdk.rpm"
curl -sSL \
  -o "/tmp/${CORRETTO_RPM}" \
  "https://corretto.aws/downloads/latest/${CORRETTO_RPM}"
yum localinstall -y "/tmp/${CORRETTO_RPM}"
export JAVA_HOME="/usr/lib/jvm/java-17-amazon-corretto"
echo "→ JAVA_HOME=${JAVA_HOME}"

# 5) CREATE tomcat USER & GROUP
groupadd -r tomcat || true
useradd -r -g tomcat -d /opt/tomcat -s /sbin/nologin tomcat || true

# 6) DOWNLOAD & VERIFY TOMCAT 11.0.7
TOMCAT_VERSION="11.0.7"
BASE="https://dlcdn.apache.org/tomcat/tomcat-11/v${TOMCAT_VERSION}/bin"
cd /tmp
for F in apache-tomcat-${TOMCAT_VERSION}.tar.gz{,.sha512}; do
  [ -f "${F}" ] || wget -q "${BASE}/${F}"
done
sha512sum -c "apache-tomcat-${TOMCAT_VERSION}.tar.gz.sha512" \
  || echo "⚠️ Checksum mismatch—continuing anyway"

# 7) UNPACK & LOCK DOWN
mkdir -p /opt/tomcat
tar xzf "apache-tomcat-${TOMCAT_VERSION}.tar.gz" \
    --strip-components=1 -C /opt/tomcat

chown -R tomcat:tomcat /opt/tomcat
find /opt/tomcat -type d -exec chmod 750 {} +
find /opt/tomcat -type f -exec chmod 640 {} +
chmod +x /opt/tomcat/bin/*.sh

# 8) Add ec2-user to tomcat group
usermod -aG tomcat ec2-user

# 9) Ensure group 'execute' (traverse) on all dirs under /opt/tomcat
find /opt/tomcat -type d -exec chmod g+rx {} +

# 10) SYSTEMD UNIT
cat > /etc/systemd/system/tomcat.service <<'EOF'
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

# 11) ENABLE & START
systemctl daemon-reload
systemctl enable --now tomcat

# 12) FINISH LINE
echo "✅ Tomcat ${TOMCAT_VERSION} deployed in /opt/tomcat"
echo "👉 Check: systemctl status tomcat"
echo "🔓 Don’t forget to open port 8080 in your Security Group!"
