#!/bin/bash

# Step 1: Check if Docker is installed and install if not
if ! command -v docker &> /dev/null
then
    echo "Docker could not be found, installing Docker..."
    curl -fsSL https://get.docker.com | bash
else
    echo "Docker is already installed."
fi

# Step 2: Check if docker-compose.yml exists locally
if [ ! -f "./docker-compose.yml" ]; then
    echo "docker-compose.yml not found locally. Please make sure the file is in the correct directory."
    exit 1
else
    echo "Using local docker-compose.yml."
fi

if [[ ! `cat /etc/sysctl.conf |  grep 'vm.overcommit_memory=1'`  ]];then 
echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf

fi
sudo sysctl vm.overcommit_memory=1

# Step 3: Pull code using Docker Compose
echo "Pulling code with Docker Compose..."
docker compose pull

# Check if firewall is enabled Ensure ufw is enabled
# if sudo ufw status | grep -q inactive; then
#     echo "Enabling UFW..."
#     sudo ufw enable
# fi
docker compose up -d

# Open ports for TCP only
echo "Opening ports 80 and 443 for TCP traffic..."
# sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3000/tcp
