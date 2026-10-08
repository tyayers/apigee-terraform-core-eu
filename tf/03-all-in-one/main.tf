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

  create_lb = var.lb_type != "none"
  is_ilb    = var.lb_type == "ilb"
  is_xlb    = var.lb_type == "xlb"
  lb_scheme = local.is_ilb ? "INTERNAL_MANAGED" : "EXTERNAL_MANAGED"
  network   = var.create_network ? try(google_compute_network.lb_network[0].id, null) : var.network
  subnet    = var.create_network ? try(google_compute_subnetwork.lb_subnet[0].id, null) : var.subnet
}

provider "google" {
  project                = var.project_id
  region                 = var.region
  apigee_custom_endpoint = "https://eu-apigee.googleapis.com/v1/"
}

/* Project APIs */

resource "google_project_service" "enabled_apis" {
  for_each           = toset(local.gcp_services)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

/* Apigee Organization (Protected from accidental deletion) */

resource "google_apigee_organization" "apigee_org" {
  project_id                 = var.project_id
  analytics_region           = var.region
  api_consumer_data_location = var.region
  disable_vpc_peering        = true
  runtime_type               = "CLOUD"
  billing_type               = "PAYG"
  depends_on                 = [google_project_service.enabled_apis]

  lifecycle {
    prevent_destroy = true
  }
}

/* Optional VPC, Subnet, and Proxy-Only Subnet */

resource "google_compute_network" "lb_network" {
  count                   = var.create_network ? 1 : 0
  name                    = "apigee-network-${var.region}"
  auto_create_subnetworks = false
  project                 = var.project_id
  depends_on              = [google_project_service.enabled_apis]
}

resource "google_compute_subnetwork" "lb_subnet" {
  count         = var.create_network ? 1 : 0
  name          = "apigee-subnet-${var.region}"
  ip_cidr_range = var.subnet_cidr_range
  region        = var.region
  network       = google_compute_network.lb_network[0].id
  project       = var.project_id
}

resource "google_compute_subnetwork" "proxy_subnet" {
  count         = var.create_network && local.create_lb ? 1 : 0
  name          = "apigee-proxy-subnet-${var.region}"
  ip_cidr_range = var.proxy_subnet_cidr_range
  region        = var.region
  network       = google_compute_network.lb_network[0].id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
  project       = var.project_id
}

/* Apigee Runtime Instance & Environment */

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

/* Certificate Manager (for ILB and XLB) */

resource "google_certificate_manager_dns_authorization" "apigee_dns_auth" {
  count       = local.create_lb ? 1 : 0
  name        = "apigee-dns-auth-${var.region}"
  location    = var.region
  domain      = var.domain
  description = "DNS authorization for Apigee regional load balancer certificate"
  project     = var.project_id
  depends_on  = [google_project_service.enabled_apis]
}

resource "google_certificate_manager_certificate" "apigee_managed_cert" {
  count       = local.create_lb ? 1 : 0
  name        = "apigee-cert-${var.region}"
  location    = var.region
  description = "Regional Google-managed certificate for Apigee load balancer"
  project     = var.project_id

  managed {
    domains = [
      google_certificate_manager_dns_authorization.apigee_dns_auth[0].domain
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.apigee_dns_auth[0].id
    ]
  }
}

/* Application Load Balancer & PSC NEG */

resource "google_compute_region_network_endpoint_group" "apigee_psc_neg" {
  count                 = local.create_lb ? 1 : 0
  name                  = "apigee-psc-neg-${var.region}"
  region                = var.region
  project               = var.project_id
  network               = local.network
  subnetwork            = local.subnet
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = google_apigee_instance.apigee.service_attachment
}

resource "google_compute_region_backend_service" "apigee_lb_backend" {
  count                 = local.create_lb ? 1 : 0
  name                  = "apigee-${var.lb_type}-backend-${var.region}"
  region                = var.region
  project               = var.project_id
  protocol              = "HTTPS"
  load_balancing_scheme = local.lb_scheme

  backend {
    group           = google_compute_region_network_endpoint_group.apigee_psc_neg[0].id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_region_url_map" "apigee_lb_url_map" {
  count           = local.create_lb ? 1 : 0
  name            = "apigee-${var.lb_type}-url-map-${var.region}"
  region          = var.region
  project         = var.project_id
  default_service = google_compute_region_backend_service.apigee_lb_backend[0].id
}

resource "google_compute_region_target_https_proxy" "apigee_lb_target_proxy" {
  count   = local.create_lb ? 1 : 0
  name    = "apigee-${var.lb_type}-target-proxy-${var.region}"
  region  = var.region
  project = var.project_id
  url_map = google_compute_region_url_map.apigee_lb_url_map[0].id

  certificate_manager_certificates = [
    google_certificate_manager_certificate.apigee_managed_cert[0].id
  ]
}

resource "google_compute_address" "apigee_lb_ip" {
  count        = local.create_lb ? 1 : 0
  name         = "apigee-${var.lb_type}-ip-${var.region}"
  region       = var.region
  project      = var.project_id
  address_type = local.is_ilb ? "INTERNAL" : "EXTERNAL"
  subnetwork   = local.is_ilb ? local.subnet : null
}

resource "google_compute_forwarding_rule" "apigee_lb_forwarding_rule" {
  count                 = local.create_lb ? 1 : 0
  name                  = "apigee-${var.lb_type}-forwarding-rule-${var.region}"
  region                = var.region
  project               = var.project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = local.lb_scheme
  port_range            = "443"
  target                = google_compute_region_target_https_proxy.apigee_lb_target_proxy[0].id
  network               = local.network
  subnetwork            = local.is_ilb ? local.subnet : null
  ip_address            = google_compute_address.apigee_lb_ip[0].address

  depends_on = [google_compute_subnetwork.proxy_subnet]
}
