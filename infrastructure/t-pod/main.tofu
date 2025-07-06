provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
  
    depends_on = [
        azurerm_resource_group.main
    ]   
}

resource "azurerm_subnet" "main" {
  name                 = var.subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = ["10.0.1.0/24"]

    depends_on = [
        azurerm_virtual_network.main
    ]

}

resource "azurerm_network_security_group" "main" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  # T-Pot Management: SSH
  security_rule {
    name                       = "Tpod.Management.SSH.Tcp"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "64295" # T-Pot Management: Access to SSH
    source_address_prefix      = var.allowed_source_ipv4_addr # only allow SSH from this IP
    destination_address_prefix = "*"
  }

  # T-Pot Management: Reverse Proxy (NGINX)
  security_rule {
    name                       = "Tpod.Management.ReverseProxy.Tcp"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "64297" # T-Pot Management Access to NGINX reverse proxy
    source_address_prefix      = var.allowed_source_ipv4_addr # only allow from this IP
    destination_address_prefix = "*"
  }

  # T-Pot Management: Sensor Data
  security_rule {
    name                       = "Tpod.Management.Sensor.Tcp"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "64294" # T-Pot Management: Sensor data transmission to hive (through NGINX reverse proxy) to 127.0.0.1:64305
    source_address_prefix      = var.allowed_source_ipv4_addr # only allow from this IP
    destination_address_prefix = "*"    
  }

  # Honeypot: ADBHoney
  security_rule {
    name                       = "Honeypot.ADBHoney.tcp"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5555"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: CiscoASA
  security_rule {
    name                       = "Honeypot.CiscoASA.udp"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Honeypot.CiscoASA.tcp"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: CitrixHoneypot
  security_rule {
    name                       = "Honeypot.CitrixHoneypot.tcp"
    priority                   = 1008
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Conpot (tcp)
  security_rule {
    name                       = "Honeypot.Conpot.tcp"
    priority                   = 1009
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "102", "502", "1025", "2404", "10001", "44818", "47808", "50100"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  # Honeypot: Conpot (udp)
  security_rule {
    name                       = "Honeypot.Conpot.udp"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_ranges    = ["161", "623"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Cowrie
  security_rule {
    name                       = "Honeypot.Cowrie.tcp"
    priority                   = 1033
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "23"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Ddospot
  security_rule {
    name                       = "Honeypot.Ddospot.udp"
    priority                   = 1011
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_ranges    = ["19", "53", "123", "1900"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Dicompot
  security_rule {
    name                       = "Honeypot.Dicompot.tcp"
    priority                   = 1012
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "11112"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Dionaea (tcp)
  security_rule {
    name                       = "Honeypot.Dionaea.tcp"
    priority                   = 1013
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["21", "42", "135", "443", "445", "1433", "1723", "1883", "3306", "8081"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  # Honeypot: Dionaea (udp)
  security_rule {
    name                       = "Honeypot.Dionaea.udp"
    priority                   = 1014
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "69"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Elasticpot
  security_rule {
    name                       = "Honeypot.Elasticpot.tcp"
    priority                   = 1015
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9200"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Endlessh
  security_rule {
    name                       = "Honeypot.Endlessh.tcp"
    priority                   = 1016
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Go-pot
  security_rule {
    name                       = "Honeypot.Gopot.tcp"
    priority                   = 1017
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: H0neytr4p
  security_rule {
    name                       = "Honeypot.H0neytr4p.tcp"
    priority                   = 1018
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Heralding
  security_rule {
    name                       = "Honeypot.Heralding.tcp"
    priority                   = 1019
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["21", "22", "23", "25", "80", "110", "143", "443", "993", "995", "1080", "5432", "5900"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Honeyaml
  security_rule {
    name                       = "Honeypot.Honeyaml.tcp"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: qHoneypots (tcp)
  security_rule {
    name                       = "Honeypot.qHoneypots.tcp"
    priority                   = 1021
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["21", "22", "23", "25", "80", "110", "143", "389", "443", "445", "631", "1080", "1433", "1521", "3306", "3389", "5060", "5432", "5900", "6379", "6667", "8080", "9100", "9200", "11211"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  # Honeypot: qHoneypots (udp)
  security_rule {
    name                       = "Honeypot.qHoneypots.udp"
    priority                   = 1022
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_ranges    = ["53", "123", "161", "5060"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: IPPHoney
  security_rule {
    name                       = "Honeypot.IPPHoney.tcp"
    priority                   = 1023
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "631"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Log4Pot
  security_rule {
    name                       = "Honeypot.Log4Pot.tcp"
    priority                   = 1024
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443", "8080", "9200", "25565"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Mailoney
  security_rule {
    name                       = "Honeypot.Mailoney.tcp"
    priority                   = 1025
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "25"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Medpot
  security_rule {
    name                       = "Honeypot.Medpot.tcp"
    priority                   = 1026
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2575"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Miniprint
  security_rule {
    name                       = "Honeypot.Miniprint.tcp"
    priority                   = 1027
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Redishoneypot
  security_rule {
    name                       = "Honeypot.Redishoneypot.tcp"
    priority                   = 1028
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6379"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: SentryPeer (tcp)
  security_rule {
    name                       = "Honeypot.SentryPeer.tcp"
    priority                   = 1029
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5060"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  # Honeypot: SentryPeer (udp)
  security_rule {
    name                       = "Honeypot.SentryPeer.udp"
    priority                   = 1030
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "5060"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Snare (Tanner)
  security_rule {
    name                       = "Honeypot.Snare.tcp"
    priority                   = 1031
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Honeypot: Wordpot
  security_rule {
    name                       = "Honeypot.Wordpot.tcp"
    priority                   = 1032
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8090"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Outbound: HTTP
  security_rule {
    name                       = "Outbound.HTTP"
    priority                   = 2001
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Outbound: HTTPS
  security_rule {
    name                       = "Outbound.HTTPS"
    priority                   = 2002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Outbound: Ollama LLM
  security_rule {
    name                       = "Outbound.OllamaLLM"
    priority                   = 2003
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "11434"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [
    azurerm_subnet.main
  ]
}

resource "azurerm_public_ip" "main" {
  name                = "${var.vm_name}-pubip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
  sku                 = "Basic"

  depends_on = [
    azurerm_resource_group.main
  ]
}

resource "azurerm_network_interface" "main" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }

  depends_on = [
    azurerm_resource_group.main
  ]
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
  
  depends_on = [
    azurerm_network_interface.main,
    azurerm_network_security_group.main
  ]
}

resource "azurerm_linux_virtual_machine" "main" {
  name                = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [azurerm_network_interface.main.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.vm_name}-osdisk"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server-arm64"   // Use "server" for x86_64 architecture
    version   = "latest"
  }

  disable_password_authentication = true
}

resource "azurerm_managed_disk" "data" {
  name                 = "${var.vm_name}-datadisk"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  managed_disk_id    = azurerm_managed_disk.data.id
  virtual_machine_id = azurerm_linux_virtual_machine.main.id
  lun                = 0
  caching            = "ReadWrite"
}

# resource "azurerm_virtual_machine_extension" "main" {
#   name                 = "customScript"
#   virtual_machine_id   = azurerm_linux_virtual_machine.main.id
#   publisher            = "Microsoft.Azure.Extensions"
#   type                 = "CustomScript"
#   type_handler_version = "2.0"

#   settings = jsonencode({
#     fileUris = ["https://raw.githubusercontent.com/erwinkersten/homelab/feature/tpod-azure-vm/infrastructure/t-pod/bootstrap/setup.sh"]
#     commandToExecute = "bash setup.sh"
#   })
# }