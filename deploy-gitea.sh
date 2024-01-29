#!/bin/bash

terraform apply -auto-approve

wait

sed -i '' '/# DB_PUBLIC_IP_START/,/# DB_PUBLIC_IP_END/s/^/#/' main.tf

terraform apply -auto-approve

wait

terraform destroy -target=azurerm_public_ip.db_public_ip -auto-approve

sed -i '' '/# DB_PUBLIC_IP_START/,/# DB_PUBLIC_IP_END/s/^#//' main.tf

VIM_IP=$(terraform output -raw public_ip_address)

ssh -i ~/.ssh/id_rsa adminuser@$VM_IP << 'EOF'
sudo fdisk /dev/sdc << 'FEOF'
n
p
w
FEOF

sleep 5

sudo mkfs.ext4 /dev/sdc1
sudo mkdir /var/lib/gitea
sudo mount /dev/sdc1 /var/lib/gitea
echo '/dev/sdx1 /mnt/gitea_data ext4 defaults 0 2' | sudo tee -a /etc/fstab
