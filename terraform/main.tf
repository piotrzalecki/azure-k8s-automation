
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "wordpress" {
  name     = "wordpress-rg"
  location = "North Europe"

  tags = {
    environment = "production"
  }
}

resource "azurerm_kubernetes_cluster" "wordpress" {
  name                = "wordpress-aks"
  location            = azurerm_resource_group.wordpress.location
  resource_group_name = azurerm_resource_group.wordpress.name
  dns_prefix          = "wordpress-k8s"

  default_node_pool {
    name            = "default"
    node_count      = 2
    vm_size         = "Standard_D2_v2"
    os_disk_size_gb = 30
    enable_auto_scaling = true
    max_count = 5
    min_count = 2
    vnet_subnet_id = azurerm_subnet.wordpress.id

  }

  service_principal {
    client_id     = var.appId
    client_secret = var.password
  }

  role_based_access_control {
    enabled = true
  }

  tags = {
    environment = "production"
    application = "wordpress"
  }
}

# ###########
# NETWORK
############
resource "azurerm_network_security_group" "wordpress" {
  name                = "wordpress-sg"
  location            = azurerm_resource_group.wordpress.location
  resource_group_name = azurerm_resource_group.wordpress.name

  security_rule {
    name                       = "http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "https"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "443"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


resource "azurerm_virtual_network" "wordpress" {
  name                = "wordpress-vn"
  location            = azurerm_resource_group.wordpress.location
  resource_group_name = azurerm_resource_group.wordpress.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "production"
    application = "wordpress"
  }
}

resource "azurerm_subnet" "wordpress" {
  name                 = "wordpress-subnet"
  resource_group_name  = azurerm_resource_group.wordpress.name
  virtual_network_name = azurerm_virtual_network.wordpress.name
  address_prefixes     = ["10.0.0.0/16"]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}
#################
# DATABASE
################

resource "azurerm_mysql_server" "wordpress" {
  name                = "wordpress-mysqlserver"
  location            = azurerm_resource_group.wordpress.location
  resource_group_name = azurerm_resource_group.wordpress.name

  administrator_login          = "admin"
  administrator_login_password = var.dbpass

  sku_name   = "B_Gen5_2"
  storage_mb = 5120
  version    = "5.7"

  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false
  public_network_access_enabled     = true
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
}

resource "azurerm_mysql_virtual_network_rule" "wordpress" {
  name                = "mysql-vnet-rule"
  resource_group_name = azurerm_resource_group.wordpress.name
  server_name         = azurerm_mysql_server.wordpress.name
  subnet_id           = azurerm_subnet.wordpress.id
}
