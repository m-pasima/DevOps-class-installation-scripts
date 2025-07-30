#!/bin/bash
# install_docker_multi_os.sh
# Dynamically installs Docker CE on Amazon Linux 2/2023, Ubuntu, or RHEL/CentOS/AlmaLinux/Rocky.
# Usage: chmod +x install_docker_multi_os.sh && ./install_docker_multi_os.sh

set -euo pipefail

echo "🔍 Detecting OS..."

# Load OS info
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
else
    echo "❌ /etc/os-release not found. Unsupported OS."
    exit 1
fi

OS_FAMILY=""
OS_VERSION="${VERSION_ID:-unknown}"

# Normalize ID for some distros
case "${ID,,}" in
    amzn | amazon)
        OS_FAMILY="amazon"
        ;;
    ubuntu)
        OS_FAMILY="ubuntu"
        ;;
    rhel | centos | rocky | almalinux)
        OS_FAMILY="rhel"
        ;;
    *)
        # Try hostnamectl fallback for Amazon Linux 2023 (sometimes ID is not 'amzn')
        if hostnamectl | grep -qi "amazon"; then
            OS_FAMILY="amazon"
        else
            echo "❌ Unsupported OS: ${ID:-unknown}."
            exit 2
        fi
        ;;
esac

echo "✅ Detected OS family: $OS_FAMILY ($PRETTY_NAME, version: $OS_VERSION)"

install_docker_amazon() {
    echo "🚀 Installing Docker on Amazon Linux 2/2023..."
    sudo dnf update -y
    sudo dnf install -y docker
    sudo systemctl enable --now docker
    sudo usermod -aG docker "${SUDO_USER:-$USER}"
    echo "🎉 Docker installed! Version info:"
    docker --version || echo "⚠️ Run 'newgrp docker' or log out/in to use Docker without sudo."
}

install_docker_ubuntu() {
    echo "🚀 Installing Docker on Ubuntu..."
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
      https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo \"${UBUNTU_CODENAME:-$VERSION_CODENAME}\") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "${SUDO_USER:-ubuntu}"
    sudo systemctl enable --now docker

    echo "🎉 Docker installed! Version info:"
    docker --version || echo "⚠️ Log out and in again to use Docker without sudo."
}

install_docker_rhel() {
    echo "🚀 Installing Docker on RHEL/CentOS/Rocky/AlmaLinux..."
    sudo yum -y update
    sudo yum -y install yum-utils device-mapper-persistent-data lvm2

    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    sudo yum install -y docker-ce docker-ce-cli containerd.io --nobest
    sudo systemctl enable --now docker
    sudo usermod -aG docker "${SUDO_USER:-$USER}"

    echo "🎉 Docker installed! Version info:"
    docker --version || echo "⚠️ Log out and in again to use Docker without sudo."
}

# Main dispatcher
case "$OS_FAMILY" in
    amazon)
        install_docker_amazon
        ;;
    ubuntu)
        install_docker_ubuntu
        ;;
    rhel)
        install_docker_rhel
        ;;
esac

echo -e "\n🚦 NEXT STEPS:"
echo "👉 If you want to use Docker as a non-root user, log out and log in again."
echo "👉 Test: docker run hello-world"
