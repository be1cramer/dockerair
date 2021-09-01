#!/bin/bash

set -e

BASE_DIRECTORY=${1:-"registry_data"}
REGISTRY_IP=${2:-"127.0.0.1"}
REGISTRY_HOST=${3:-"localhost"}

CA_SUBJ_INPUT=${4:-"/C=US/ST=NC/L=FtBragg/O=JCU/OU=EC/CN=registry-ca"}
REGISTRY_SUBJ_INPUT=${5:-"/C=US/ST=NC/L=FtBragg/O=JCU/OU=EC/CN=registry-ca"}

mkdir -p $BASE_DIRECTORY/certs
mkdir -p $BASE_DIRECTORY/db

rm -f $BASE_DIRECTORY/certs/*

openssl genrsa -out $BASE_DIRECTORY/certs/ca.key 2048

openssl req -x509 -new -nodes \
-key $BASE_DIRECTORY/certs/ca.key \
-sha256 -days 1095 \
-out $BASE_DIRECTORY/certs/ca.pem \
-subj $CA_SUBJ_INPUT

openssl genrsa -out $BASE_DIRECTORY/certs/server.key 2048

openssl req -new \
-key $BASE_DIRECTORY/certs/server.key \
-out $BASE_DIRECTORY/certs/server.csr \
-subj $REGISTRY_SUBJ_INPUT

cat > $BASE_DIRECTORY/certs/server.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = $REGISTRY_IP
DNS.1 = $REGISTRY_HOST
EOF

openssl x509 -req \
-in $BASE_DIRECTORY/certs/server.csr \
-CA $BASE_DIRECTORY/certs/ca.pem \
-CAkey $BASE_DIRECTORY/certs/ca.key \
-CAcreateserial \
-out $BASE_DIRECTORY/certs/server.crt \
-days 1095 -sha256 \
-extfile $BASE_DIRECTORY/certs/server.ext