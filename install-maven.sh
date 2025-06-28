# === SERVER TYPE / OS DETECTION ===
# This script is written for Amazon Linux 2023 and compatible RHEL-based systems.
# It uses 'dnf' for package management (the successor to 'yum').
# If you are running this on another OS (e.g., Ubuntu/Debian), STOP and adapt the script for 'apt' or your package manager.
# Installs Amazon Corretto 21 JDK, Maven 3.9.10 (manual from Apache), tree, git, and vim.
# All users will have mvn and java available system-wide after this script runs.
#!/bin/bash
set -euxo pipefail

MAVEN_VERSION="3.9.10"
MAVEN_DIST="apache-maven-${MAVEN_VERSION}-bin.tar.gz"
MAVEN_URL="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/${MAVEN_DIST}"
INSTALL_BASE="/opt"
MAVEN_EXTRACT_DIR="${INSTALL_BASE}/apache-maven-${MAVEN_VERSION}"
MAVEN_SYMLINK="${INSTALL_BASE}/maven"
PROFILE_SNIPPET="/etc/profile.d/maven.sh"

sudo dnf install -y java-21-amazon-corretto-devel wget tar tree git vim

JAVA_HOME_PATH="/usr/lib/jvm/java-21-amazon-corretto.x86_64"
sudo tee /etc/profile.d/java.sh >/dev/null <<EOF
export JAVA_HOME=${JAVA_HOME_PATH}
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
sudo chmod +x /etc/profile.d/java.sh
export JAVA_HOME="${JAVA_HOME_PATH}"
export PATH="$JAVA_HOME/bin:$PATH"

sudo rm -rf "${MAVEN_EXTRACT_DIR}" "${MAVEN_SYMLINK}"

cd /tmp
wget -q "${MAVEN_URL}"
sudo tar -xzf "${MAVEN_DIST}" -C "${INSTALL_BASE}"
sudo ln -sfn "${MAVEN_EXTRACT_DIR}" "${MAVEN_SYMLINK}"

sudo tee "${PROFILE_SNIPPET}" >/dev/null <<'EOF'
export M2_HOME=/opt/maven
export PATH=$PATH:$M2_HOME/bin
EOF
sudo chmod +x "${PROFILE_SNIPPET}"

sudo ln -sf "${MAVEN_SYMLINK}/bin/mvn" /usr/bin/mvn

rm -f "/tmp/${MAVEN_DIST}"

export M2_HOME=/opt/maven
export PATH=$PATH:$M2_HOME/bin

mvn -version

echo -e "\n✅ Maven ${MAVEN_VERSION}, Java 21, tree, git, and vim are installed and ready for ALL users."

