#!/bin/bash
#
# Jenkins Automated Install Script for RHEL 9/10 (AWS EC2, Not Registered)
#
# Prerequisites & Guidelines:
# ---------------------------
# - Use T2.Medium Server
# - Run as root or via sudo.
# - EC2 Security Group must allow inbound TCP 8080 for Jenkins UI access.
# - No Red Hat subscription required (RHUI provides repos).
# - Port 8080 must be open in firewalld and/or Security Group.
# - Script installs OpenJDK 21 (latest supported by Jenkins as of 2024).
# - Suitable for "pet" and "cattle" servers alike!
#
# Common Pitfalls & Warnings:
# ---------------------------
# - Always check /var/log/jenkins for errors if Jenkins fails to start.
# - If firewalld is inactive, only AWS SG will protect/allow access.
# - If you run a proxy, set Jenkins URL and proxy env vars.
# - For production, always front Jenkins with HTTPS via ALB or nginx.
#
set -e

echo "🏗️  Updating system packages..."
yum update -y

echo "📦 Installing required dependencies (fontconfig, Java 21, wget, firewalld)..."
yum install -y fontconfig java-21-openjdk wget firewalld

echo "🛡️  Ensuring firewalld is running if installed..."
if systemctl is-enabled firewalld >/dev/null 2>&1; then
    systemctl start firewalld
    systemctl enable firewalld
fi

echo "➕ Adding Jenkins official repo (LTS release)..."
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo

echo "🔑 Importing Jenkins repo GPG key..."
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

echo "🔄 Upgrading system packages after adding Jenkins repo..."
yum upgrade -y

echo "☕ Installing Jenkins..."
yum install -y jenkins

echo "🔁 Reloading systemd daemon in case Jenkins unit file changed..."
systemctl daemon-reload

echo "🚀 Enabling and starting Jenkins service..."
systemctl enable jenkins
systemctl start jenkins

echo "🌐 Configuring firewall to allow port 8080 for Jenkins (if firewalld running)..."
if systemctl is-active firewalld >/dev/null 2>&1; then
    firewall-cmd --permanent --new-service=jenkins || true
    firewall-cmd --permanent --service=jenkins --set-short="Jenkins ports"
    firewall-cmd --permanent --service=jenkins --set-description="Jenkins port exceptions"
    firewall-cmd --permanent --service=jenkins --add-port=8080/tcp
    firewall-cmd --permanent --add-service=jenkins
    firewall-cmd --reload
fi

echo "⏳ Waiting 15 seconds to let Jenkins initialize..."
sleep 15

echo "🔑 Jenkins initial admin password:" | tee /var/log/jenkins-init.log
cat /var/lib/jenkins/secrets/initialAdminPassword | tee -a /var/log/jenkins-init.log

echo "✅ Jenkins installation and setup completed!"
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 || echo "YOUR_INSTANCE_IP")
echo "   Access Jenkins at: http://$PRIVATE_IP:8080"

echo "   Admin password also stored in: /var/log/jenkins-init.log"
echo ""
echo "   ⚡ Pro Tip: For production, front Jenkins with HTTPS (via ALB or reverse proxy)."
echo "   🔒 For backups: Regularly archive /var/lib/jenkins to S3/EFS."
echo "   🤖 For CI: Integrate agents using dedicated IAM roles."
