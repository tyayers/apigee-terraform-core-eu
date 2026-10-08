output "org_id" {
  description = "Apigee organization resource ID (organizations/<project_id>)."
  value       = google_apigee_organization.apigee_org.id
}

output "project_id" {
  description = "GCP Project ID."
  value       = var.project_id
}

output "region" {
  description = "Analytics and consumer data region."
  value       = var.region
}
