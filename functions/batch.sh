#!/bin/bash

#==============================================================================
# Source other files
#==============================================================================
source ${SCRIPT_DIR}/functions/common.sh
source ${SCRIPT_DIR}/functions/formatting.sh

function batchEntrypoint {
  local PIKA_PKI_BATCH_ACTION=""
  local PIKA_PKI_BATCH_AUTHORITY=""
  local PIKA_PKI_BATCH_COUNTRY=""
  local PIKA_PKI_BATCH_EMAIL=""
  local PIKA_PKI_BATCH_LOCALITY=""
  local PIKA_PKI_BATCH_COMMON_NAME=""
  local PIKA_PKI_BATCH_ORGANIZATION=""
  local PIKA_PKI_BATCH_PASSWORD=""
  local PIKA_PKI_BATCH_SANS=""
  local PIKA_PKI_BATCH_STATE=""
  local PIKA_PKI_BATCH_ORGANIZATIONAL_UNIT=""
  local PIKA_PKI_BATCH_FILE=""

  # a - authority
  # c - country
  # e - email
  # h - help
  # l - locality
  # m - mode
  # n - common name
  # o - organization
  # p - password
  # s - sans
  # t - state
  # u - organizational unit
  # f - file

  while getopts "ha:c:e:l:m:n:o:p:s:t:u:f:" OPTION; do
    case $OPTION in
      a)
        # Set the authority
        PIKA_PKI_BATCH_AUTHORITY=$(stripLS "${OPTARG}")
        ;;
      c)
        # Set the country
        PIKA_PKI_BATCH_COUNTRY=${OPTARG}
        ;;
      e)
        # Set the email
        PIKA_PKI_BATCH_EMAIL=${OPTARG}
        ;;
      l)
        # Set the locality
        PIKA_PKI_BATCH_LOCALITY=${OPTARG}
        ;;
      n)
        # Set the common name
        PIKA_PKI_BATCH_COMMON_NAME=${OPTARG}
        ;;
      o)
        # Set the organization
        PIKA_PKI_BATCH_ORGANIZATION=${OPTARG}
        ;;
      s)
        # Set the sans
        PIKA_PKI_BATCH_SANS=${OPTARG}
        ;;
      t)
        # Set the state
        PIKA_PKI_BATCH_STATE=${OPTARG}
        ;;
      u)
        # Set the organizational unit
        PIKA_PKI_BATCH_ORGANIZATIONAL_UNIT=${OPTARG}
        ;;
      f)
        # Set the file
        PIKA_PKI_BATCH_FILE=${OPTARG}
        ;;
      p)
        # Set the password
        PIKA_PKI_BATCH_PASSWORD=${OPTARG}
        ;;
      m)
        # Batch mode functions
        case ${OPTARG} in
          "createCertificate" | "rotateCertificate" | "signCSR" | "rotateCRL" | "copyBundles")
            PIKA_PKI_BATCH_ACTION="${OPTARG}"
            ;;
          *)
            PIKA_PKI_BATCH_ACTION="help"
            ;;
        esac
        ;;
      h)
        PIKA_PKI_BATCH_ACTION="help"
        ;;
      :)
        echo "Option -${OPTARG} requires an argument."
        exit 1
        ;;
      *)
        PIKA_PKI_BATCH_ACTION="help"
        ;;
    esac
  done
  
  echo "===== Working PKI Base Directory: ${PIKA_PKI_DIR}"

  case "${PIKA_PKI_BATCH_ACTION}" in
    # Done
    "copyBundles")
      # Loop through the root CA directories
      for ROOT_CA_DIR in $(find ${PIKA_PKI_DIR}/roots/ -maxdepth 1 -type d -printf '%p\n' | grep -ve "^${PIKA_PKI_DIR}/roots/$"); do
        processCAChainPublicBundles ${ROOT_CA_DIR}
      done
      tree ${PIKA_PKI_DIR}/public_bundles
      ;;
    "signCSR")
      # Fail if no authority
      if [ -z "${PIKA_PKI_BATCH_AUTHORITY}" ]; then
        echo "No authority specified.  Exiting..."
        exit 10
      fi
      if [ -z "${PIKA_PKI_BATCH_FILE}" ]; then
        echo "No CSR file specified.  Exiting..."
        exit 11
      fi
      signExternalCSR "${PIKA_PKI_BATCH_AUTHORITY}" "${PIKA_PKI_BATCH_FILE}" "${PIKA_PKI_BATCH_PASSWORD}"
      ;;
    "revokeCertificate")
      revokeCertificate "${PIKA_PKI_BATCH_FILE}" "${PIKA_PKI_BATCH_PASSWORD}"
      ;;
    "rotateCertificate")
      rotateCertificate "${PIKA_PKI_BATCH_FILE}" "${PIKA_PKI_BATCH_PASSWORD}"
      ;;
    "rotateCRL")
      batchRotateCRL "${PIKA_PKI_BATCH_AUTHORITY}" "${PIKA_PKI_BATCH_PASSWORD}"
      ;;
    "createCertificate")
      batchCreateCertificate "${PIKA_PKI_BATCH_AUTHORITY}" "${PIKA_PKI_BATCH_PASSWORD}" "${PIKA_PKI_BATCH_COMMON_NAME}" "${PIKA_PKI_BATCH_COUNTRY}" "${PIKA_PKI_BATCH_STATE}" "${PIKA_PKI_BATCH_LOCALITY}" "${PIKA_PKI_BATCH_ORGANIZATION}" "${PIKA_PKI_BATCH_ORGANIZATIONAL_UNIT}" "${PIKA_PKI_BATCH_EMAIL}" "${PIKA_PKI_BATCH_SANS}"
      ;;
    *)
      showHelpMenu
      ;;
  esac
}

function batchRotateCRL {
  local PIKA_PKI_BATCH_AUTHORITY=${1}
  local PIKA_PKI_BATCH_PASSWORD=${2}

  # Fail if no authority
  if [ -z "${PIKA_PKI_BATCH_AUTHORITY}" ]; then
    echo "No authority specified.  Exiting..."
    exit 10
  fi
  # Disabled checking for a password cause maybe they're manually enterting the password when prompted
  #if [ -z "${PIKA_PKI_BATCH_PASSWORD}" ]; then
  #  echo "No password specified.  Exiting..."
  #  exit 11
  #fi

  # Make sure the targeted authority exists
  if [ ! -d "${PIKA_PKI_BATCH_AUTHORITY}" ]; then
    echo "Authority directory at path ${PIKA_PKI_BATCH_AUTHORITY} does not exist.  Exiting..."
    exit 12
  else
    # Make sure the path has a CA
    if [ "$(isCertificateAuthority "${PIKA_PKI_BATCH_AUTHORITY}/certs/ca.cert.pem")" == "false" ]; then
      echo "Schema at path ${PIKA_PKI_BATCH_AUTHORITY} is not a Certificate Authority.  Exiting..."
      exit 13
    fi
  fi

  CA_CERT=${PIKA_PKI_BATCH_AUTHORITY}/certs/ca.cert.pem
  CA_CN=$(getCertificateCommonName ${CA_CERT})

  echo "- Rotating CRL for ${CA_CN}"
  createCRLFile "${PIKA_PKI_BATCH_AUTHORITY}" "${PIKA_PKI_BATCH_PASSWORD}"
}

function batchCreateCertificate {
  local PARENT_CA_PATH=${1}
  local PARENT_CA_PASS=${2}
  local CERT_CN=${3}
  local CERT_COUNTRY_CODE=${4}
  local CERT_STATE=${5}
  local CERT_LOCALITY=${6}
  local CERT_ORG=${7}
  local CERT_ORG_UNIT=${8}
  local CERT_EMAIL=${9}
  local CERT_SANS=${10}

  if [ -z "${PARENT_CA_PATH}" ]; then
    echo "No parent CA path specified.  Exiting..."
    exit 10
  fi
  if [ -z "${CERT_CN}" ]; then
    echo "No common name specified.  Exiting..."
    exit 12
  fi

  createServerCertificate "${PARENT_CA_PATH}" \
    "${PARENT_CA_PASS}" \
    "${CERT_CN}" \
    "" \
    "${CERT_COUNTRY_CODE}" \
    "${CERT_STATE}" \
    "${CERT_LOCALITY}" \
    "${CERT_ORG}" \
    "${CERT_ORG_UNIT}" \
    "${CERT_EMAIL}" \
    "${CERT_SANS}"
}