#!/bin/bash

# SonarQube 7.8 installation on RedHat 7/8
# DevOps Academy Teaching Script (by Pasima)
# Make it executable: chmod +x install_sonarqube.sh
# Run as root or Sudo : sudo ./install_sonarqube.sh
# Check the status with: sudo systemctl status sonarqube

set -e

SONAR_VERSION=7.8
SONAR _USER=sonar
SONAR_DIR=/opt/sonarqube
JAVA_PACKAGE=java-1.8.0-openjdk-devel

echo "🚀 Installing SonarQube $SONAR_VERSION on RedHat..."

# 1. Ensure running as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root or with sudo"
  exit 1
fi

# 2. Update system
yum update -y

# 3. Install prerequisites
yum install -y wget unzip git $JAVA_PACKAGE

# Verify Java version
java -version

# 4. Set Java environment globally
JAVA_HOME=$(dirname $(dirname $(readlink $(readlink $(which java)))))
echo "export JAVA_HOME=${JAVA_HOME}" > /etc/profile.d/java_home.sh
echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile.d/java_home.sh
source /etc/profile.d/java_home.sh

echo "✅ JAVA_HOME set to $JAVA_HOME"

# 5. Create sonar user if it doesn't exist
if ! id $SONAR_USER &>/dev/null; then
    useradd $SONAR_USER
    echo "$SONAR_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$SONAR_USER
    chmod 440 /etc/sudoers.d/$SONAR_USER
    echo "✅ Created user '$SONAR_USER'"
else
    echo "⚠️ User '$SONAR_USER' already exists"
fi

# 6. Download SonarQube
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

# 7. Adjust permissions
chown -R $SONAR_USER:$SONAR_USER $SONAR_DIR
chmod -R 775 $SONAR_DIR

# 8. Set required sysctl params (for Elasticsearch)
if ! grep -q vm.max_map_count /etc/sysctl.conf; then
  echo "vm.max_map_count=262144" >> /etc/sysctl.conf
  sysctl -w vm.max_map_count=262144
  echo "✅ vm.max_map_count set"
else
  echo "⚠️ vm.max_map_count already configured"
fi

# 9. Configure Java explicitly for SonarQube wrapper
sed -i "/^#wrapper.java.command=/c\wrapper.java.command=$JAVA_HOME/bin/java" \
  $SONAR_DIR/conf/wrapper.conf
echo "✅ SonarQube wrapper configured with Java path"

# 10. Create systemd service (best practice)
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

# Reload systemd and start SonarQube
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube
systemctl status sonarqube --no-pager

echo "✅ SonarQube installation complete!"
echo "🚀 Access SonarQube at: http://<server-ip>:9000 (Default: admin/admin)"
