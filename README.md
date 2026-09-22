# Apigee Terraform Core EU
This is a simple core terraform deployment of Apigee X in a GCP project and region, using the EU DRZ control plane and a (presumably) european runtime region.

In addition to the core Apigee control plane and regional gateway, AI analytics collectors for token analytics, along with AI token reports, are also created. 

No load balancer is currently deployed with these templates, that can be done afterwards with either an external or internal LB that connects to the Apigee runtime's PSC Service Attachment.

## Install
To deploy simply clone this repository and run these commands.
```sh
# Set your GCP info
GOOGLE_CLOUD_PROJECT=
GOOGLE_CLOUD_LOCATION=

# Clean TF state
./sh/tfclean.sh
# Init and Apply
terraform -chdir=tf/ init
terraform -chdir=tf/ apply -var "project_id=$GOOGLE_CLOUD_PROJECT" -var "region=$GOOGLE_CLOUD_LOCATION"
```
