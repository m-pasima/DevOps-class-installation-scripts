#!/bin/bash
set -euo pipefail

MAVEN_VERSION="3.9.9"
MAVEN_URL="https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip"
MAVEN_DIR="/opt/maven"
PROFILE_SNIPPET="/etc/profile.d/maven.sh"
CALLER="${SUDO_USER:-$(whoami)}"

echo "▶ Installing prerequisites…"
sudo yum install -y wget unzip tree vim git-all java-1.8.0-openjdk-devel

echo "▶ Installing Maven ${MAVEN_VERSION}…"
cd /opt
sudo wget -q "${MAVEN_URL}"
sudo unzip -q "apache-maven-${MAVEN_VERSION}-bin.zip"
sudo rm  "apache-maven-${MAVEN_VERSION}-bin.zip"
sudo rm -rf "${MAVEN_DIR}"
sudo mv  "apache-maven-${MAVEN_VERSION}" "${MAVEN_DIR}"

echo "▶ Publishing env vars system-wide…"
sudo tee  "${PROFILE_SNIPPET}" >/dev/null <<'EOF'
export M2_HOME=/opt/maven
export PATH=$PATH:$M2_HOME/bin
EOF
sudo chmod +x "${PROFILE_SNIPPET}"

# **FIX** – symlink where sudo secure_path can see it
sudo ln -sf "${MAVEN_DIR}/bin/mvn" /usr/bin/mvn

# Make mvn usable in *this* shell immediately
export  M2_HOME=/opt/maven
export  PATH=$PATH:$M2_HOME/bin

echo "▶ Verifying install…"
/usr/bin/mvn -version   # works for root and any sudo-spawned user

echo -e "\n🎉 Maven ready for every user (and sudo) on this host!"
