provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

data "azurerm_client_config" "current" {}

# Configuration files
locals {
  env = merge(
    yamldecode(file("main.development.yaml"))
  )
}

resource "azurerm_resource_group" "rg" {
  name     = local.env.resource_group_name
  location = local.env.location
}

# COSMOS

resource "azurerm_cosmosdb_account" "default" {
  name                = local.env.cosmos_account_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  enable_automatic_failover = false

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }

  lifecycle {
      prevent_destroy = true
  }

}

resource "azurerm_cosmosdb_mongo_database" "default" {
  name                = "maibeer"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.default.name
  throughput          = 400

  lifecycle {
      prevent_destroy = true
  }
}

resource "azurerm_cosmosdb_mongo_collection" "questions" {
  name                = "questions"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.default.name
  database_name       = azurerm_cosmosdb_mongo_database.default.name

  default_ttl_seconds = "0"
  shard_key           = "product"
  throughput          = 400

  lifecycle {
      prevent_destroy = true
  }

}

resource "azurerm_cosmosdb_mongo_collection" "answers" {
  name                = "answers"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.default.name
  database_name       = azurerm_cosmosdb_mongo_database.default.name

  default_ttl_seconds = "0"
  shard_key           = "address.zipcode"
  throughput          = 400

  lifecycle {
      prevent_destroy = true
  }

}

# STORAGE

resource "azurerm_storage_account" "default" {
  name                     = local.env.storage_name
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# FUNCTIONS

resource "azurerm_app_service_plan" "default" {
  name                = local.env.func_plan_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "FunctionApp"
  reserved            = true

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "maibeer" {
  name                       = local.env.func_app_name
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_app_service_plan.default.id
  storage_account_name       = azurerm_storage_account.default.name
  storage_account_access_key = azurerm_storage_account.default.primary_access_key
  os_type                    = "linux"
  version                    = "~3"

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"  = "python"
  }

  site_config {
    # only for free plan
    use_32_bit_worker_process = true
  }

  identity {
    type                     = "SystemAssigned"
  }
}

# KEYVAULT

resource "azurerm_key_vault" "prototype" {
  name                        = local.env.kv_name
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = false
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_enabled         = true
  purge_protection_enabled    = false

  sku_name = "standard"

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "get",
      "create",
      "delete",
      "update"
    ]
  }

}

resource "azurerm_key_vault_key" "generated" {
  name         = "generated-key"
  key_vault_id = azurerm_key_vault.prototype.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt"
  ]
}

resource "azurerm_key_vault_access_policy" "function" {
  key_vault_id = azurerm_key_vault.prototype.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_function_app.maibeer.identity[0].principal_id

  key_permissions = [
    "get",
    "decrypt",
    "encrypt"
  ]
}

# OUTPUTS

output "cosmosdb_connection_strings" {
  value = azurerm_cosmosdb_account.default.connection_strings
}

output "vault_uri" {
  value = azurerm_key_vault.prototype.vault_uri
}

output "function_identity" {
  value = azurerm_function_app.maibeer.identity
}