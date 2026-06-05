#!/bin/bash

ENV=$1

if [[ -z "$ENV" || ! "$ENV" =~ ^(dev|prod)$ ]]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

IMAGES_TFVARS="$(dirname "$0")/images.${ENV}.tfvars"

if [[ ! -f "$IMAGES_TFVARS" ]]; then
  echo "ERROR: $IMAGES_TFVARS not found."
  echo "Copy images/images.tfvars.example to images.${ENV}.tfvars and configure it."
  exit 1
fi

cd "$(dirname "$0")/images"

tofu init -upgrade
tofu workspace select "$ENV" || tofu workspace new "$ENV"
tofu apply -var-file="../images.${ENV}.tfvars"

if [[ $? -eq 0 ]]; then
  echo ""
  echo "=========================================="
  echo "Image file IDs — copy into environment.${ENV}.tfvars:"
  echo "=========================================="
  tofu output -json images | jq -r '
    to_entries[] |
    "Label: \(.key)",
    "  installer_image: \(.value.installer_image)",
    (.value.file_ids | to_entries[] | "  file_id [\(.key)]: \(.value)"),
    ""
  '
fi
