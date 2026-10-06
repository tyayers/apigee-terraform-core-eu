/* Variables */

variable "project_id" {
  description = "Project id (also used for the Apigee Organization)."
  type        = string
}

variable "region" {
  description = "GCP region for the Apigee runtime & analytics data."
  type        = string
}

locals {
  gcp_services = [
    "apigee.googleapis.com",
    "apihub.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "aiplatform.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "modelarmor.googleapis.com",
    "dlp.googleapis.com"
  ]
}

provider "google" {
  region = var.region
  apigee_custom_endpoint = "https://eu-apigee.googleapis.com/v1/"
}

/* Project */

resource "google_project_service" "enabled_apis" {
  for_each           = toset(local.gcp_services)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

/* Apigee */

resource "google_apigee_organization" "apigee_org" {
  project_id                 = var.project_id
  analytics_region           = var.region
  api_consumer_data_location = var.region
  disable_vpc_peering        = true
  runtime_type               = "CLOUD"
  billing_type               = "PAYG"
  depends_on                 = [google_project_service.enabled_apis]
}

resource "google_apigee_instance" "apigee" {
  name                 = "apigee-${var.region}"
  location             = var.region
  org_id               = google_apigee_organization.apigee_org.id
  consumer_accept_list = [var.project_id]
}

resource "google_apigee_environment" "dev_env" {
  name         = "dev"
  org_id       = google_apigee_organization.apigee_org.id
  display_name = "Development Environment"
  description  = "Development environment for API proxy deployments"
  type         = "COMPREHENSIVE"
}

resource "google_apigee_envgroup" "dev_envgroup" {
  name      = "dev"
  org_id    = google_apigee_organization.apigee_org.id
  hostnames = ["api.example.com"]
}

resource "google_apigee_envgroup_attachment" "dev_envgroup_attachment" {
  envgroup_id = google_apigee_envgroup.dev_envgroup.id
  environment = google_apigee_environment.dev_env.name
}

resource "google_apigee_instance_attachment" "dev_instance_attachment" {
  instance_id = google_apigee_instance.apigee.id
  environment = google_apigee_environment.dev_env.name
}
