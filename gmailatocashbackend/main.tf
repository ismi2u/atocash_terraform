# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}
provider "azurerm" {
  features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "atocash" {
  name     = "atocash_rg"
  location = "Central India"

  tags = {
    environment = "development"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "atocash" {
  name                = "atocash_vnet"
  address_space       = ["10.0.0.0/16"]
  
  location            = azurerm_resource_group.atocash.location
  resource_group_name = azurerm_resource_group.atocash.name

  tags = {
    environment = "development"
  }
}

# Create subnet
resource "azurerm_subnet" "atocash" {
  name                 = "atocash_subnet"
  resource_group_name  = azurerm_resource_group.atocash.name
  virtual_network_name = azurerm_virtual_network.atocash.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "atocash" {
  name                = "atocash_publicip"
  location            = azurerm_resource_group.atocash.location
  resource_group_name = azurerm_resource_group.atocash.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "development"
  }
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "atocash" {
  name                = "atocash_nsg"
  location            = azurerm_resource_group.atocash.location
  resource_group_name = azurerm_resource_group.atocash.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "http"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

    security_rule {
    name                       = "https"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "ICMP"
    priority                   = 3000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "ICMP"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "pgsql"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "development"
  }
}

# Create network interface
resource "azurerm_network_interface" "atocash" {
  name                = "atocash_nic"
  location            = azurerm_resource_group.atocash.location
  resource_group_name = azurerm_resource_group.atocash.name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = azurerm_subnet.atocash.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.atocash.id
  }

  tags = {
    environment = "development"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "atocash" {
  network_interface_id      = azurerm_network_interface.atocash.id
  network_security_group_id = azurerm_network_security_group.atocash.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.atocash.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "atocash" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = azurerm_resource_group.atocash.name
  location                 = azurerm_resource_group.atocash.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "development"
  }
}

# Create (and display) an SSH key
resource "tls_private_key" "atocash" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
output "tls_private_key" {
  value     = tls_private_key.atocash.private_key_pem
  sensitive = true
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "atocash" {
  name                  = "atocashdevm"
  location              = azurerm_resource_group.atocash.location
  resource_group_name   = azurerm_resource_group.atocash.name
  network_interface_ids = [azurerm_network_interface.atocash.id]
  size                  = "Standard_B1s"
  #   size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "atocash_osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-LTS"
    version   = "latest"
  }



  computer_name                   = "atocashdevvm"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.atocash.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.atocash.primary_blob_endpoint
  }

  tags = {
    environment = "development"
  }












# provisioner "file" {
#   source      = "docker-compose.yml"
#   destination = "/usr/docker-compose.yml"

#   # connection {
#   #   type     = "ssh"
#   #   user     = "azureuser"
#   #   private_key = tls_private_key.atocash.private_key_pem
#   # private_key = "${file(var.private_key)}"
#   #   # password = "${var.root_password}"
#   #   # host     = azurerm_public_ip.atocash.ip_address

#   #   "${azurerm_public_ip.publicip.ip_address}"
#   # }


#    connection {
#       host        = "${azurerm_public_ip.atocash.ip_address}"
#       type        = "ssh"
#       private_key = "${tls_private_key.atocash.private_key_pem}"
#       port        = 22
#       user        = "azureuser"
#       agent       = false
#       timeout     = "1m"
#     }


# }





}


###########################################################
#########  Atocash Angular App ######### ##################
###########################################################

output "instance_ip_addr" {
  value       = "${azurerm_public_ip.atocash.ip_address}"
  description = "The private IP address of the main server instance."
}

output "privatekey" {
  value       = "${tls_private_key.atocash.private_key_pem}"
  description = "The private Key  instance."
  sensitive = true
}



# resource "azurerm_virtual_machine_extension" "atocash" {
#   name                 = "atocashangular"
#   virtual_machine_id   = azurerm_linux_virtual_machine.atocash.id
#   publisher            = "Microsoft.Azure.Extensions"
#   type                 = "CustomScript"
#   type_handler_version = "2.0"


#   settings = <<SETTINGS
#     {
#       "commandToExecute": "sudo su",
#       "commandToExecute": "cd /",
#         "commandToExecute": "sudo apt update",
# 		"commandToExecute": "sudo apt install apt-transport-https ca-certificates curl software-properties-common -y", 
# 		"commandToExecute": "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -", 
# 		"commandToExecute": "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable\"", 
# 		"commandToExecute": "sudo apt update",
# 		"commandToExecute": "apt-cache policy docker-ce",
# 		"commandToExecute": "sudo apt install docker-ce -y",
# 		"commandToExecute": "apt-get install docker-compose -y",
#         "commandToExecute": "cd /usr/atocash"
       
#     }
# SETTINGS


#   tags = {
#     environment = "development"
#   }
# }

  