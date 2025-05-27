# === SERVER TYPE / OS DETECTION ===
# Detect and log the operating system type.
# This script is written for RHEL-based systems (Amazon Linux, CentOS, Red Hat).
# It uses 'yum' for package management.
# If you are running this on another OS (e.g., Ubuntu/Debian), STOP and adapt the script for 'apt' or your package manager.
#!/bin/bash
set -euo pipefail

MAVEN_VERSION="3.9.9"
MAVEN_URL="https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip"
MAVEN_DIR="/opt/maven"
PROFILE_SNIPPET="/etc/profile.d/maven.sh"
CALLER="${SUDO_USER:-$(whoami)}"

echo "▶ Removing any old Java installations…"
sudo yum remove -y java-1.8.0-openjdk* || true

echo "▶ Installing prerequisites and Java 17…"
sudo yum install -y wget unzip tree vim git-all java-17-openjdk-devel

echo "▶ Verifying Java installation…"
java -version
javac -version

echo "▶ Setting JAVA_HOME system-wide…"
JAVA_HOME_PATH=$(dirname $(dirname $(readlink $(readlink $(which javac)))))
sudo tee /etc/profile.d/java.sh >/dev/null <<EOF
export JAVA_HOME=${JAVA_HOME_PATH}
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
sudo chmod +x /etc/profile.d/java.sh
# Make Java 17 available immediately
export JAVA_HOME="${JAVA_HOME_PATH}"
export PATH="$JAVA_HOME/bin:$PATH"

echo "▶ Installing Maven ${MAVEN_VERSION}…"
cd /opt
sudo wget -q "${MAVEN_URL}"
sudo unzip -q "apache-maven-${MAVEN_VERSION}-bin.zip"
sudo rm  "apache-maven-${MAVEN_VERSION}-bin.zip"
sudo rm -rf "${MAVEN_DIR}"
sudo mv  "apache-maven-${MAVEN_VERSION}" "${MAVEN_DIR}"

echo "▶ Publishing Maven env vars system-wide…"
sudo tee "${PROFILE_SNIPPET}" >/dev/null <<'EOF'
export M2_HOME=/opt/maven
export PATH=$PATH:$M2_HOME/bin
EOF
sudo chmod +x "${PROFILE_SNIPPET}"

# **FIX** – symlink where sudo secure_path can see it
sudo ln -sf "${MAVEN_DIR}/bin/mvn" /usr/bin/mvn

# Make mvn usable in *this* shell immediately
export M2_HOME=/opt/maven
export PATH=$PATH:$M2_HOME/bin

echo "▶ Verifying Maven install…"
mvn -version   # Uses correct Java version

echo -e "\n🎉 Maven and Java 17+ are ready for every user (and sudo) on this host!"

