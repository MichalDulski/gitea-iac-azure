# main.tf

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "my-resource-group"
  location = "East US" # Change to your desired Azure region
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "my-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "private-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group for the private subnet
resource "azurerm_network_security_group" "nsg" {
  name                = "private-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# Allow inbound SSH traffic on the private subnet
resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "allow_ssh"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Gitea VM
resource "azurerm_linux_virtual_machine" "gitea_vm" {
  name                = "gitea-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.gitea_nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub") # Replace with the path to your SSH public key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

resource "azurerm_managed_disk" "gitea_managed_disk" {
  name                 = "acctestdisk1"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1"
}

resource "azurerm_virtual_machine_data_disk_attachment" "gitea_managed_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.gitea_managed_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.gitea_vm.id
  caching            = "ReadWrite"
  lun                = "0"
}

# Database VM
resource "azurerm_linux_virtual_machine" "database_vm" {
  name                = "database-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.database_nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub") # Replace with the path to your SSH public key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

# Network Interfaces
resource "azurerm_network_interface" "gitea_nic" {
  name                = "gitea-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  ip_configuration {
    name                          = "gitea-ip"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "database_nic" {
  name                = "database-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  ip_configuration {
    name                          = "database-ip"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine_extension" "database" {
  name                 = "database"
  virtual_machine_id   = azurerm_linux_virtual_machine.database_vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = jsonencode({
  "commandToExecute" : "export DEBIAN_FRONTEND=noninteractive && apt-get update -y && apt-get install -y docker.io && apt-get install -y docker-compose && echo '${file("docker-compose-db.yml")}' > docker-compose.yml && docker-compose up -d" })
}

resource "azurerm_virtual_machine_extension" "gitea" {
  name                 = "gitea"
  virtual_machine_id   = azurerm_linux_virtual_machine.gitea_vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = jsonencode({
  "commandToExecute" : "export DEBIAN_FRONTEND=noninteractive && apt-get update -y && apt-get install -y docker.io && apt-get install -y docker-compose && mkdir -p /var/lib/gitea && DISK_DEVICE=$(lsblk -o NAME,SIZE -dn -e 7,11 | sort -k2 -n | tail -1 | awk '{print $1}') && mkfs.ext4 /dev/$DISK_DEVICE && mount /dev/$DISK_DEVICE /var/lib/gitea && echo '/dev/$DISK_DEVICE /var/lib/gitea ext4 defaults 0 0' >> /etc/fstab && export DB_HOST=${azurerm_network_interface.database_nic.private_ip_address} && echo '${file("docker-compose-gitea.yml")}' > docker-compose.yml && docker-compose up -d" })
}