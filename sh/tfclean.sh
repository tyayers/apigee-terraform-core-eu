#!/usr/bin/env bash
set -e

# Target runtime by default to protect the Apigee organization state
TARGET="${1:-runtime}"

if [ "$TARGET" = "runtime" ]; then
  echo "Cleaning tf/02-runtime state and caches..."
  rm -rf ./tf/02-runtime/.terraform
  rm -f ./tf/02-runtime/.terraform.lock.hcl
  rm -rf ./tf/02-runtime/.terraform*
  rm -rf ./tf/02-runtime/terraform.tfstate*
  echo "Runtime state cleaned. Stage 01-org state remains protected."
elif [ "$TARGET" = "all" ]; then
  echo "WARNING: Cleaning BOTH org and runtime state."
  echo "Deleting 01-org state while an Apigee Org exists in GCP will require manual state import."
  rm -rf ./tf/01-org/.terraform ./tf/01-org/.terraform.lock.hcl ./tf/01-org/terraform.tfstate*
  rm -rf ./tf/02-runtime/.terraform ./tf/02-runtime/.terraform.lock.hcl ./tf/02-runtime/terraform.tfstate*
  rm -rf ./tf/.terraform ./tf/.terraform.lock.hcl ./tf/terraform.tfstate*
else
  echo "Usage: $0 [runtime|all]"
  exit 1
fi
