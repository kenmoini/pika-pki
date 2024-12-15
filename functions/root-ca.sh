#!/bin/bash

source ${SCRIPT_DIR}/functions/formatting.sh
source ${SCRIPT_DIR}/functions/common.sh

function promptNewRootCAName {
  local ROOT_CA_NAME=$(gum input --prompt "* Root CA [Common] Name: " --placeholder "ACME Root Certificate Authority")
  if [ -z "$ROOT_CA_NAME" ]; then
    promptNewRootCAName
  else
    echo ${ROOT_CA_NAME}
  fi
}

function promptNewRootCACountryCode {
  local ROOT_CA_COUNTRY_CODE=$(gum input --prompt "* Country Code: " --placeholder "US" --value "${PIKA_PKI_DEFAULT_COUNTRY}")
  if [ -z "$ROOT_CA_COUNTRY_CODE" ]; then
    promptNewRootCACountryCode
  else
    echo ${ROOT_CA_COUNTRY_CODE}
  fi
}

function promptNewRootCAState {
  local ROOT_CA_STATE=$(gum input --prompt "* State: " --placeholder "California" --value "${PIKA_PKI_DEFAULT_STATE}")
  if [ -z "$ROOT_CA_STATE" ]; then
    promptNewRootCAState
  else
    echo ${ROOT_CA_STATE}
  fi
}

function promptNewRootCALocality {
  local ROOT_CA_LOCALITY=$(gum input --prompt "* City/Locality: " --placeholder "San Francisco" --value "${PIKA_PKI_DEFAULT_LOCALITY}")
  if [ -z "$ROOT_CA_LOCALITY" ]; then
    promptNewRootCALocality
  else
    echo ${ROOT_CA_LOCALITY}
  fi
}

function promptNewRootCAOrganization {
  local ROOT_CA_ORGANIZATION=$(gum input --prompt "* Organization: " --placeholder "ACME Corporation" --value "${PIKA_PKI_DEFAULT_ORG}")
  if [ -z "$ROOT_CA_ORGANIZATION" ]; then
    promptNewRootCAOrganization
  else
    echo ${ROOT_CA_ORGANIZATION}
  fi
}

function promptNewRootCAOrganizationalUnit {
  local ROOT_CA_ORGANIZATIONAL_UNIT=$(gum input --prompt "* Organizational Unit: " --placeholder "InfoSec" --value "${PIKA_PKI_DEFAULT_OU}")
  if [ -z "$ROOT_CA_ORGANIZATIONAL_UNIT" ]; then
    promptNewRootCAOrganizationalUnit
  else
    echo ${ROOT_CA_ORGANIZATIONAL_UNIT}
  fi
}

function promptNewRootCAEmail {
  local ROOT_CA_EMAIL=$(gum input --prompt "* Email: " --placeholder "you@acme.com" --value "${PIKA_PKI_DEFAULT_EMAIL}")
  if [ -z "$ROOT_CA_EMAIL" ]; then
    promptNewRootCAEmail
  else
    echo ${ROOT_CA_EMAIL}
  fi
}

function promptNewRootCACRLURL {
  local ROOT_CA_CRL_DIST_URI=$(gum input --prompt " [Optional] CRL URI Root: " --placeholder "https://acme.com/pki/crl")
  echo ${ROOT_CA_CRL_DIST_URI}
}


function selectRootCA {
  local ROOT_CA_DIRS=$(find ${PIKA_PKI_DIR}/roots/ -maxdepth 1 -type d -printf '%p\n' | grep -ve "^${PIKA_PKI_DIR}/roots/$")
  if [ -z "$ROOT_CA_DIRS" ]; then
    echo "No Root CA's found.  Would you like to create a new one?"
    if gum confirm; then
      createNewRootCA
    fi
  fi

  local ROOT_CA_CERT=""
  local ROOT_CA_COMMON_NAME=""
  local ROOT_CA_GLUE=()
  local ROOT_CA_GLUE_STR=''
  local ROOT_CA_COMMON_NAMES_STR="[+] Create a new Root CA"
  local ROOT_CA_COMMON_NAMES=()

  while IFS= read -r line; do
    if [ -z "$line" ]; then
      continue
    fi
    ROOT_CA_CERT="${line}/certs/ca.cert.pem"
    ROOT_CA_COMMON_NAME="$(getCertificateCommonName ${ROOT_CA_CERT})"
    ROOT_CA_GLUE+=("${line}|${ROOT_CA_COMMON_NAME}")
    ROOT_CA_GLUE_STR="${ROOT_CA_GLUE_STR}${line}|${ROOT_CA_COMMON_NAME}\n"
    ROOT_CA_COMMON_NAMES+=("${ROOT_CA_COMMON_NAME}")
    ROOT_CA_COMMON_NAMES_STR+='\n-|- '${ROOT_CA_COMMON_NAME}
  done <<< "$ROOT_CA_DIRS"

  ROOT_CA_COMMON_NAMES_STR=${ROOT_CA_COMMON_NAMES_STR}'\n[x] Exit'

  clear
  echoBanner "Root CA Selection"

  local ROOT_CA_CHOICE=$(echo -e ${ROOT_CA_COMMON_NAMES_STR} | gum choose)
  if [ -z "$ROOT_CA_CHOICE" ]; then
    echo "No Root CA selected.  Exiting..."
    exit 1
  fi

  case "${ROOT_CA_CHOICE}" in
    ("[+] Create a new Root CA")
      createNewRootCA
      ;;
    ("[x] Exit")
      echo "Exiting..."
      exit 0
      ;;
    (*)
      local CLEANED_ROOT_CA_CHOICE=$(echo ${ROOT_CA_CHOICE} | sed 's/-|- //')
      local ROOT_CA_CN=$(echo -e ${ROOT_CA_GLUE_STR} | grep -e "|${CLEANED_ROOT_CA_CHOICE}\$" | cut -d"|" -f2)
      local ROOT_CA_DIR=$(echo -e ${ROOT_CA_GLUE_STR} | grep -e "|${CLEANED_ROOT_CA_CHOICE}\$" | cut -d"|" -f1)
      selectCAActions "${ROOT_CA_DIR}"
      ;;
  esac

}

function createNewRootCA {
  
  clear
  echoBanner "Create new Root Certificate Authority (CA)"

  local ROOT_CA_NAME=$(promptNewRootCAName)
  local ROOT_CA_COUNTRY_CODE=$(promptNewRootCACountryCode)
  local ROOT_CA_STATE=$(promptNewRootCAState)
  local ROOT_CA_LOCALITY=$(promptNewRootCALocality)
  local ROOT_CA_ORGANIZATION=$(promptNewRootCAOrganization)
  local ROOT_CA_ORGANIZATIONAL_UNIT=$(promptNewRootCAOrganizationalUnit)
  local ROOT_CA_EMAIL=$(promptNewRootCAEmail)
  local ROOT_CA_CRL_DIST_URI=$(promptNewRootCACRLURL)

  echo -e "- $(bld '[Common] Name:') ${ROOT_CA_NAME}\n- $(bld Country Code:) ${ROOT_CA_COUNTRY_CODE}\n- $(bld State:) ${ROOT_CA_STATE}\n- $(bld Locality:) ${ROOT_CA_LOCALITY}\n- $(bld Organization:) ${ROOT_CA_ORGANIZATION}\n- $(bld Organizational Unit:) ${ROOT_CA_ORGANIZATIONAL_UNIT}\n- $(bld Email:) ${ROOT_CA_EMAIL}"
  if [ ! -z "${ROOT_CA_CRL_DIST_URI}" ]; then
    echo -e "- $(bld 'CRL Distribution URI:') ${ROOT_CA_CRL_DIST_URI}"
  fi

  echo ""
  
  if gum confirm; then
    local ROOT_CA_SLUG=$(slugify "${ROOT_CA_NAME}")
    local ROOT_CA_DIR=${PIKA_PKI_DIR}/roots/${ROOT_CA_SLUG}

    # Make sure the directory doesn't already exist
    if [ -d ${ROOT_CA_DIR} ]; then
      echo "- Root CA \"${ROOT_CA_NAME}\" Directory already exists: ${ROOT_CA_DIR}"
      echo "- Aborting..."
      exit 1
    fi

    createCommonCAAssets "${ROOT_CA_DIR}" "Root"

    echo -e "- Creating default OpenSSL configuration files..."
    generateOpenSSLConfFile "${ROOT_CA_DIR}" "${ROOT_CA_NAME}" "${ROOT_CA_SLUG}" "root" "${ROOT_CA_COUNTRY_CODE}" "${ROOT_CA_STATE}" "${ROOT_CA_LOCALITY}" "${ROOT_CA_ORGANIZATION}" "${ROOT_CA_ORGANIZATIONAL_UNIT}" "${ROOT_CA_EMAIL}" 3650 "${ROOT_CA_CRL_DIST_URI}"

    generatePrivateKey "${ROOT_CA_DIR}/private/ca.key.pem" "Root CA"

    if [ ! -f ${ROOT_CA_DIR}/certs/ca.cert.pem ]; then
      echo "- No certificate found, creating now..."
      ROOT_CA_PASS=$(gum input --password --prompt "Enter a password for the Root CA private key: ")
      PW_FILE=$(mktemp)
      echo ${ROOT_CA_PASS} > ${PW_FILE}

      openssl req -config ${ROOT_CA_DIR}/openssl.cnf \
        -key ${ROOT_CA_DIR}/private/ca.key.pem \
        -passin file:${PW_FILE} \
        -new -x509 -days 7500 -sha256 -extensions v3_root_ca \
        -out ${ROOT_CA_DIR}/certs/ca.cert.pem \
        -subj "/emailAddress=${ROOT_CA_EMAIL}/C=${ROOT_CA_COUNTRY_CODE}/ST=${ROOT_CA_STATE}/L=${ROOT_CA_LOCALITY}/O=${ROOT_CA_ORGANIZATION}/OU=${ROOT_CA_ORGANIZATIONAL_UNIT}/CN=${ROOT_CA_NAME}"
      
      rm -f ${PW_FILE}
    else
      echo "- Certificate already exists: ${ROOT_CA_DIR}/certs/ca.cert.pem"
    fi

    if [ ! -z "${ROOT_CA_CRL_DIST_URI}" ]; then
      createCRLFile "${ROOT_CA_DIR}"
    fi

  fi
  selectRootCA

}