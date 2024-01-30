#!/bin/bash

terraform apply -auto-approve
wait

VM_IP=$(terraform output -raw public_ip_address)

ssh -i ~/.ssh/id_rsa adminuser@$VM_IP << 'EOF'
sudo fdisk /dev/sdc << 'FEOF'
n
p
1
  
  
w
FEOF

sleep 5

sudo mkfs.ext4 /dev/sdc1
sudo mkdir -p /var/lib/gitea
sudo mount /dev/sdc1 /var/lib/gitea
echo '/dev/sdc1 /var/lib/gitea ext4 defaults 0 2' | sudo tee -a /etc/fstab

sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose
sudo curl https://raw.githubusercontent.com/MichalDulski/gitea-iac-azure/master/docker-compose-gitea.yml -o docker-compose.yml
sudo docker-compose up -d
EOF

sed -i '' '/# DB_PUBLIC_IP_START/,/# DB_PUBLIC_IP_END/s/^/#/' main.tf
sed -i '' '/# ALLOW_SSH_START/,/# ALLOW_SSH_END/s/^/#/' main.tf
terraform apply -auto-approve
wait

terraform destroy -target=azurerm_public_ip.db_public_ip -auto-approve
terraform destroy -target=azurerm_network_security_rule.allow_ssh -auto-approve

sed -i '' '/# DB_PUBLIC_IP_START/,/# DB_PUBLIC_IP_END/s/^#//' main.tf
sed -i '' '/# ALLOW_SSH_START/,/# ALLOW_SSH_END/s/^#//' main.tf
