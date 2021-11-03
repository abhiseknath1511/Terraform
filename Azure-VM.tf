terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.82.0"
    }
  }
}
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "terraform_vm" {
  name     = var.name
  location = var.loc
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.name}-Vnet"
  location            = var.loc
  address_space       = ["10.0.0.0/16"]
  resource_group_name = azurerm_resource_group.terraform_vm.name

}

resource "azurerm_subnet" "snet" {
  name                 = "${var.name}-subnet"
  address_prefixes     = ["10.0.0.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.terraform_vm.name
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.name}-nic"
  location            = var.loc
  resource_group_name = azurerm_resource_group.terraform_vm.name

  ip_configuration {
    name                          = "azurevm_IP"
    subnet_id                     = azurerm_subnet.snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.onlineip.id
  }
}

resource "azurerm_public_ip" "onlineip" {
  name                = "${var.name}-publicip"
  location            = var.loc
  allocation_method   = "Static"
  resource_group_name = azurerm_resource_group.terraform_vm.name

}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.name}-NSG"
  location            = var.loc
  resource_group_name = azurerm_resource_group.terraform_vm.name

  security_rule {
    name                       = "NSG_Rules"
    priority                   = 100
    direction                  = "outbound"
    access                     = "allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nic-nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

data "azurerm_public_ip" "ipdata" {
  name                = azurerm_public_ip.onlineip.name
  resource_group_name = azurerm_resource_group.terraform_vm.name
}

resource "azurerm_linux_virtual_machine" "linuxPC" {
  name                  = "linuxPC-Server"
  location              = var.loc
  resource_group_name   = azurerm_resource_group.terraform_vm.name
  size                  = "Standard_B1ms"
  admin_username        = "abhisek"
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "abhisek"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y nginx",
      "sudo systemctl start nginx"
    ]
  }

  connection {
    type        = "ssh"
    user        = "abhisek"
    private_key = file("~/.ssh/id_rsa")
    host        = data.azurerm_public_ip.ipdata.ip_address
  }

}
