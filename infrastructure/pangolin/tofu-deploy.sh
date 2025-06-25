#!/bin/bash

ENV=azure # Default environment is set to 'azure'

tofu workspace select $ENV || tofu workspace new $ENV
tofu init # ensures the correct versions are downloaded.
tofu apply -var-file="environment.${ENV}.tfvars" 
