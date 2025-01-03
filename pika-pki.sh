#!/bin/bash

#set -e
shopt -s extglob
clear

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#==============================================================================
# Source other files
#==============================================================================
source ${SCRIPT_DIR}/functions/defaults.sh
source ${SCRIPT_DIR}/functions/common.sh
source ${SCRIPT_DIR}/functions/formatting.sh
source ${SCRIPT_DIR}/functions/config.sh
if [ -d "${SCRIPT_DIR}/overrides" ]; then
  if [ -f "${SCRIPT_DIR}/overrides/defaults.sh" ]; then
    source ${SCRIPT_DIR}/overrides/defaults.sh
  fi
  if [ -f "${SCRIPT_DIR}/overrides/config.sh" ]; then
    source ${SCRIPT_DIR}/overrides/config.sh
  fi
fi
source ${SCRIPT_DIR}/functions/root-ca.sh
source ${SCRIPT_DIR}/functions/intermediate-ca.sh
source ${SCRIPT_DIR}/functions/signing-ca.sh
source ${SCRIPT_DIR}/functions/certs.sh
source ${SCRIPT_DIR}/functions/batch.sh

#==============================================================================
# Set Environment Variables and defaults
#==============================================================================
export PIKA_PKI_DEFAULT_ORG=${PIKA_PKI_DEFAULT_ORG:=""}
export PIKA_PKI_DEFAULT_ORGUNIT=${PIKA_PKI_DEFAULT_ORGUNIT:=""}
export PIKA_PKI_DEFAULT_COUNTRY=${PIKA_PKI_DEFAULT_COUNTRY:=""}
export PIKA_PKI_DEFAULT_STATE=${PIKA_PKI_DEFAULT_STATE:=""}
export PIKA_PKI_DEFAULT_LOCALITY=${PIKA_PKI_DEFAULT_LOCALITY:=""}
export PIKA_PKI_DEFAULT_EMAIL=${PIKA_PKI_DEFAULT_EMAIL:=""}
export PIKA_PKI_CERT_KEY_ENCRYPTION=${PIKA_PKI_CERT_KEY_ENCRYPTION:="false"}
export PIKA_PKI_DEFAULT_CA_URI_BASE=${PIKA_PKI_DEFAULT_CA_URI_BASE:=""}
PIKA_PKI_DEFAULT_CA_URI_BASE=$(stripLastSlash ${PIKA_PKI_DEFAULT_CA_URI_BASE})


export PIKA_PKI_DIR=${PIKA_PKI_DIR:="$(pwd)/.pika-pki"}

if [ $# -eq 0 ]; then
  #==============================================================================
  # Directory Check
  #==============================================================================
  echo "===== Working PKI Base Directory: ${PIKA_PKI_DIR}"
  echo "Do you want to continue with this directory?"
  if gum confirm; then
    echo -e "- Continuing...\n"
  else
    echo "Exiting..."
    exit 1
  fi

  mkdir -p ${PIKA_PKI_DIR}/{roots,private_bundles,public_bundles/{certs,crls}}

  #==============================================================================
  # Menu Entrypoint
  #==============================================================================
  selectRootCAScreen
else
  #==============================================================================
  # Start CLI batch mode
  #==============================================================================
  batchEntrypoint "$@"
fi