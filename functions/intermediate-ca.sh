#!/bin/bash

shopt -s extglob;

source ${SCRIPT_DIR}/functions/formatting.sh
source ${SCRIPT_DIR}/functions/common.sh

function promptNewIntermediateCAName {
  local INTERMEDIATE_CA_NAME=$(gum input --prompt "* Intermediate CA [Common] Name: " --placeholder "ACME Intermediate Certificate Authority")
  if [ -z "$INTERMEDIATE_CA_NAME" ]; then
    promptNewIntermediateCAName
  else
    echo ${INTERMEDIATE_CA_NAME}
  fi
}

function promptNewIntermediateCACountryCode {
  local INTERMEDIATE_CA_COUNTRY_CODE=$(gum input --prompt "* Country Code: " --placeholder "US")
  if [ -z "$INTERMEDIATE_CA_COUNTRY_CODE" ]; then
    promptNewIntermediateCACountryCode
  else
    echo ${INTERMEDIATE_CA_COUNTRY_CODE}
  fi
}

function promptNewIntermediateCAState {
  local INTERMEDIATE_CA_STATE=$(gum input --prompt "* State: " --placeholder "California")
  if [ -z "$INTERMEDIATE_CA_STATE" ]; then
    promptNewIntermediateCAState
  else
    echo ${INTERMEDIATE_CA_STATE}
  fi
}

function promptNewIntermediateCALocality {
  local INTERMEDIATE_CA_LOCALITY=$(gum input --prompt "* City/Locality: " --placeholder "San Francisco")
  if [ -z "$INTERMEDIATE_CA_LOCALITY" ]; then
    promptNewIntermediateCALocality
  else
    echo ${INTERMEDIATE_CA_LOCALITY}
  fi
}

function promptNewIntermediateCAOrganization {
  local INTERMEDIATE_CA_ORGANIZATION=$(gum input --prompt "* Organization: " --placeholder "ACME Corporation")
  if [ -z "$INTERMEDIATE_CA_ORGANIZATION" ]; then
    promptNewIntermediateCAOrganization
  else
    echo ${INTERMEDIATE_CA_ORGANIZATION}
  fi
}

function promptNewIntermediateCAOrganizationalUnit {
  local INTERMEDIATE_CA_ORGANIZATIONAL_UNIT=$(gum input --prompt "* Organizational Unit: " --placeholder "InfoSec")
  if [ -z "$INTERMEDIATE_CA_ORGANIZATIONAL_UNIT" ]; then
    promptNewIntermediateCAOrganizationalUnit
  else
    echo ${INTERMEDIATE_CA_ORGANIZATIONAL_UNIT}
  fi
}

function promptNewIntermediateCAEmail {
  local INTERMEDIATE_CA_EMAIL=$(gum input --prompt "* Email: " --placeholder "you@acme.com")
  if [ -z "$INTERMEDIATE_CA_EMAIL" ]; then
    promptNewIntermediateCAEmail
  else
    echo ${INTERMEDIATE_CA_EMAIL}
  fi
}

function promptNewIntermediateCACRLURL {
  local INTERMEDIATE_CA_CRL_DIST_URI=$(gum input --prompt " [Optional] CRL URI Root: " --placeholder "https://acme.com/pki/crl")
  echo ${INTERMEDIATE_CA_CRL_DIST_URI}
}

function selectIntermediateCA {
  local CA_PATH=${1}
  local CA_CN=$(getCertificateCommonName "${CA_PATH}/certs/ca.cert.pem")
  local CA_TYPE=$(getCAType ${CA_PATH})
  local INT_CA_DIRS=$(find ${CA_PATH}/intermediate-ca/ -maxdepth 1 -type d -printf '%p\n' | grep -ve "^${CA_PATH}/intermediate-ca/$")

  local INT_CA_CERT=""
  local INT_CA_COMMON_NAME=""
  local INT_CA_GLUE=()
  local INT_CA_GLUE_STR=''
  local INT_CA_COMMON_NAMES_STR="../ Back\n[+] Create a new Intermediate CA"
  local INT_CA_COMMON_NAMES=()

  while IFS= read -r line; do
    if [ -z "$line" ]; then
      continue
    fi
    INT_CA_CERT="${line}/certs/ca.cert.pem"
    INT_CA_COMMON_NAME="$(getCertificateCommonName ${INT_CA_CERT})"
    INT_CA_GLUE+=("${line}|${INT_CA_COMMON_NAME}")
    INT_CA_GLUE_STR="${INT_CA_GLUE_STR}${line}|${INT_CA_COMMON_NAME}\n"
    INT_CA_COMMON_NAMES+=("${INT_CA_COMMON_NAME}")
    INT_CA_COMMON_NAMES_STR+="\n-|- ${INT_CA_COMMON_NAME}"
  done <<< "$INT_CA_DIRS"

  clear
  echoBanner "[${CA_TYPE}] ${CA_CN} - Intermediate CA Selection"
  echo "===== Path: $(getPKIPath ${CA_PATH})"

  local INT_CA_CHOICE=$(echo -e $INT_CA_COMMON_NAMES_STR | gum choose)
  if [ -z "$INT_CA_CHOICE" ]; then
    echo "No Intermediate CA selected.  Exiting..."
    exit 1
  fi

  case "${INT_CA_CHOICE}" in
    ("../ Back")
      selectCAActions ${CA_PATH}
      ;;
    "[+] Create a new Intermediate CA")
      echo -e "- Creating a new Intermediate CA...\n"
      createNewIntermediateCA ${CA_PATH}
      ;;
    (*)
      local CLEANED_INT_CA_CHOICE=$(echo ${INT_CA_CHOICE} | sed 's/-|- //')
      local INT_CA_CN=$(echo -e ${INT_CA_GLUE_STR} | grep -e "|${CLEANED_INT_CA_CHOICE}\$" | cut -d"|" -f2)
      local INT_CA_DIR=$(echo -e ${INT_CA_GLUE_STR} | grep -e "|${CLEANED_INT_CA_CHOICE}\$" | cut -d"|" -f1)

      selectCAActions ${INT_CA_DIR}
      ;;
  esac
}

function createNewIntermediateCA {
  local PARENT_CA_PATH=${1}
  local PARENT_CA_NAME=$(getCertificateCommonName "${PARENT_CA_PATH}/certs/ca.cert.pem")

  local INTERMEDIATE_CA_NAME=$(promptNewIntermediateCAName)
  local INTERMEDIATE_CA_COUNTRY_CODE=$(promptNewIntermediateCACountryCode)
  local INTERMEDIATE_CA_STATE=$(promptNewIntermediateCAState)
  local INTERMEDIATE_CA_LOCALITY=$(promptNewIntermediateCALocality)
  local INTERMEDIATE_CA_ORGANIZATION=$(promptNewIntermediateCAOrganization)
  local INTERMEDIATE_CA_ORGANIZATIONAL_UNIT=$(promptNewIntermediateCAOrganizationalUnit)
  local INTERMEDIATE_CA_EMAIL=$(promptNewIntermediateCAEmail)
  local INTERMEDIATE_CA_CRL_DIST_URI=$(promptNewIntermediateCACRLURL)

  echo -e "- $(bld '[Common] Name:') ${INTERMEDIATE_CA_NAME}\n- $(bld Country Code:) ${INTERMEDIATE_CA_COUNTRY_CODE}\n- $(bld State:) ${INTERMEDIATE_CA_STATE}\n- $(bld Locality:) ${INTERMEDIATE_CA_LOCALITY}\n- $(bld Organization:) ${INTERMEDIATE_CA_ORGANIZATION}\n- $(bld Organizational Unit:) ${INTERMEDIATE_CA_ORGANIZATIONAL_UNIT}\n- $(bld Email:) ${INTERMEDIATE_CA_EMAIL}"
  if [ ! -z "${INTERMEDIATE_CA_CRL_DIST_URI}" ]; then
    echo -e "- $(bld 'CRL Distribution URI:') ${INTERMEDIATE_CA_CRL_DIST_URI}"
  fi

  echo ""

  if gum confirm; then
    local INTERMEDIATE_CA_SLUG=$(slugify "${INTERMEDIATE_CA_NAME}")
    local INTERMEDIATE_CA_DIR=${PARENT_CA_PATH}/intermediate-ca/${INTERMEDIATE_CA_SLUG}

    # Make sure the directory doesn't already exist
    if [ -d ${INTERMEDIATE_CA_DIR} ]; then
      echo "- Intermediate CA \"${INTERMEDIATE_CA_NAME}\" Directory already exists: ${INTERMEDIATE_CA_DIR}"
      echo "- Aborting..."
      exit 1
    fi

    createCommonCAAssets "${INTERMEDIATE_CA_DIR}" "Intermediate"

    echo -e "- Creating default OpenSSL configuration files..."
    generateOpenSSLConfFile "${INTERMEDIATE_CA_DIR}" "${INTERMEDIATE_CA_NAME}" "${INTERMEDIATE_CA_SLUG}" "intermediate" "${INTERMEDIATE_CA_COUNTRY_CODE}" "${INTERMEDIATE_CA_STATE}" "${INTERMEDIATE_CA_LOCALITY}" "${INTERMEDIATE_CA_ORGANIZATION}" "${INTERMEDIATE_CA_ORGANIZATIONAL_UNIT}" "${INTERMEDIATE_CA_EMAIL}" 3650 "${INTERMEDIATE_CA_CRL_DIST_URI}"

    generatePrivateKey "${INTERMEDIATE_CA_DIR}/private/ca.key.pem" "Intermediate CA"

    if [ ! -f "${INTERMEDIATE_CA_DIR}/csr/ca.csr.pem" ]; then
      echo -e "- Creating Intermediate CA Certificate Signing Request (CSR)..."
      INTERMEDIATE_CA_PASS=$(gum input --password --prompt "Enter the password for the Intermediate CA private key: ")
      INT_CA_PASS_FW=$(mktemp)
      echo ${INTERMEDIATE_CA_PASS} > ${INT_CA_PASS_FW}
      openssl req -new -sha256 \
        -config ${INTERMEDIATE_CA_DIR}/openssl.cnf \
        -passin file:${INT_CA_PASS_FW} \
        -key ${INTERMEDIATE_CA_DIR}/private/ca.key.pem \
        -out ${INTERMEDIATE_CA_DIR}/csr/ca.csr.pem \
        -subj "/emailAddress=${INTERMEDIATE_CA_EMAIL}/C=${INTERMEDIATE_CA_COUNTRY_CODE}/ST=${INTERMEDIATE_CA_STATE}/L=${INTERMEDIATE_CA_LOCALITY}/O=${INTERMEDIATE_CA_ORGANIZATION}/OU=${INTERMEDIATE_CA_ORGANIZATIONAL_UNIT}/CN=${INTERMEDIATE_CA_NAME}"
      rm -f ${INT_CA_PASS_FW}
    else
      echo "- CSR already exists: ${INTERMEDIATE_CA_DIR}/csr/ca.csr.pem"
    fi

    if [ ! -f "${INTERMEDIATE_CA_DIR}/certs/ca.cert.pem" ]; then
      echo -e "- Signing Intermediate CA Certificate with parent CA \"${PARENT_CA_NAME}\"..."
      PARENT_CA_PASS=$(gum input --password --prompt "Enter the password for the Parent \"${PARENT_CA_NAME}\" CA private key: ")
      PARENT_CA_PASS_FW=$(mktemp)
      echo ${PARENT_CA_PASS} > ${PARENT_CA_PASS_FW}

      openssl ca -config ${PARENT_CA_PATH}/openssl.cnf -extensions v3_intermediate_ca \
        -passin file:${PARENT_CA_PASS_FW} \
        -days 3750 -notext -md sha256 -batch \
        -in ${INTERMEDIATE_CA_DIR}/csr/ca.csr.pem \
        -out ${INTERMEDIATE_CA_DIR}/certs/ca.cert.pem

      rm -f ${PARENT_CA_PASS_FW}
    fi

    if [ ! -z "${INTERMEDIATE_CA_CRL_DIST_URI}" ]; then
      createCRLFile "${INTERMEDIATE_CA_DIR}"
    fi

    selectCAActions "${INTERMEDIATE_CA_DIR}"

  else
    selectCAActions "${PARENT_CA_PATH}"
  fi

}