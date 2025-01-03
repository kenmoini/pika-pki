#!/bin/bash

source ${SCRIPT_DIR}/functions/formatting.sh
source ${SCRIPT_DIR}/functions/common.sh
source ${SCRIPT_DIR}/functions/prompts.ca.sh

function selectRootCAScreen {
  local ROOT_CA_DIRS=$(find ${PIKA_PKI_DIR}/roots/ -maxdepth 1 -type d -printf '%p\n' | grep -ve "^${PIKA_PKI_DIR}/roots/$")
  if [ -z "$ROOT_CA_DIRS" ]; then
    clear
    echoBanner "Empty Workspace"
    echo "No Root CA's found.  Would you like to create a new one?"
    if gum confirm; then
      createNewRootCA
    fi
  fi

  local ROOT_CA_CERT=""
  local ROOT_CA_COMMON_NAME=""
  local ROOT_CA_GLUE=()
  local ROOT_CA_GLUE_STR=''
  local ROOT_CA_COMMON_NAMES_STR="[x] Exit"
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

  ROOT_CA_COMMON_NAMES_STR=${ROOT_CA_COMMON_NAMES_STR}'\n[+] Create a new Root CA'

  clear
  echoBanner "Root CA Selection"

  local ROOT_CA_CHOICE=$(echo -e "${ROOT_CA_COMMON_NAMES_STR}" | gum choose)
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
  local ROOT_CA_SLUG=$(slugify "${ROOT_CA_NAME}")
  local ROOT_CA_COUNTRY_CODE=$(promptNewRootCACountryCode)
  local ROOT_CA_STATE=$(promptNewRootCAState)
  local ROOT_CA_LOCALITY=$(promptNewRootCALocality)
  local ROOT_CA_ORGANIZATION=$(promptNewRootCAOrganization)
  local ROOT_CA_ORGANIZATIONAL_UNIT=$(promptNewRootCAOrganizationalUnit)
  local ROOT_CA_EMAIL=$(promptNewRootCAEmail)
  local ROOT_CA_DIST_URI=$(promptNewCAURI)

  echo -e "- $(bld '[Common] Name:') ${ROOT_CA_NAME}\n- $(bld Country Code:) ${ROOT_CA_COUNTRY_CODE}\n- $(bld State:) ${ROOT_CA_STATE}\n- $(bld Locality:) ${ROOT_CA_LOCALITY}\n- $(bld Organization:) ${ROOT_CA_ORGANIZATION}\n- $(bld Organizational Unit:) ${ROOT_CA_ORGANIZATIONAL_UNIT}\n- $(bld Email:) ${ROOT_CA_EMAIL}"
  if [ ! -z "${ROOT_CA_DIST_URI}" ]; then
    echo -e "- $(bld 'CA Distribution URI:') ${ROOT_CA_DIST_URI}"
    echo -e "- $(bld 'CRL URI:') ${ROOT_CA_DIST_URI}/crls/root-ca.${ROOT_CA_SLUG}.crl"
  fi

  echo ""
  
  if gum confirm; then
    local ROOT_CA_DIR=${PIKA_PKI_DIR}/roots/${ROOT_CA_SLUG}

    # Make sure the directory doesn't already exist
    if [ -d ${ROOT_CA_DIR} ]; then
      echo "- Root CA \"${ROOT_CA_NAME}\" Directory already exists: ${ROOT_CA_DIR}"
      echo "- Aborting..."
      exit 1
    fi

    # Create things such as paths, index files, etc.
    createCommonCAAssets "${ROOT_CA_DIR}" "Root"

    # Create the OpenSSL Configuration file
    echo -e "- Creating default OpenSSL configuration files..."
    generateOpenSSLConfFile "${ROOT_CA_DIR}" "${ROOT_CA_NAME}" "${ROOT_CA_SLUG}" "root" "${ROOT_CA_COUNTRY_CODE}" "${ROOT_CA_STATE}" "${ROOT_CA_LOCALITY}" "${ROOT_CA_ORGANIZATION}" "${ROOT_CA_ORGANIZATIONAL_UNIT}" "${ROOT_CA_EMAIL}" 3650 "${ROOT_CA_DIST_URI}"
    
    # Prompt for a Root CA Password
    # At this point, you could potentially edit the openssl.cnf file to modify things before the Root CA gets created
    local PW_FILE=$(mktemp)
    local KEY_PASS=$(gum input --password --prompt "Enter a password for the Root CA private key: ")
    echo ${KEY_PASS} > ${PW_FILE}

    # Generate the Root CA private key
    generatePrivateKey "${ROOT_CA_DIR}/private/ca.key.pem" "Root CA" "${PW_FILE}"

    # Generate the self signed Root CA Certificate
    if [ ! -f ${ROOT_CA_DIR}/certs/ca.cert.pem ]; then
      echo "- No certificate found, creating now..."

      openssl req -config ${ROOT_CA_DIR}/openssl.cnf \
        -key ${ROOT_CA_DIR}/private/ca.key.pem \
        -batch -passin file:${PW_FILE} \
        -new -x509 -days 7500 -sha256 -extensions v3_root_ca \
        -out ${ROOT_CA_DIR}/certs/ca.cert.pem \
        -subj "/emailAddress=${ROOT_CA_EMAIL}/C=${ROOT_CA_COUNTRY_CODE}/ST=${ROOT_CA_STATE}/L=${ROOT_CA_LOCALITY}/O=${ROOT_CA_ORGANIZATION}/OU=${ROOT_CA_ORGANIZATIONAL_UNIT}/CN=${ROOT_CA_NAME}"
    else
      echo "- Certificate already exists: ${ROOT_CA_DIR}/certs/ca.cert.pem"
    fi

    # Create the CRL file if a CRL Distribution URI is provided
    if [ ! -z "${ROOT_CA_DIST_URI}" ]; then
      createCRLFile "${ROOT_CA_DIR}" "${PW_FILE}"
    else
      # Copy the Root CA public bundle around
      copyCAPublicBundles ${ROOT_CA_DIR}
    fi

    rm -f ${PW_FILE}

  fi
  # Return back to the Root CA selection screen
  selectRootCAScreen

}