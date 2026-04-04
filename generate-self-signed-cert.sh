#!/bin/bash
# generate-self-signed-cert.sh - Generate a self-signed PKCS12 keystore for Tomcat TLS
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEYSTORE_FILE="${1:-${SCRIPT_DIR}/tls/keystore.p12}"
KEYSTORE_PASS="${2:-changeit}"
HOSTNAME="${3:-localhost}"
VALIDITY_DAYS=365

mkdir -p "$(dirname "${KEYSTORE_FILE}")"

echo "Generating self-signed certificate..."
echo "  Keystore: ${KEYSTORE_FILE}"
echo "  Hostname: ${HOSTNAME}"
echo "  Validity: ${VALIDITY_DAYS} days"

keytool -genkeypair \
    -alias tomcat \
    -keyalg RSA \
    -keysize 2048 \
    -validity ${VALIDITY_DAYS} \
    -storetype PKCS12 \
    -keystore "${KEYSTORE_FILE}" \
    -storepass "${KEYSTORE_PASS}" \
    -dname "CN=${HOSTNAME},OU=Development,O=Self-Signed,L=Unknown,ST=Unknown,C=XX" \
    -ext "SAN=dns:${HOSTNAME},dns:localhost,ip:127.0.0.1"

echo ""
echo "Keystore created successfully."
echo "  Password: ${KEYSTORE_PASS}"
echo ""
echo "Build the image with:"
echo "  docker build --build-arg TLS_KEYSTORE=tls/keystore.p12 --build-arg TLS_KEYSTORE_PASS=${KEYSTORE_PASS} -t tomcat-ords:latest ."
