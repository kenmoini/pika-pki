#!/bin/bash

shopt -s extglob;

source ${SCRIPT_DIR}/functions/formatting.sh
source ${SCRIPT_DIR}/functions/common.sh

function promptNewSigningCAName {
  local SIGNING_CA_NAME=$(gum input --prompt "* Signing CA [Common] Name: " --placeholder "ACME Signing Certificate Authority")
  if [ -z "$SIGNING_CA_NAME" ]; then
    promptNewSigningCAName
  else
    echo ${SIGNING_CA_NAME}
  fi
}

function promptNewSigningCACountryCode {
  local SIGNING_CA_COUNTRY_CODE=$(gum input --prompt "* Country Code: " --placeholder "US")
  if [ -z "$SIGNING_CA_COUNTRY_CODE" ]; then
    promptNewSigningCACountryCode
  else
    echo ${SIGNING_CA_COUNTRY_CODE}
  fi
}

function promptNewSigningCAState {
  local SIGNING_CA_STATE=$(gum input --prompt "* State: " --placeholder "California")
  if [ -z "$SIGNING_CA_STATE" ]; then
    promptNewSigningCAState
  else
    echo ${SIGNING_CA_STATE}
  fi
}

function promptNewSigningCALocality {
  local SIGNING_CA_LOCALITY=$(gum input --prompt "* City/Locality: " --placeholder "San Francisco")
  if [ -z "$SIGNING_CA_LOCALITY" ]; then
    promptNewSigningCALocality
  else
    echo ${SIGNING_CA_LOCALITY}
  fi
}

function promptNewSigningCAOrganization {
  local SIGNING_CA_ORGANIZATION=$(gum input --prompt "* Organization: " --placeholder "ACME Corporation")
  if [ -z "$SIGNING_CA_ORGANIZATION" ]; then
    promptNewSigningCAOrganization
  else
    echo ${SIGNING_CA_ORGANIZATION}
  fi
}

function promptNewSigningCAOrganizationalUnit {
  local SIGNING_CA_ORGANIZATIONAL_UNIT=$(gum input --prompt "* Organizational Unit: " --placeholder "InfoSec")
  if [ -z "$SIGNING_CA_ORGANIZATIONAL_UNIT" ]; then
    promptNewSigningCAOrganizationalUnit
  else
    echo ${SIGNING_CA_ORGANIZATIONAL_UNIT}
  fi
}

function promptNewSigningCAEmail {
  local SIGNING_CA_EMAIL=$(gum input --prompt "* Email: " --placeholder "you@acme.com")
  if [ -z "$SIGNING_CA_EMAIL" ]; then
    promptNewSigningCAEmail
  else
    echo ${SIGNING_CA_EMAIL}
  fi
}

function promptNewSigningCACRLURL {
  local SIGNING_CA_CRL_DIST_URI=$(gum input --prompt " [Optional] CRL URI: " --placeholder "https://acme.com/pki/crl")
  echo ${SIGNING_CA_CRL_DIST_URI}
}


function selectSigningCA {
  local CA_PATH=${1}
  local CA_CN=$(getCertificateCommonName "${CA_PATH}/certs/ca.cert.pem")
  local CA_TYPE=$(getCAType ${CA_PATH})
  local SIGNING_CA_DIRS=$(find ${CA_PATH}/signing-ca/ -maxdepth 1 -type d -printf '%p\n' | grep -ve "^${CA_PATH}/signing-ca/$")

  local SIGNING_CA_CERT=""
  local SIGNING_CA_COMMON_NAME=""
  local SIGNING_CA_GLUE=()
  local SIGNING_CA_GLUE_STR=''
  local SIGNING_CA_COMMON_NAMES_STR="../ Back\n[+] Create a new Signing CA"
  
  local SIGNING_CA_COMMON_NAMES=()

  while IFS= read -r line; do
    if [ -z "$line" ]; then
      continue
    fi
    SIGNING_CA_CERT="${line}/certs/ca.cert.pem"
    SIGNING_CA_COMMON_NAME="$(getCertificateCommonName ${SIGNING_CA_CERT})"
    SIGNING_CA_GLUE+=("${line}|${SIGNING_CA_COMMON_NAME}")
    SIGNING_CA_GLUE_STR="${SIGNING_CA_GLUE_STR}${line}|${SIGNING_CA_COMMON_NAME}\n"
    SIGNING_CA_COMMON_NAMES+=("${SIGNING_CA_COMMON_NAME}")
    SIGNING_CA_COMMON_NAMES_STR+="\n$SIGNING_CA_COMMON_NAME"
  done <<< "$SIGNING_CA_DIRS"

  clear
  echoBanner "[${CA_TYPE}] ${CA_CN} - Signing CA Selection"
  echo "===== Path: $(getPKIPath ${CA_PATH})"

  SIGNING_CA_CHOICE=$(echo -e $SIGNING_CA_COMMON_NAMES_STR | gum choose)
  if [ -z "$SIGNING_CA_CHOICE" ]; then
    echo "No Signing CA selected.  Exiting..."
    exit 1
  fi

  SIGNING_CA_CN=$(echo -e ${SIGNING_CA_GLUE_STR} | grep -e "|${SIGNING_CA_CHOICE}\$" | cut -d"|" -f2)
  SIGNING_CA_DIR=$(echo -e ${SIGNING_CA_GLUE_STR} | grep -e "|${SIGNING_CA_CHOICE}\$" | cut -d"|" -f1)

  case "${SIGNING_CA_CHOICE}" in
    ("../ Back")
      selectCAActions ${CA_PATH}
      ;;
    "[+] Create a new Signing CA")
      createNewSigningCA ${CA_PATH}
      ;;
    (*)
      selectCAActions ${SIGNING_CA_DIR}
      ;;
  esac
}

# Create a new Signing CA
# $1 - Parent CA Path
function createNewSigningCA {
  echo -e "\n- Creating a new Signing CA...\n"
  local PARENT_CA_PATH=${1}
  local PARENT_CA_NAME=$(getCertificateCommonName "${PARENT_CA_PATH}/certs/ca.cert.pem")

  local SIGNING_CA_NAME=$(promptNewSigningCAName)
  local SIGNING_CA_COUNTRY_CODE=$(promptNewSigningCACountryCode)
  local SIGNING_CA_STATE=$(promptNewSigningCAState)
  local SIGNING_CA_LOCALITY=$(promptNewSigningCALocality)
  local SIGNING_CA_ORGANIZATION=$(promptNewSigningCAOrganization)
  local SIGNING_CA_ORGANIZATIONAL_UNIT=$(promptNewSigningCAOrganizationalUnit)
  local SIGNING_CA_EMAIL=$(promptNewSigningCAEmail)
  local SIGNING_CA_CRL_DIST_URI=$(promptNewSigningCACRLURL)

  echo -e "- $(bld '[Common] Name:') ${SIGNING_CA_NAME}\n- $(bld Country Code:) ${SIGNING_CA_COUNTRY_CODE}\n- $(bld State:) ${SIGNING_CA_STATE}\n- $(bld Locality:) ${SIGNING_CA_LOCALITY}\n- $(bld Organization:) ${SIGNING_CA_ORGANIZATION}\n- $(bld Organizational Unit:) ${SIGNING_CA_ORGANIZATIONAL_UNIT}\n- $(bld Email:) ${SIGNING_CA_EMAIL}"
  if [ ! -z "${SIGNING_CA_CRL_DIST_URI}" ]; then
    echo -e "- $(bld 'CRL Distribution URI:') ${SIGNING_CA_CRL_DIST_URI}"
  fi

  echo ""

  if gum confirm; then
    #set -x
    local SIGNING_CA_SLUG=$(slugify "${SIGNING_CA_NAME}")
    local SIGNING_CA_DIR=${PARENT_CA_PATH}/signing-ca/${SIGNING_CA_SLUG}

    # Make sure the directory doesn't already exist
    if [ -d ${SIGNING_CA_DIR} ]; then
      echo "- Signing CA \"${SIGNING_CA_NAME}\" Directory already exists: ${SIGNING_CA_DIR}"
      echo "- Aborting..."
      exit 1
    fi
    
    createCommonCAAssets "${SIGNING_CA_DIR}" "Signing"
    
    echo -e "- Creating default OpenSSL configuration files..."
    generateOpenSSLConfFile "${SIGNING_CA_DIR}" "signing" "${SIGNING_CA_COUNTRY_CODE}" "${SIGNING_CA_STATE}" "${SIGNING_CA_LOCALITY}" "${SIGNING_CA_ORGANIZATION}" "${SIGNING_CA_ORGANIZATIONAL_UNIT}" "${SIGNING_CA_EMAIL}" 1875 "${SIGNING_CA_CRL_DIST_URI}"
    
    generatePrivateKey "${SIGNING_CA_DIR}/private/ca.key.pem" "Signing CA"

    if [ ! -f "${SIGNING_CA_DIR}/csr/ca.csr.pem" ]; then
      echo -e "- Creating Signing CA Certificate Signing Request (CSR)..."
      SIGNING_CA_PASS=$(gum input --password --prompt "Enter the password for the Signing CA private key: ")
      SIGN_CA_PASS_FW=$(mktemp)
      echo ${SIGNING_CA_PASS} > ${SIGN_CA_PASS_FW}
      openssl req -new -sha256 \
        -config ${SIGNING_CA_DIR}/openssl.cnf \
        -passin file:${SIGN_CA_PASS_FW} \
        -key ${SIGNING_CA_DIR}/private/ca.key.pem \
        -out ${SIGNING_CA_DIR}/csr/ca.csr.pem \
        -subj "/emailAddress=${SIGNING_CA_EMAIL}/C=${SIGNING_CA_COUNTRY_CODE}/ST=${SIGNING_CA_STATE}/L=${SIGNING_CA_LOCALITY}/O=${SIGNING_CA_ORGANIZATION}/OU=${SIGNING_CA_ORGANIZATIONAL_UNIT}/CN=${SIGNING_CA_NAME}"
      rm -f ${SIGN_CA_PASS_FW}
    else
      echo "- CSR already exists: ${SIGNING_CA_DIR}/csr/ca.csr.pem"
    fi

    if [ ! -f "${SIGNING_CA_DIR}/certs/ca.cert.pem" ]; then
      echo -e "- Signing Signing CA Certificate with parent CA \"${PARENT_CA_NAME}\"..."
      PARENT_CA_PASS=$(gum input --password --prompt "Enter the password for the Parent \"${PARENT_CA_NAME}\" CA private key: ")
      PARENT_CA_PASS_FW=$(mktemp)
      echo ${PARENT_CA_PASS} > ${PARENT_CA_PASS_FW}

      openssl ca -config ${PARENT_CA_PATH}/openssl.cnf -extensions v3_signing_ca \
        -passin file:${PARENT_CA_PASS_FW} \
        -days 1875 -notext -md sha256 \
        -in ${SIGNING_CA_DIR}/csr/ca.csr.pem \
        -out ${SIGNING_CA_DIR}/certs/ca.cert.pem

      rm -f ${PARENT_CA_PASS_FW}
    fi

    if [ ! -z "${SIGNING_CA_CRL_DIST_URI}" ]; then
      if [ ! -f ${SIGNING_CA_DIR}/crl/ca.crl.pem ]; then
        echo "- No CRL found, creating now..."
        openssl ca -config ${SIGNING_CA_DIR}/openssl.cnf -gencrl -out ${SIGNING_CA_DIR}/crl/ca.crl.pem
      else
        echo "- CRL already exists: ${SIGNING_CA_DIR}/crl/ca.crl.pem"
      fi
    fi

    selectCAActions "${SIGNING_CA_DIR}"

  else
    selectCAActions "${PARENT_CA_PATH}"
  fi

}