#!/bin/bash
#
# SonarQube 7.8 Install Script for Amazon Linux (AL2023 or AL2)
# Author: Pasima (DevOps Academy)
#
# USAGE:
#   chmod +x install_sonarqube.sh
#   sudo ./install_sonarqube.sh
#
set -e

SONAR_VERSION=7.8
SONAR_USER=sonar
SONAR_DIR=/opt/sonarqube
JAVA_PACKAGE=java-11-amazon-corretto-devel   # <-- Use Java 11 for better compatibility

echo "🚀 Installing SonarQube $SONAR_VERSION on Amazon Linux..."

# 1. Must run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root or with sudo."
  exit 1
fi

# 2. System update
yum update -y

# 3. Install Amazon Corretto 11 and tools
yum install -y $JAVA_PACKAGE wget unzip git

# 4. Verify Java version
java -version

# 5. Set JAVA_HOME system-wide
JAVA_HOME=$(dirname $(dirname $(readlink $(readlink $(which java)))))
echo "export JAVA_HOME=${JAVA_HOME}" > /etc/profile.d/java_home.sh
echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile.d/java_home.sh
source /etc/profile.d/java_home.sh
echo "✅ JAVA_HOME set to $JAVA_HOME"

# 6. Create sonar user if missing (never run as root!)
if ! id $SONAR_USER &>/dev/null; then
    useradd $SONAR_USER
    echo "$SONAR_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$SONAR_USER
    chmod 440 /etc/sudoers.d/$SONAR_USER
    echo "✅ Created user '$SONAR_USER'"
else
    echo "⚠️ User '$SONAR_USER' already exists"
fi

# 7. Download and extract SonarQube
cd /opt
if [ ! -d "$SONAR_DIR" ]; then
  wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip
  unzip sonarqube-$SONAR_VERSION.zip
  mv sonarqube-$SONAR_VERSION sonarqube
  rm -f sonarqube-$SONAR_VERSION.zip
  echo "✅ SonarQube downloaded and extracted to $SONAR_DIR"
else
  echo "⚠️ $SONAR_DIR already exists"
fi

# 8. Set permissions for SonarQube files
chown -R $SONAR_USER:$SONAR_USER $SONAR_DIR
chmod -R 775 $SONAR_DIR

# 9. Configure system for Elasticsearch (SonarQube requirement)
if ! grep -q vm.max_map_count /etc/sysctl.conf; then
  echo "vm.max_map_count=262144" >> /etc/sysctl.conf
  sysctl -w vm.max_map_count=262144
  echo "✅ vm.max_map_count set"
else
  echo "⚠️ vm.max_map_count already configured"
fi

# 10. Set correct Java path in SonarQube wrapper config
sed -i "/^#wrapper.java.command=/c\wrapper.java.command=$JAVA_HOME/bin/java" \
  $SONAR_DIR/conf/wrapper.conf
echo "✅ SonarQube wrapper configured with Java path"

# 11. Open firewall port 9000 for SonarQube (if firewalld is running)
if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-port=9000/tcp
  firewall-cmd --reload
  echo "✅ Opened firewall port 9000"
fi

# 12. Create systemd service for SonarQube
cat <<EOF >/etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
User=$SONAR_USER
Group=$SONAR_USER
ExecStart=$SONAR_DIR/bin/linux-x86-64/sonar.sh start
ExecStop=$SONAR_DIR/bin/linux-x86-64/sonar.sh stop
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

# 13. Start SonarQube
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

echo "⏳ Waiting 10 seconds for SonarQube to initialize..."
sleep 10
systemctl status sonarqube --no-pager

PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 || hostname -I | awk '{print $1}')
echo "✅ SonarQube installation complete!"
echo "🚀 Access SonarQube at: http://$PRIVATE_IP:9000 (default: admin/admin)"

# SELinux warning
if command -v getenforce &>/dev/null && [ "$(getenforce)" = "Enforcing" ]; then
  echo "⚠️ SELinux is enforcing. If SonarQube fails to start, set to permissive for testing: setenforce 0"
fi

echo "📚 Teaching notes:"
echo "- This installs SonarQube with built-in H2 DB (for labs only)."
echo "- For production, use external PostgreSQL DB and SonarQube LTS."
echo "- Ensure your EC2 Security Group also allows port 9000 inbound."

