# Apigee Terraform Core EU

This repository provides Terraform configuration to deploy Apigee X in a GCP project and region using the EU DRZ control plane and a European runtime region.

It includes:
- **Apigee X Organization & Instance**: PAYG organization using the EU custom endpoint (`https://eu-apigee.googleapis.com/v1/`) with a regional instance.
- **Environment & Environment Group**: `dev` environment attached to an environment group and instance.
- **Regional Internal Application Load Balancer (ILB)**: Envoy-based regional internal HTTP(S) load balancer (`INTERNAL_MANAGED`).
- **Private Service Connect (PSC) NEG**: Regional network endpoint group pointing directly to the Apigee instance service attachment.
- **Certificate Manager**: Regional Google-managed SSL certificate with DNS authorization.

## Prerequisites

1. **VPC Network & Subnet**: A VPC network and subnet in the target region for the load balancer forwarding rule and PSC NEG.
2. **Proxy-Only Subnet**: A regional proxy-only subnet in the same VPC and region (required by GCP for `INTERNAL_MANAGED` load balancers):
   - Purpose: `REGIONAL_MANAGED_PROXY`
   - Role: `ACTIVE`
   - Recommended size: `/23` to `/26` depending on expected proxy capacity (e.g., `10.129.0.0/23`)

## Variables

| Variable | Description | Type | Default | Required |
|---|---|---|---|---|
| `project_id` | GCP Project ID (also used as the Apigee Organization name) | `string` | - | **Yes** |
| `region` | GCP region for Apigee runtime, analytics, and regional ILB resources | `string` | - | **Yes** |
| `network` | VPC network name or self-link for the ILB and PSC NEG | `string` | - | **Yes** |
| `subnet` | VPC subnetwork name or self-link for the ILB forwarding rule and PSC NEG | `string` | - | **Yes** |
| `domain` | Domain name for the Certificate Manager certificate and Apigee envgroup hostname | `string` | `"api.example.com"` | No |

## Deployment

### 1. Set Environment Variables or Create `terraform.tfvars`

You can supply variables via a `tf/terraform.tfvars` file:

```hcl
project_id = "my-apigee-project"
region     = "europe-west1"
network    = "my-vpc"
subnet     = "my-subnet-europe-west1"
domain     = "api.example.com"
```

### 2. Initialize and Apply

```sh
# Clean TF state if needed
./sh/tfclean.sh

# Initialize Terraform
terraform -chdir=tf/ init

# Apply configuration
terraform -chdir=tf/ apply
```

Or pass variables directly via CLI `-var` flags:

```sh
terraform -chdir=tf/ apply \
  -var "project_id=my_project_id" \
  -var "region=my_region" \
  -var "network=my_vpc" \
  -var "subnet=my_subnet_in_region" \
  -var "domain=my_domain
```

## Post-Deployment: DNS Authorization

The deployment provisions a Google-managed certificate through Certificate Manager using a regional DNS authorization challenge. To complete certificate issuance:

1. Obtain the DNS authorization record from Terraform outputs:
   ```sh
   terraform -chdir=tf/ output dns_authorization_record
   ```
2. In your DNS provider (e.g. Cloud DNS), create the CNAME record matching the output:
   - **Name**: The record name provided in the output (e.g., `_acme-challenge.api.example.com.`)
   - **Type**: `CNAME`
   - **Data**: The target domain provided in the output

Once the DNS record resolves, Google Cloud will automatically provision and renew the managed certificate.

## Outputs

| Output | Description |
|---|---|
| `ilb_ip_address` | Reserved internal IP address for the regional load balancer frontend |
| `dns_authorization_record` | CNAME record details for the Certificate Manager domain challenge |
