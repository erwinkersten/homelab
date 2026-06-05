#!/bin/bash
set -euo pipefail

ROLE_ID=$1
USER_ID=$2
PROXMOX_URL=$3
API_TOKEN=$4

role_count=$(curl -sk -H "Authorization: PVEAPIToken=${API_TOKEN}" \
  "${PROXMOX_URL}/api2/json/access/roles" \
  | jq "[.data[] | select(.roleid==\"${ROLE_ID}\")] | length")

user_count=$(curl -sk -H "Authorization: PVEAPIToken=${API_TOKEN}" \
  "${PROXMOX_URL}/api2/json/access/users" \
  | jq "[.data[] | select(.userid==\"${USER_ID}\")] | length")

role_exists="false"
user_exists="false"
[ "${role_count}" -gt 0 ] && role_exists="true"
[ "${user_count}" -gt 0 ] && user_exists="true"

echo "{\"role_exists\": \"${role_exists}\", \"user_exists\": \"${user_exists}\"}"
