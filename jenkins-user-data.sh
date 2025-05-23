#!/bin/bash
set -e

# Update system packages
yum update -y

# Install required dependencies
yum install -y fontconfig java-21-openjdk wget firewalld

# Enable and start firewalld if installed but not running
if systemctl is-enabled firewalld >/dev/null 2>&1; then
    systemctl start firewalld
    systemctl enable firewalld
fi

# Add Jenkins repo for Long Term Support release
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo

# Import Jenkins repo key
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Upgrade system packages again (after adding Jenkins repo)
yum upgrade -y

# Install Jenkins
yum install -y jenkins

# Reload systemd daemon in case Jenkins service file is updated
systemctl daemon-reload

# Enable and start Jenkins service
systemctl enable jenkins
systemctl start jenkins

# Configure firewall to allow Jenkins port 8080 if firewalld is running
if systemctl is-active firewalld >/dev/null 2>&1; then
    firewall-cmd --permanent --new-service=jenkins || true
    firewall-cmd --permanent --service=jenkins --set-short="Jenkins ports"
    firewall-cmd --permanent --service=jenkins --set-description="Jenkins port exceptions"
    firewall-cmd --permanent --service=jenkins --add-port=8080/tcp
    firewall-cmd --permanent --add-service=jenkins
    firewall-cmd --reload
fi

# Wait a few seconds to ensure Jenkins has initialized
sleep 15

# Output initial admin password to console and /var/log/jenkins-init.log for convenience
echo "Jenkins initial admin password:" | tee /var/log/jenkins-init.log
cat /var/lib/jenkins/secrets/initialAdminPassword | tee -a /var/log/jenkins-init.log

# Finished
echo "Jenkins installation and setup completed!"
