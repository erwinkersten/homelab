
#!/bin/bash
set -euo pipefail

ROLE_ID=$1
USER_ID=$2
PROXMOX_URL=$3
API_TOKEN=$4

# Check Role existence
role_exists=$(curl -sk -H "Authorization: PVEAPIToken=${API_TOKEN}" \
  ${PROXMOX_URL}/api2/json/access/roles | jq ".data[] | select(.roleid==\"${ROLE_ID}\") | .roleid" | wc -l)

# Check User existence
user_exists=$(curl -sk -H "Authorization: PVEAPIToken=${API_TOKEN}" \
  ${PROXMOX_URL}/api2/json/access/users | jq ".data[] | select(.userid==\"${USER_ID}\") | .userid" | wc -l)

echo "{ \"role_exists\": "'"${role_exists}"'", \"user_exists\": "'"${user_exists}"'" }"


# curl -s -H 'Authorization: PVEAPIToken=root@pam!terraform=blabla' https://pve-01.local.erwinkersten.com:8006/api2/json/access/roles