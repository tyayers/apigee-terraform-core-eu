output "lb_type" {
  description = "The type of load balancer configured ('none', 'ilb', or 'xlb')."
  value       = var.lb_type
}

output "lb_ip_address" {
  description = "The IP address reserved for the load balancer frontend (internal for ILB, external for XLB, null if none)."
  value       = try(google_compute_address.apigee_lb_ip[0].address, null)
}

output "dns_authorization_record" {
  description = "DNS resource record information for completing the Certificate Manager authorization challenge (null if lb_type is none)."
  value       = try(google_certificate_manager_dns_authorization.apigee_dns_auth[0].dns_resource_record, null)
}

output "apigee_instance_id" {
  description = "The ID of the Apigee instance."
  value       = google_apigee_instance.apigee.id
}

output "apigee_service_attachment" {
  description = "The service attachment URI of the Apigee instance."
  value       = google_apigee_instance.apigee.service_attachment
}

output "network" {
  description = "The VPC network used for the load balancer (null if not configured)."
  value       = local.network
}

output "subnet" {
  description = "The subnetwork used for the load balancer (null if not configured)."
  value       = local.subnet
}
