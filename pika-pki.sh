#!/bin/bash

#set -e
shopt -s extglob
clear

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source ${SCRIPT_DIR}/functions/common.sh
source ${SCRIPT_DIR}/functions/formatting.sh
source ${SCRIPT_DIR}/functions/config.sh
source ${SCRIPT_DIR}/functions/root-ca.sh
source ${SCRIPT_DIR}/functions/intermediate-ca.sh
source ${SCRIPT_DIR}/functions/signing-ca.sh
source ${SCRIPT_DIR}/functions/certs.sh

export PIKA_PKI_DEFAULT_ORG=${PIKA_PKI_DEFAULT_ORG:=""}
export PIKA_PKI_DEFAULT_OU=${PIKA_PKI_DEFAULT_OU:=""}
export PIKA_PKI_DEFAULT_COUNTRY=${PIKA_PKI_DEFAULT_COUNTRY:=""}
export PIKA_PKI_DEFAULT_STATE=${PIKA_PKI_DEFAULT_STATE:=""}
export PIKA_PKI_DEFAULT_LOCALITY=${PIKA_PKI_DEFAULT_LOCALITY:=""}
export PIKA_PKI_DEFAULT_EMAIL=${PIKA_PKI_DEFAULT_EMAIL:=""}
export PIKA_PKI_CERT_KEY_ENCRYPTION=${PIKA_PKI_CERT_KEY_ENCRYPTION:="false"}

export PIKA_PKI_DIR=${PIKA_PKI_DIR:="$(pwd)/.pika-pki"}

echo "===== Working PKI Base Directory: ${PIKA_PKI_DIR}"
echo "Do you want to continue with this directory?"
gum confirm && echo -e "- Continuing...\n" || exit 1

mkdir -p ${PIKA_PKI_DIR}/roots

selectRootCA