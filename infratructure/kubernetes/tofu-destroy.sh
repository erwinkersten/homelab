#!/bin/bash

ENV=$1

if [[ -z "$ENV" || ! "$ENV" =~ ^(dev|prod)$ ]]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

tofu workspace select $ENV || tofu workspace new $ENV
tofu destroy -var-file="environment.${ENV}.tfvars"
