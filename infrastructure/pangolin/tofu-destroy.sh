#!/bin/bash

ENV=azure # Default environment is set to 'azure'

tofu workspace select $ENV 
tofu destroy -var-file="environment.${ENV}.tfvars" 
