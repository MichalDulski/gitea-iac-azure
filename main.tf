# main.tf

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "gitea-resource-group"
  location = "North Europe"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "gitea-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]

  depends_on = [azurerm_resource_group.rg]
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "gitea-private-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  depends_on = [azurerm_virtual_network.vnet]
}

# Network Security Group for the private subnet
resource "azurerm_network_security_group" "nsg" {
  name                = "gitea-private-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  depends_on = [azurerm_subnet.subnet]
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Allow inbound SSH traffic on the private subnet
 resource "azurerm_network_security_rule" "allow_ssh" {
   name                        = "allow_ssh"
   priority                    = 101
   direction                   = "Inbound"
   access                      = "Allow"
   protocol                    = "Tcp"
   source_port_range           = "*"
   destination_port_range      = "*"
   source_address_prefix       = "*"
   destination_address_prefix  = "*"
   resource_group_name         = azurerm_resource_group.rg.name
   network_security_group_name = azurerm_network_security_group.nsg.name

   depends_on = [azurerm_network_security_group.nsg]
 }

# Allow inbound SSH traffic on the private subnet
#resource "azurerm_network_security_rule" "allow_mysql" {
#  name                        = "allow_mysql"
#  priority                    = 100
#  direction                   = "Inbound"
#  access                      = "Allow"
#  protocol                    = "Tcp"
#  source_port_range           = "*"
#  destination_port_range      = "3306"
#  source_address_prefix       = "*"
#  destination_address_prefix  = "*"
#  resource_group_name         = azurerm_resource_group.rg.name
#  network_security_group_name = azurerm_network_security_group.nsg.name
#
#  depends_on = [azurerm_network_security_group.nsg]
#}

#resource "azurerm_network_security_rule" "allow_http" {
#  name                        = "allow_http"
#  priority                    = 101
#  direction                   = "Inbound"
#  access                      = "Allow"
#  protocol                    = "Tcp"
#  source_port_range           = "*"
#  destination_port_range      = "80"
#  source_address_prefix       = "*"
#  destination_address_prefix  = "*"
#  resource_group_name         = azurerm_resource_group.rg.name
#  network_security_group_name = azurerm_network_security_group.nsg.name
#
#  depends_on = [azurerm_network_security_group.nsg]
#}

# Database
resource "azurerm_public_ip" "db_public_ip" {
  name                    = "db-public-ip"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
}

resource "azurerm_network_interface" "database_nic" {
  name                = "database-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  ip_configuration {
    name                          = "database-ip"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.5"
    # DB_PUBLIC_IP_START
    public_ip_address_id          = azurerm_public_ip.db_public_ip.id
    # DB_PUBLIC_IP_END
  }

  depends_on = [azurerm_subnet.subnet]
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

  depends_on = [azurerm_network_interface.database_nic]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
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

# gitea vm

resource "azurerm_public_ip" "gitea_public_ip" {
  name                    = "gitea-public-ip"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
}

# Network Interfaces
resource "azurerm_network_interface" "gitea_nic" {
  name                = "gitea-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  ip_configuration {
    name                          = "gitea-ip"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.4"
    public_ip_address_id          = azurerm_public_ip.gitea_public_ip.id

  }

  depends_on = [azurerm_subnet.subnet]
}
# Managed Disk
resource "azurerm_managed_disk" "gitea_managed_disk" {
  name                 = "acctestdisk1"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "10"
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
    public_key = file("~/.ssh/id_rsa.pub")
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

  depends_on = [azurerm_network_interface.gitea_nic]
}


data "azurerm_public_ip" "gitea_public_ip" {
  name                = azurerm_public_ip.gitea_public_ip.name
  resource_group_name = azurerm_linux_virtual_machine.gitea_vm.resource_group_name
}

output "public_ip_address" {
  value = data.azurerm_public_ip.gitea_public_ip.ip_address
}

resource "azurerm_virtual_machine_data_disk_attachment" "gitea_managed_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.gitea_managed_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.gitea_vm.id
  caching            = "ReadWrite"
  lun                = "0"
}

resource "azurerm_virtual_machine_extension" "database" {
  name                 = "database"
  virtual_machine_id   = azurerm_linux_virtual_machine.database_vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  depends_on = [azurerm_linux_virtual_machine.database_vm]

  settings = jsonencode({
  "commandToExecute" : "export DEBIAN_FRONTEND=noninteractive && apt-get update -y && apt-get install -y docker.io && apt-get install -y docker-compose && curl https://raw.githubusercontent.com/MichalDulski/gitea-iac-azure/master/docker-compose-db.yml -o docker-compose.yml && docker-compose up -d" })
}


resource "azurerm_virtual_machine_extension" "gitea" {
  name                 = "gitea"
  virtual_machine_id   = azurerm_linux_virtual_machine.gitea_vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  depends_on = [azurerm_linux_virtual_machine.gitea_vm, azurerm_linux_virtual_machine.database_vm]

  settings = jsonencode({
  "commandToExecute" : "export DEBIAN_FRONTEND=noninteractive && apt-get update -y && apt-get install -y docker.io && apt-get install -y docker-compose && curl https://raw.githubusercontent.com/MichalDulski/gitea-iac-azure/master/docker-compose-gitea.yml -o docker-compose.yml && docker-compose up -d" })
}
