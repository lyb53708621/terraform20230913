terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.44.0"
    }

    #    aws = {
    #      source = "hashicorp/aws"
    #      version = "= 3.0"
    #    }
    #
    #    kubernetes = {
    #      source = "hashicorp/kubernetes"
    #      version = ">= 2.0.0"
    #    }
  }

  backend "azurerm" {
    resource_group_name  = "ae_fundmental"
    storage_account_name = "aesto1"
    container_name       = "terraform"
    key                  = "prd.terrasform.tfstate"
  }
}

provider "azurerm" {
  skip_provider_registration = true
#  environment = "china"
  features {
    #    resource_group {
    #      prevent_deletion_if_contains_resources = true
    #      }
    #
    #    virtual_machine {
    #      delete_os_disk_on_deletion = true
    #      graceful_shutdown = false
    #      skip_shutdown_and_force_delete = false
    #    }
    #
    #    key_vault {
    #      purge_soft_delete_on_destroy = true
    #      recover_soft_deleted_key_vaults = true
    #    }
  }
}

resource "azurerm_resource_group" "tfrg" {
  name     = "${var.environment}-tfrg"
  location = var.location
  tags = {
    Env  = "${var.environment}"
    Costcenter = "arch001"
  }
}

# Create Hub VNET
resource "azurerm_virtual_network" "tfhubvnet" {
  name                = "${var.environment}-tfhubvnet"
  location            = azurerm_resource_group.tfrg.location
  resource_group_name = azurerm_resource_group.tfrg.name
  address_space       = ["10.210.0.0/16"]
#  dns_servers         = ["10.0.0.4", "10.0.0.5"]

  tags = {
    Env = "${var.environment}"
  }
}

# Create subnets in Hub VNET
resource "azurerm_subnet" "GatewaySubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.tfrg.name
  virtual_network_name = azurerm_virtual_network.tfhubvnet.name
  address_prefixes     = ["10.210.0.0/24"]
}

resource "azurerm_subnet" "AzureFirewallSubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.tfrg.name
  virtual_network_name = azurerm_virtual_network.tfhubvnet.name
  address_prefixes     = ["10.210.1.0/24"]
}

resource "azurerm_subnet" "AzureFirewallManagementSubnet" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.tfrg.name
  virtual_network_name = azurerm_virtual_network.tfhubvnet.name
  address_prefixes     = ["10.210.2.0/24"]
}

resource "azurerm_subnet" "AzureBastionSubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.tfrg.name
  virtual_network_name = azurerm_virtual_network.tfhubvnet.name
  address_prefixes     = ["10.210.3.0/24"]
}

resource "azurerm_subnet" "JumpServerSubnet" {
  name                 = "JumpServerSubnet"
  resource_group_name  = azurerm_resource_group.tfrg.name
  virtual_network_name = azurerm_virtual_network.tfhubvnet.name
  address_prefixes     = ["10.210.4.0/24"]
}

# Create NSG for subnets in Hub VNET
resource "azurerm_network_security_group" "JumpServerNSG" {
  name                = "JumpServerNSG"
  location            = azurerm_resource_group.tfrg.location
  resource_group_name = azurerm_resource_group.tfrg.name

  security_rule {
    name                       = "SSH"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RDP"
    priority                   = 121
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create subnet NSG association
resource "azurerm_subnet_network_security_group_association" "JumpServerSubnetToNSG" {
  subnet_id                 = azurerm_subnet.JumpServerSubnet.id
  network_security_group_id = azurerm_network_security_group.JumpServerNSG.id
}

##########################################################
#
# Create Spoke VNET
#
###########################################################
/* resource "azurerm_virtual_network" "tfspokevnet" {
  name                = "${var.environment}-tfspokevnet"
  location            = azurerm_resource_group.tfrg.location
  resource_group_name = azurerm_resource_group.tfrg.name
  address_space       = ["10.211.0.0/16"]
#  dns_servers         = ["10.0.0.4", "10.0.0.5"]

  subnet {
    name           = "PrivateEndpointSubnet"
    address_prefix = "10.211.0.0/24"
  }

  subnet {
    name           = "VmSubnetSubnet"
    address_prefix = "10.211.1.0/24"
    security_group = azurerm_network_security_group.JumpServerNSG.id
  }

  subnet {
    name           = "ADBpubSubnet"
    address_prefix = "10.211.2.0/24"
  }
  
  subnet {
    name           = "ADBpriSubnet"
    address_prefix = "10.211.3.0/24"
  }

  subnet {
    name           = "AksSubnet"
    address_prefix = "10.211.4.0/24"
    security_group = azurerm_network_security_group.AksNSG.id
  }

  tags = {
    Env = "${var.environment}"
  }
}

resource "azurerm_network_security_group" "AksNSG" {
  name                = "AksNSG"
  location            = azurerm_resource_group.tfrg.location
  resource_group_name = azurerm_resource_group.tfrg.name

  security_rule {
    name                       = "HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 121
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create VNET Peering
resource "azurerm_virtual_network_peering" "SpokeToHub" {
  name                      = "SpokeToHub"
  resource_group_name       = azurerm_resource_group.tfrg.name
  virtual_network_name      = azurerm_virtual_network.tfspokevnet.name
  remote_virtual_network_id = azurerm_virtual_network.tfhubvnet.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
}

resource "azurerm_virtual_network_peering" "HubToSpoke" {
  name                      = "HubToSpoke"
  resource_group_name       = azurerm_resource_group.tfrg.name
  virtual_network_name      = azurerm_virtual_network.tfhubvnet.name
  remote_virtual_network_id = azurerm_virtual_network.tfspokevnet.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
} */

############################################################
#
# Create Firewall
#
#############################################################
# Create Public IP for Firewall
/* resource "azurerm_public_ip" "firewallpublicip" {
  name                      = "firewallpublicip"
  location                  = azurerm_resource_group.tfrg.location
  resource_group_name       = azurerm_resource_group.tfrg.name
  allocation_method         = "Static"
  sku                       = "Standard"
}

# Create Firewall Policy
resource "azurerm_firewall_policy" "tffwpolicy" {
  name                = "tffwpolicy"
  resource_group_name = azurerm_resource_group.tfrg.name
  location            = azurerm_resource_group.tfrg.location
  sku                 = "Standard"
}

# Create Firewall Policy Rule Collection
resource "azurerm_firewall_policy_rule_collection_group" "tffwpolicy_rulecollection" {
  name               = "tffwpolicy_rulecollection"
  firewall_policy_id = azurerm_firewall_policy.tffwpolicy.id
  priority           = 500
  application_rule_collection {
    name     = "app_rule_collection1"
    priority = 500
    action   = "Allow"
    rule {
      name = "app_rule_collection1_rule1"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["10.210.0.0/16"]
      destination_fqdns = ["*.microsoft.com"]
    }
  }

  network_rule_collection {
    name     = "network_rule_collection1"
    priority = 400
    action   = "Allow"
    rule {
      name                  = "network_rule_collection1_rule1"
      protocols             = ["TCP", "UDP"]
      source_addresses      = ["10.210.0.0/16"]
      destination_addresses = ["10.211.0.0/16"]
      destination_ports     = ["80", "1000-2000"]
    }
  }

  # nat_rule_collection {
  #   name     = "nat_rule_collection1"
  #   priority = 300
  #   action   = "Dnat"
  #   rule {
  #     name                = "nat_rule_collection1_rule1"
  #     protocols           = ["TCP", "UDP"]
  #     source_addresses    = ["10.0.0.1", "10.0.0.2"]
  #     destination_address = "192.168.1.1"
  #     destination_ports   = ["80"]
  #     translated_address  = "192.168.0.1"
  #     translated_port     = "8080"
  #   }
  # }
}

# Create Firewall
resource "azurerm_firewall" "tffirewall" {
  name                      = "tffirewall"
  location                  = azurerm_resource_group.tfrg.location
  resource_group_name       = azurerm_resource_group.tfrg.name
  sku_name                  = "AZFW_VNet"
  sku_tier                  = "Standard"
  firewall_policy_id        = azurerm_firewall_policy.tffwpolicy.id

  ip_configuration {
    name = "firewall_configuration"
    subnet_id = azurerm_subnet.AzureFirewallSubnet.id
    public_ip_address_id = azurerm_public_ip.firewallpublicip.id
  }
} */

########################################################################
#
# Create Jumpserver VM by azurerm_virtual_machine
#
########################################################################

# Create NIC for the VM
/* resource "azurerm_network_interface" "JumpserverNIC" {
  name                = "JumpserverNIC"
  location            = azurerm_resource_group.tfrg.location
  resource_group_name = azurerm_resource_group.tfrg.name

  ip_configuration {
    name                          = "JumpserverNIC_IP"
    subnet_id                     = azurerm_subnet.JumpServerSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create JumpServer VM
resource "azurerm_virtual_machine" "JumpserverVM" {
  name                  = "JumpserverVM"
  location              = azurerm_resource_group.tfrg.location
  resource_group_name   = azurerm_resource_group.tfrg.name
  network_interface_ids = [azurerm_network_interface.JumpserverNIC.id]
  vm_size               = "Standard_B2ms"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  storage_os_disk {
    name              = "JumperServerOSDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "StandardSSD_LRS"
    disk_size_gb      = 40
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "azureuser"
    admin_password = "Testceph123!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "prd"
  }
} */

########################################################################
#
# Create VM by azurerm_linux_virtual_machine
#
########################################################################

# Create NIC for the Linux VM
resource "azurerm_network_interface" "LunixVMNIC" {
  name                = "LunixVMNIC"
  location            = azurerm_resource_group.tfrg.location
  resource_group_name = azurerm_resource_group.tfrg.name

  ip_configuration {
    name                          = "LunixVMNIC_IP"
    subnet_id                     = azurerm_subnet.JumpServerSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create disk encryption set
resource "azurerm_disk_encryption_set" "disk_encryption_set" {
  name                = "disk_encryption_set"
  resource_group_name = azurerm_resource_group.tfrg.name
  location            = azurerm_resource_group.tfrg.location
  key_vault_key_id    = azurerm_key_vault_key.diskencryptionkey.id

  identity {
    type = "SystemAssigned"
  }
}

# Create Linux VM
resource "azurerm_linux_virtual_machine" "LunixVM" {
  name                = "LunixVM"
  resource_group_name = azurerm_resource_group.tfrg.name
  location            = azurerm_resource_group.tfrg.location
  size                = "Standard_B2ms"
  admin_username      = "azureuser"
  admin_password      = "Testceph123!"
  network_interface_ids = [
    azurerm_network_interface.LunixVMNIC.id,
  ]
#  vtpm_enabled        = true
#  secure_boot_enabled = true
  disable_password_authentication = false
#  admin_ssh_key {
#    username   = "adminuser"
#    public_key = file("~/.ssh/id_rsa.pub")
#  }

  os_disk {
    name                 = "LinuxOS_Disk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = "50"
    disk_encryption_set_id = azurerm_disk_encryption_set.disk_encryption_set.id
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}







######################################################
#
# Create a key vault and related resources
#
######################################################

data "azurerm_client_config" "current" {}

# Create a key vault
resource "azurerm_key_vault" "tfkv" {
  name                        = "tfkv"
  location                    = azurerm_resource_group.tfrg.location
  resource_group_name         = azurerm_resource_group.tfrg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  enabled_for_disk_encryption = true
  purge_protection_enabled    = true
  soft_delete_retention_days  = 30

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Delete",
      "Get",
      "Purge",
      "Recover",
      "Update",
      "GetRotationPolicy",
      "SetRotationPolicy"
    ]

    secret_permissions = [
      "Set",
    ]
  }
}

# Create a access policy
resource "azurerm_key_vault_access_policy" "disk_encryption" {
  key_vault_id = azurerm_key_vault.tfkv.id
  tenant_id = azurerm_disk_encryption_set.disk_encryption_set.identity.0.tenant_id
  object_id = azurerm_disk_encryption_set.disk_encryption_set.identity.0.principal_id
#  object_id    = azurerm_disk_encryption_set.disk_encryption_set.id

    key_permissions = [
        "Create",
        "Delete",
        "Get",
        "WrapKey",
        "UnwrapKey",
        "Purge",
        "Recover",
        "Update",
        "List",
        "Decrypt",
        "Sign",
        "GetRotationPolicy",
        "Rotate",
        "GetRotationPolicy",
        "SetRotationPolicy",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
}

# Create a access policy for User
/* resource "azurerm_key_vault_access_policy" "user_policy" {
  key_vault_id = azurerm_key_vault.tfkv.id
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
        "Create",
        "Delete",
        "Get",
        "WrapKey",
        "UnwrapKey",
        "Purge",
        "Recover",
        "Update",
        "List",
        "Decrypt",
        "Sign",
        "GetRotationPolicy",
        "Rotate",
        "GetRotationPolicy",
        "SetRotationPolicy",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
} */

# Create a key
resource "azurerm_key_vault_key" "diskencryptionkey" {
  name         = "diskencryptionkey"
  key_vault_id = azurerm_key_vault.tfkv.id
  key_type     = "RSA"
  key_size     = 2048

#  depends_on = [
#      azurerm_key_vault_access_policy.user_policy
#  ]

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  rotation_policy {
    automatic {
      time_after_creation = "P36M"
    }
  }
}
