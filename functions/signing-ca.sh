#!/bin/bash

shopt -s extglob;

source ${SCRIPT_DIR}/functions/formatting.sh
source ${SCRIPT_DIR}/functions/common.sh
source ${SCRIPT_DIR}/functions/prompts.ca.sh

function selectSigningCAScreen {
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
    SIGNING_CA_COMMON_NAMES_STR+="\n-|- ${SIGNING_CA_COMMON_NAME}"
  done <<< "$SIGNING_CA_DIRS"

  clear
  echoBanner "[${CA_TYPE}] ${CA_CN} - Signing CA Selection"
  echo "===== CA Path: $(getPKIPath ${CA_PATH})"

  local SIGNING_CA_CHOICE=$(echo -e "${SIGNING_CA_COMMON_NAMES_STR}" | gum choose)
  if [ -z "$SIGNING_CA_CHOICE" ]; then
    echo "No Signing CA selected.  Exiting..."
    exit 1
  fi

  local CLEANED_SIGNING_CA_CHOICE=$(echo ${SIGNING_CA_CHOICE} | sed 's/-|- //')
  local SIGNING_CA_CN=$(echo -e ${SIGNING_CA_GLUE_STR} | grep -e "|${CLEANED_SIGNING_CA_CHOICE}\$" | cut -d"|" -f2)
  local SIGNING_CA_DIR=$(echo -e ${SIGNING_CA_GLUE_STR} | grep -e "|${CLEANED_SIGNING_CA_CHOICE}\$" | cut -d"|" -f1)

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
    
    # Create things such as paths, index files, etc.
    createCommonCAAssets "${SIGNING_CA_DIR}" "Signing"

    # Create the OpenSSL Configuration file
    echo -e "- Creating default OpenSSL configuration files..."
    generateOpenSSLConfFile "${SIGNING_CA_DIR}" "${SIGNING_CA_NAME}" "${SIGNING_CA_SLUG}" "signing" "${SIGNING_CA_COUNTRY_CODE}" "${SIGNING_CA_STATE}" "${SIGNING_CA_LOCALITY}" "${SIGNING_CA_ORGANIZATION}" "${SIGNING_CA_ORGANIZATIONAL_UNIT}" "${SIGNING_CA_EMAIL}" 1875 "${SIGNING_CA_CRL_DIST_URI}"
    
    # Prompt for a Root CA Password
    # At this point, you could potentially edit the openssl.cnf file to modify things before the Root CA gets created
    local SIGN_CA_PASS_FW=$(mktemp)
    local KEY_PASS=$(gum input --password --prompt "Enter a password for the Signing CA private key: ")
    echo ${KEY_PASS} > ${SIGN_CA_PASS_FW}

    # Generate the Root CA private key
    generatePrivateKey "${SIGNING_CA_DIR}/private/ca.key.pem" "Signing CA" "${SIGN_CA_PASS_FW}"

    # Generate the Signing CA CSR
    if [ ! -f "${SIGNING_CA_DIR}/csr/ca.csr.pem" ]; then
      echo -e "- Creating Signing CA Certificate Signing Request (CSR)..."
      
      openssl req -new -sha256 -batch \
        -config ${SIGNING_CA_DIR}/openssl.cnf \
        -passin file:${SIGN_CA_PASS_FW} \
        -key ${SIGNING_CA_DIR}/private/ca.key.pem \
        -out ${SIGNING_CA_DIR}/csr/ca.csr.pem \
        -subj "/emailAddress=${SIGNING_CA_EMAIL}/C=${SIGNING_CA_COUNTRY_CODE}/ST=${SIGNING_CA_STATE}/L=${SIGNING_CA_LOCALITY}/O=${SIGNING_CA_ORGANIZATION}/OU=${SIGNING_CA_ORGANIZATIONAL_UNIT}/CN=${SIGNING_CA_NAME}"
    else
      echo "- CSR already exists: ${SIGNING_CA_DIR}/csr/ca.csr.pem"
    fi

    # Sign the Signing CA CSR with the parent CA
    if [ ! -f "${SIGNING_CA_DIR}/certs/ca.cert.pem" ]; then
      echo -e "- Signing Signing CA Certificate with parent CA \"${PARENT_CA_NAME}\"..."
      PARENT_CA_PASS=$(gum input --password --prompt "Enter the password for the Parent \"${PARENT_CA_NAME}\" CA private key: ")
      PARENT_CA_PASS_FW=$(mktemp)
      echo ${PARENT_CA_PASS} > ${PARENT_CA_PASS_FW}

      openssl ca -config ${PARENT_CA_PATH}/openssl.cnf -extensions v3_signing_ca \
        -passin file:${PARENT_CA_PASS_FW} \
        -days 1875 -notext -md sha256 -batch \
        -in ${SIGNING_CA_DIR}/csr/ca.csr.pem \
        -out ${SIGNING_CA_DIR}/certs/ca.cert.pem

      rm -f ${PARENT_CA_PASS_FW}
    fi

    if [ ! -z "${SIGNING_CA_CRL_DIST_URI}" ]; then
      createCRLFile "${SIGNING_CA_DIR}" "${SIGN_CA_PASS_FW}"
    else
      # Copy the Root CA public bundle around
      copyCAPublicBundles ${SIGNING_CA_DIR}
    fi

    rm -f ${SIGN_CA_PASS_FW}

    selectCAActions "${SIGNING_CA_DIR}"

  else
    selectCAActions "${PARENT_CA_PATH}"
  fi

}