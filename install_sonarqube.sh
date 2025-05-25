#!/bin/bash
#
# SonarQube 9.9 LTS Install for Amazon Linux 2023/2 (Java 17)
#
set -e

SONAR_VERSION=9.9.4.87374
SONAR_USER=sonar
SONAR_DIR=/opt/sonarqube
JAVA_PACKAGE=java-17-amazon-corretto

echo "🚀 Installing SonarQube $SONAR_VERSION on Amazon Linux..."

if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root or with sudo."
  exit 1
fi

yum update -y
yum install -y $JAVA_PACKAGE wget unzip git

java -version

# Set JAVA_HOME
JAVA_HOME=$(dirname $(dirname $(readlink $(readlink $(which java)))))
echo "export JAVA_HOME=${JAVA_HOME}" > /etc/profile.d/java_home.sh
echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile.d/java_home.sh
source /etc/profile.d/java_home.sh

if ! id $SONAR_USER &>/dev/null; then
    useradd $SONAR_USER
    echo "$SONAR_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$SONAR_USER
    chmod 440 /etc/sudoers.d/$SONAR_USER
    echo "✅ Created user '$SONAR_USER'"
fi

cd /opt
if [ ! -d "$SONAR_DIR" ]; then
  wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip
  unzip sonarqube-$SONAR_VERSION.zip
  mv sonarqube-$SONAR_VERSION sonarqube
  rm -f sonarqube-$SONAR_VERSION.zip
fi

chown -R $SONAR_USER:$SONAR_USER $SONAR_DIR
chmod -R 775 $SONAR_DIR

if ! grep -q vm.max_map_count /etc/sysctl.conf; then
  echo "vm.max_map_count=262144" >> /etc/sysctl.conf
  sysctl -w vm.max_map_count=262144
fi

if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-port=9000/tcp
  firewall-cmd --reload
fi

# Create systemd service (NEW for SonarQube 9+)
cat <<EOF >/etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=network.target

[Service]
Type=simple
User=$SONAR_USER
Group=$SONAR_USER
Environment=JAVA_HOME=$JAVA_HOME
Environment=PATH=$JAVA_HOME/bin:/usr/bin:/bin
ExecStart=$SONAR_DIR/bin/linux-x86-64/sonar.sh console
Restart=always
LimitNOFILE=65536
LimitNPROC=4096
TimeoutStartSec=420

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

echo "⏳ Waiting for SonarQube to start (check logs for progress)..."
sleep 20
systemctl status sonarqube --no-pager
echo ""
echo "Check logs with: tail -f /opt/sonarqube/logs/sonar.log"
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 || hostname -I | awk '{print $1}')
echo "🚀 Access SonarQube at: http://$PRIVATE_IP:9000 (default: admin/admin)"
