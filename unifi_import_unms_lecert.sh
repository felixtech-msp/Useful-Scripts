#!/usr/bin/env bash

# CONFIGURATION OPTIONS
UNIFI_HOSTNAME=unms.example.com
UNIFI_SERVICE=unifi

UNIFI_DIR=/var/lib/unifi
JAVA_DIR=/usr/lib/unifi
KEYSTORE=${UNIFI_DIR}/keystore

PRIV_KEY=/home/unms/data/cert/live/${UNIFI_HOSTNAME}/privkey.pem
SIGNED_CRT=/home/unms/data/cert/live/${UNIFI_HOSTNAME}/cert.pem
CHAIN_FILE=/home/unms/data/cert/live/${UNIFI_HOSTNAME}/chain.pem

# CONFIGURATION OPTIONS YOU PROBABLY SHOULDN'T CHANGE
ALIAS=unifi
PASSWORD=aircontrolenterprise

printf "\nStarting UniFi Controller SSL Import...\n"

# Verify required files exist
if [[ ! -f ${PRIV_KEY} ]] || [[ ! -f ${CHAIN_FILE} ]]; then
        printf "\nMissing one or more required files. Check your settings.\n"
        exit 1
else
        # Everything looks OK to proceed
        printf "\nImporting the following files:\n"
        printf "Private Key: %s\n" "$PRIV_KEY"
        printf "CA File: %s\n" "$CHAIN_FILE"
fi

# Create temp files
P12_TEMP=$(mktemp)

# Stop the UniFi Controller
printf "\nStopping UniFi Controller...\n"
service "${UNIFI_SERVICE}" stop

# Create double-safe keystore backup
if [[ -s "${KEYSTORE}.orig" ]]; then
        printf "\nBackup of original keystore exists!\n"
        printf "\nCreating non-destructive backup as keystore.bak...\n"
        cp "${KEYSTORE}" "${KEYSTORE}.bak"
else
        cp "${KEYSTORE}" "${KEYSTORE}.orig"
        printf "\nNo original keystore backup found.\n"
        printf "\nCreating backup as keystore.orig...\n"
fi

# Export your existing SSL key, cert, and CA data to a PKCS12 file
printf "\nExporting SSL certificate and key data into temporary PKCS12 file...\n"

openssl pkcs12 -export \
  -in "${CHAIN_FILE}" \
  -in "${SIGNED_CRT}" \
  -inkey "${PRIV_KEY}" \
  -out "${P12_TEMP}" -passout pass:"${PASSWORD}" \
  -name "${ALIAS}"

# Delete the previous certificate data from keystore to avoid "already exists" message
printf "\nRemoving previous certificate data from UniFi keystore...\n"
keytool -delete -alias "${ALIAS}" -keystore "${KEYSTORE}" -deststorepass "${PASSWORD}"

# Import the temp PKCS12 file into the UniFi keystore
printf "\nImporting SSL certificate into UniFi keystore...\n"
keytool -importkeystore \
-srckeystore "${P12_TEMP}" -srcstoretype PKCS12 \
-srcstorepass "${PASSWORD}" \
-destkeystore "${KEYSTORE}" \
-deststorepass "${PASSWORD}" \
-destkeypass "${PASSWORD}" \
-alias "${ALIAS}" -trustcacerts

# Clean up temp files
printf "\nRemoving temporary files...\n"
rm -f "${P12_TEMP}"

# Restart the UniFi Controller to pick up the updated keystore
printf "\nRestarting UniFi Controller to apply new Let's Encrypt SSL certificate...\n"
service "${UNIFI_SERVICE}" start

# That's all, folks!
printf "\nDone!\n"

exit 0
