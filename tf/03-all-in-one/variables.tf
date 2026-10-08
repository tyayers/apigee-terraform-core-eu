variable "project_id" {
  description = "GCP Project ID (also used as the Apigee Organization name)."
  type        = string
}

variable "region" {
  description = "GCP region for Apigee analytics, runtime instance, and load balancer."
  type        = string
}

variable "lb_type" {
  description = "Load balancer type to deploy: 'none', 'ilb' (Regional Internal ALB), or 'xlb' (Regional External ALB)."
  type        = string
  default     = "ilb"

  validation {
    condition     = contains(["none", "ilb", "xlb"], var.lb_type)
    error_message = "Allowed values for lb_type are 'none', 'ilb', or 'xlb'."
  }
}

variable "create_network" {
  description = "Whether to create a dedicated VPC network, subnetwork, and proxy-only subnet in the specified region."
  type        = bool
  default     = false
}

variable "network" {
  description = "VPC network name or self-link for the load balancer and PSC NEG. Required if lb_type is not 'none' and create_network is false."
  type        = string
  default     = null
}

variable "subnet" {
  description = "VPC subnetwork name or self-link for the load balancer forwarding rule and PSC NEG. Required if lb_type is not 'none' and create_network is false."
  type        = string
  default     = null
}

variable "subnet_cidr_range" {
  description = "IP CIDR range for the client/backend subnet when create_network is true."
  type        = string
  default     = "10.0.0.0/24"
}

variable "proxy_subnet_cidr_range" {
  description = "IP CIDR range for the proxy-only subnet when create_network is true."
  type        = string
  default     = "10.129.0.0/23"
}

variable "domain" {
  description = "Domain name for the Certificate Manager certificate and Apigee envgroup hostname."
  type        = string
  default     = "api.example.com"
}
