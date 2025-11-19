terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  host                   = var.aks_cluster_endpoint
  client_certificate     = base64decode(var.aks_client_certificate)
  client_key             = base64decode(var.aks_client_key)
  cluster_ca_certificate = base64decode(var.aks_cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = var.aks_cluster_endpoint
    client_certificate     = base64decode(var.aks_client_certificate)
    client_key             = base64decode(var.aks_client_key)
    cluster_ca_certificate = base64decode(var.aks_cluster_ca_certificate)
  }
}
