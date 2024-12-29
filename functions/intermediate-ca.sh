#!/bin/bash

shopt -s extglob;

source ${SCRIPT_DIR}/functions/formatting.sh
source ${SCRIPT_DIR}/functions/common.sh
source ${SCRIPT_DIR}/functions/prompts.ca.sh

function selectIntermediateCAScreen {
  local CA_PATH=${1}
  local CA_CN=$(getCertificateCommonName "${CA_PATH}/certs/ca.cert.pem")
  local CA_TYPE=$(getCAType ${CA_PATH})
  local INT_CA_DIRS=$(find ${CA_PATH}/intermediate-ca/ -maxdepth 1 -type d -printf '%p\n' | grep -ve "^${CA_PATH}/intermediate-ca/$")

  local INT_CA_CERT=""
  local INT_CA_COMMON_NAME=""
  local INT_CA_GLUE=()
  local INT_CA_GLUE_STR=''
  local INT_CA_COMMON_NAMES_STR="../ Back"
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

  local INT_CA_COMMON_NAMES_STR+="\n[+] Create a new Intermediate CA"

  clear
  echoBanner "[${CA_TYPE}] ${CA_CN} - Intermediate CA Selection"
  echo "===== CA Path: $(getPKIPath ${CA_PATH})"

  local INT_CA_CHOICE=$(echo -e "${INT_CA_COMMON_NAMES_STR}" | gum choose)
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
  local PARENT_CA_SLUG=$(slugify "${PARENT_CA_NAME}")
  local PARENT_CA_URI_BASE=$(getCAURIBase ${PARENT_CA_PATH})
  local PARENT_CA_TYPE=$(getCAType ${PARENT_CA_PATH} | tr '[:upper:]' '[:lower:]')

  local INTERMEDIATE_CA_NAME=$(promptNewIntermediateCAName)
  local INTERMEDIATE_CA_COUNTRY_CODE=$(promptNewIntermediateCACountryCode)
  local INTERMEDIATE_CA_STATE=$(promptNewIntermediateCAState)
  local INTERMEDIATE_CA_LOCALITY=$(promptNewIntermediateCALocality)
  local INTERMEDIATE_CA_ORGANIZATION=$(promptNewIntermediateCAOrganization)
  local INTERMEDIATE_CA_ORGANIZATIONAL_UNIT=$(promptNewIntermediateCAOrganizationalUnit)
  local INTERMEDIATE_CA_EMAIL=$(promptNewIntermediateCAEmail)
  local INTERMEDIATE_CA_DIST_URI=$(promptNewCAURI)
  local INTERMEDIATE_CA_CRL_URI=""
  local INTERMEDIATE_CA_AIA_URI=""

  # If the Parent/Signing CA has a URI base, then we can use it to generate the CRL URI for this Intermediate CA
  if [ ! -z "${PARENT_CA_URI_BASE}" ]; then
    INTERMEDIATE_CA_CRL_URI="${PARENT_CA_URI_BASE}/crls/${PARENT_CA_TYPE}-ca.${PARENT_CA_SLUG}.crl"
    INTERMEDIATE_CA_AIA_URI="${PARENT_CA_URI_BASE}/certs/${PARENT_CA_TYPE}-ca.${PARENT_CA_SLUG}.${CERT_DER_FILE_EXTENSION}"
  fi

  echo -e "- $(bld '[Common] Name:') ${INTERMEDIATE_CA_NAME}\n- $(bld Country Code:) ${INTERMEDIATE_CA_COUNTRY_CODE}\n- $(bld State:) ${INTERMEDIATE_CA_STATE}\n- $(bld Locality:) ${INTERMEDIATE_CA_LOCALITY}\n- $(bld Organization:) ${INTERMEDIATE_CA_ORGANIZATION}\n- $(bld Organizational Unit:) ${INTERMEDIATE_CA_ORGANIZATIONAL_UNIT}\n- $(bld Email:) ${INTERMEDIATE_CA_EMAIL}"
  if [ ! -z "${INTERMEDIATE_CA_DIST_URI}" ]; then
    echo -e "- $(bld 'CA Distribution URI:') ${INTERMEDIATE_CA_DIST_URI}"
  fi
  if [ ! -z "${PARENT_CA_URI_BASE}" ]; then
    echo -e "- $(bld 'CRL URI (from signing CA):') ${INTERMEDIATE_CA_CRL_URI}"
    echo -e "- $(bld 'AIA URI (from signing CA):') ${INTERMEDIATE_CA_AIA_URI}"
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

    # Create things such as paths, index files, etc.
    createCommonCAAssets "${INTERMEDIATE_CA_DIR}" "Intermediate"

    # Create the OpenSSL Configuration file
    echo -e "- Creating default OpenSSL configuration files..."
    generateOpenSSLConfFile "${INTERMEDIATE_CA_DIR}" "${INTERMEDIATE_CA_NAME}" "${INTERMEDIATE_CA_SLUG}" "intermediate" "${INTERMEDIATE_CA_COUNTRY_CODE}" "${INTERMEDIATE_CA_STATE}" "${INTERMEDIATE_CA_LOCALITY}" "${INTERMEDIATE_CA_ORGANIZATION}" "${INTERMEDIATE_CA_ORGANIZATIONAL_UNIT}" "${INTERMEDIATE_CA_EMAIL}" 3650 "${INTERMEDIATE_CA_DIST_URI}" "${PARENT_CA_URI_BASE}" "${PARENT_CA_TYPE}" "${PARENT_CA_SLUG}"

    # Prompt for a Intermediate CA Password
    # At this point, you could potentially edit the openssl.cnf file to modify things before the Intermediate CA gets created
    local INT_CA_PASS_FW=$(mktemp)
    local KEY_PASS=$(gum input --password --prompt "Enter a password for the Intermediate CA private key: ")
    echo ${KEY_PASS} > ${INT_CA_PASS_FW}

    # Generate the Intermediate CA private key
    generatePrivateKey "${INTERMEDIATE_CA_DIR}/private/ca.key.pem" "Intermediate CA" "${INT_CA_PASS_FW}"

    if [ ! -f "${INTERMEDIATE_CA_DIR}/csr/ca.csr.pem" ]; then
      echo -e "- Creating Intermediate CA Certificate Signing Request (CSR)..."
      
      openssl req -new -sha256 -batch \
        -config ${INTERMEDIATE_CA_DIR}/openssl.cnf \
        -passin file:${INT_CA_PASS_FW} \
        -key ${INTERMEDIATE_CA_DIR}/private/ca.key.pem \
        -out ${INTERMEDIATE_CA_DIR}/csr/ca.csr.pem \
        -subj "/emailAddress=${INTERMEDIATE_CA_EMAIL}/C=${INTERMEDIATE_CA_COUNTRY_CODE}/ST=${INTERMEDIATE_CA_STATE}/L=${INTERMEDIATE_CA_LOCALITY}/O=${INTERMEDIATE_CA_ORGANIZATION}/OU=${INTERMEDIATE_CA_ORGANIZATIONAL_UNIT}/CN=${INTERMEDIATE_CA_NAME}"

    else
      echo "- CSR already exists: ${INTERMEDIATE_CA_DIR}/csr/ca.csr.pem"
    fi

    if [ ! -f "${INTERMEDIATE_CA_DIR}/certs/ca.cert.pem" ]; then
      echo -e "- Signing Intermediate CA Certificate with parent CA \"${PARENT_CA_NAME}\"..."
      PARENT_CA_PASS=$(gum input --password --prompt "Enter the password for the Parent \"${PARENT_CA_NAME}\" CA private key: ")
      PARENT_CA_PASS_FW=$(mktemp)
      echo ${PARENT_CA_PASS} > ${PARENT_CA_PASS_FW}

      openssl ca -config ${PARENT_CA_PATH}/openssl.cnf -extensions v3_intermediate_ca \
        -days 3750 -notext -md sha256 -batch \
        -passin file:${PARENT_CA_PASS_FW} \
        -in ${INTERMEDIATE_CA_DIR}/csr/ca.csr.pem \
        -out ${INTERMEDIATE_CA_DIR}/certs/ca.cert.pem

      rm -f ${PARENT_CA_PASS_FW}
    fi

    if [ ! -z "${INTERMEDIATE_CA_DIST_URI}" ]; then
      createCRLFile "${INTERMEDIATE_CA_DIR}" "${INT_CA_PASS_FW}"
    else
      # Copy the Intermediate CA public bundle around
      copyCAPublicBundles ${INTERMEDIATE_CA_DIR}
    fi

    rm -f ${INT_CA_PASS_FW}

    selectCAActions "${INTERMEDIATE_CA_DIR}"

  else
    selectCAActions "${PARENT_CA_PATH}"
  fi

}