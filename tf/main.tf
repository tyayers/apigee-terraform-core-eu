/* Variables */

variable "project_id" {
  description = "Project id (also used for the Apigee Organization)."
  type        = string
}

variable "region" {
  description = "GCP region for the Apigee runtime & analytics data."
  type        = string
}

variable "network" {
  description = "VPC network name or self-link for the load balancer and PSC NEG."
  type        = string
}

variable "subnet" {
  description = "VPC subnetwork name or self-link for the load balancer forwarding rule and PSC NEG."
  type        = string
}

variable "domain" {
  description = "Domain name for the Certificate Manager certificate and Apigee envgroup hostname."
  type        = string
  default     = "api.example.com"
}

locals {
  gcp_services = [
    "apigee.googleapis.com",
    "apihub.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "certificatemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "aiplatform.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "modelarmor.googleapis.com",
    "dlp.googleapis.com"
  ]
}

provider "google" {
  region                 = var.region
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
  hostnames = [var.domain]
}

resource "google_apigee_envgroup_attachment" "dev_envgroup_attachment" {
  envgroup_id = google_apigee_envgroup.dev_envgroup.id
  environment = google_apigee_environment.dev_env.name
}

resource "google_apigee_instance_attachment" "dev_instance_attachment" {
  instance_id = google_apigee_instance.apigee.id
  environment = google_apigee_environment.dev_env.name
}

/* Certificate Manager */

resource "google_certificate_manager_dns_authorization" "apigee_dns_auth" {
  name        = "apigee-dns-auth-${var.region}"
  location    = var.region
  domain      = var.domain
  description = "DNS authorization for Apigee regional ILB certificate"
  depends_on  = [google_project_service.enabled_apis]
}

resource "google_certificate_manager_certificate" "apigee_managed_cert" {
  name        = "apigee-cert-${var.region}"
  location    = var.region
  description = "Regional Google-managed certificate for Apigee ILB"

  managed {
    domains = [
      google_certificate_manager_dns_authorization.apigee_dns_auth.domain
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.apigee_dns_auth.id
    ]
  }
}

/* Internal Application Load Balancer & PSC NEG */

resource "google_compute_region_network_endpoint_group" "apigee_psc_neg" {
  name                  = "apigee-psc-neg-${var.region}"
  region                = var.region
  network               = var.network
  subnetwork            = var.subnet
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = google_apigee_instance.apigee.service_attachment
}

resource "google_compute_region_backend_service" "apigee_ilb_backend" {
  name                  = "apigee-ilb-backend-${var.region}"
  region                = var.region
  protocol              = "HTTPS"
  load_balancing_scheme = "INTERNAL_MANAGED"

  backend {
    group           = google_compute_region_network_endpoint_group.apigee_psc_neg.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_region_url_map" "apigee_ilb_url_map" {
  name            = "apigee-ilb-url-map-${var.region}"
  region          = var.region
  default_service = google_compute_region_backend_service.apigee_ilb_backend.id
}

resource "google_compute_region_target_https_proxy" "apigee_ilb_target_proxy" {
  name    = "apigee-ilb-target-proxy-${var.region}"
  region  = var.region
  url_map = google_compute_region_url_map.apigee_ilb_url_map.id

  certificate_manager_certificates = [
    google_certificate_manager_certificate.apigee_managed_cert.id
  ]
}

resource "google_compute_address" "apigee_ilb_ip" {
  name         = "apigee-ilb-ip-${var.region}"
  region       = var.region
  subnetwork   = var.subnet
  address_type = "INTERNAL"
}

resource "google_compute_forwarding_rule" "apigee_ilb_forwarding_rule" {
  name                  = "apigee-ilb-forwarding-rule-${var.region}"
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_region_target_https_proxy.apigee_ilb_target_proxy.id
  network               = var.network
  subnetwork            = var.subnet
  ip_address            = google_compute_address.apigee_ilb_ip.address
}

/* Outputs */

output "ilb_ip_address" {
  description = "The internal IP address reserved for the regional internal load balancer."
  value       = google_compute_address.apigee_ilb_ip.address
}

output "dns_authorization_record" {
  description = "DNS resource record information for completing the Certificate Manager authorization challenge."
  value       = google_certificate_manager_dns_authorization.apigee_dns_auth.dns_resource_record
}

