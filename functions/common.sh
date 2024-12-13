#!/bin/bash

#trap ctrl_c INT
#
#function ctrl_c() {
#  exit 1
#}

#==============================================================================
# generatePrivateKey - Generate a private key at a given path
# $1 - Key Path
# $2 - Type (default: "") [Certificate, Root CA, Intermediate CA, Signing CA]
# $3 - Bit Length (default: 4096)
#==============================================================================
function generatePrivateKey {
  local KEY_PATH=${1}
  local TYPE=${2:-""}
  local BIT_LENGTH=${3:-4096}
  local PW_FILE=$(mktemp)

  if [ ! -f ${KEY_PATH} ]; then
    echo "- Generating private key..."
    if [ "${TYPE}" == "Certificate" ] && [ "false" == "${PIKA_PKI_CERT_KEY_ENCRYPTION}" ]; then
      openssl genrsa -out ${KEY_PATH} ${BIT_LENGTH}
    else
      local KEY_PASS=$(gum input --password --prompt "Enter a password for the ${TYPE} private key: ")
      echo ${KEY_PASS} > ${PW_FILE}

      openssl genrsa -aes256 -passout file:${PW_FILE} -out ${KEY_PATH} ${BIT_LENGTH}
      rm -f ${PW_FILE}
    fi
    chmod 400 ${KEY_PATH}
  else
    echo "- Private key already exists: ${1}"
  fi
}

#==============================================================================
# echoBanner - Echo a banner with the current workspace and some text
# $1 - CA Path
#==============================================================================
function echoBanner {
  local INPUT_TEXT=${1}
  echo "===== Workspace: ${PIKA_PKI_DIR} - ${INPUT_TEXT}"
}

#==============================================================================
# getCertificateCommonName - Get the Common Name (CN) for a given certificate
#==============================================================================
function getCertificateCommonName {
  local CERT_PATH=${1}
  openssl x509 -noout -subject -in ${CERT_PATH} -nameopt multiline | awk -F' = ' '/commonName/ {print $2}'
}

#==============================================================================
# createCommonCAAssets - Create common assets for a CA eg. directories, files
# $1 - CA Path
#==============================================================================
function createCommonCAAssets {
  local CA_PATH=${1}
  local TYPE=${2:-""}

  echo -e "\n- Creating ${TYPE} CA in ${CA_PATH}"
  if [ "${TYPE}" == "Signing" ]; then
    mkdir -p ${CA_PATH}/{certs,crl,csr,newcerts,private}
  else
    mkdir -p ${CA_PATH}/{certs,crl,csr,newcerts,private,intermediate-ca,signing-ca}
  fi
  mkdir -p ${CA_PATH}/public_bundles/{certs,crls}
  chmod 700 ${CA_PATH}/private
  chmod -R 777 ${CA_PATH}/public_bundles

  echo "- Touching basic files (index, serial, crlnumber)..."
  touch ${CA_PATH}/index.txt
  [ ! -f ${CA_PATH}/serial ] && echo 1000 > ${CA_PATH}/serial
  [ ! -f ${CA_PATH}/crlnumber ] && echo 1000 > ${CA_PATH}/crlnumber
}

#==============================================================================
# getCAParentPath - Get the parent path for a given CA path
# $1 - CA Path
#==============================================================================
function getCAParentPath {
  local CA_PATH=${1}
  local PARENT_PATH=$(dirname $(dirname ${CA_PATH}))
  echo $PARENT_PATH
}

#==============================================================================
# getCAType - Get the type of CA based on the path
# $1 - CA Path
#==============================================================================
function getCAType {
  local CA_PATH=${1}
  local PARENT_PATH=$(basename $(dirname ${CA_PATH}))
  case "${PARENT_PATH}" in
    "roots")
      echo "Root"
      ;;
    "intermediate-ca")
      echo "Intermediate"
      ;;
    "signing-ca")
      echo "Signing"
      ;;
  esac
}

#==============================================================================
# getPKIPath - Get the PKI path for a given CA
# $1 - CA Path
# Assuming the normal directory structure:
# /roots/{$ROOT_CA}/${intermediate-ca/${INTERMEDIATE_CA}...N}/signing-ca/${SIGNING_CA}
# This function will return the path in a human-readable format:
# $ROOT_CA > $INTERMEDIATE_CA ...N > $SIGNING_CA
#==============================================================================
function getPKIPath {
  local CA_PATH=${1}
  local BASE_PATH=$(sed 's|'$PIKA_PKI_DIR'/||g' <<< ${CA_PATH})
  local ROOT=$(sed 's|roots/||' <<< ${BASE_PATH})
  local INTERMEDIATE=$(sed 's|/intermediate-ca/| > |' <<< ${ROOT})
  local SIGNING=$(sed 's|/signing-ca/| > |' <<< ${INTERMEDIATE})
  echo $SIGNING
}

#==============================================================================
# selectCAActions - Select the actions for a given CA
# $1 - CA Path
#==============================================================================
function selectCAActions {
  local ACTIVE_CA_PATH=${1}
  local CA_TYPE=$(getCAType ${ACTIVE_CA_PATH})
  local IS_ROOT_CA="false"
  if [ "${ACTIVE_CA_PATH}" == "${ROOT_CA_DIR}" ]; then
    IS_ROOT_CA="true"
  fi

  local INTERMEDIATE_CA_COUNT=0
  local SIGNING_CA_COUNT=0
  local CERTIFICATE_COUNT=0
  local CERTIFICATES=$(find ${ACTIVE_CA_PATH}/certs/ -maxdepth 1 -type f -name '*.cert.pem' -printf '%p\n' | grep -ve "^${ACTIVE_CA_PATH}/certs/ca.cert.pem$")
  local CERTIFICATE_COUNT=$(echo -e "${CERTIFICATES}" | sed '/^$/d' | wc -l)
  local CA_ACTIONS='../ Back\n[+] Certificates ('$CERTIFICATE_COUNT')'
  
  clear
  echoBanner "[${CA_TYPE}] $(getCertificateCommonName ${ACTIVE_CA_PATH}/certs/ca.cert.pem)"
  echo "===== CA Path: $(getPKIPath ${ACTIVE_CA_PATH})"

  if [ "$CA_TYPE" != "Signing" ]; then
    local INTERMEDIATE_CA_DIRS=$(find ${ACTIVE_CA_PATH}/intermediate-ca/ -maxdepth 1 -type d -printf '%p\n' | grep -ve "^${ACTIVE_CA_PATH}/intermediate-ca/$")
    local SIGNING_CA_DIRS=$(find ${ACTIVE_CA_PATH}/signing-ca/ -maxdepth 1 -type d -printf '%p\n' | grep -ve "^${ACTIVE_CA_PATH}/signing-ca/$")
    local INTERMEDIATE_CA_COUNT=$(echo -e "${INTERMEDIATE_CA_DIRS}" | sed '/^$/d' | wc -l)
    local SIGNING_CA_COUNT=$(echo -e "${SIGNING_CA_DIRS}" | sed '/^$/d' | wc -l)
    CA_ACTIONS=${CA_ACTIONS}'\n[+] Intermediate CAs ('$INTERMEDIATE_CA_COUNT')\n[+] Signing CAs ('$SIGNING_CA_COUNT')'
  fi

  local SELECTED_ACTION=$(echo -e "${CA_ACTIONS}" | gum choose)
  if [ -z "$SELECTED_ACTION" ]; then
    echo "No action selected, exiting..."
    exit 1
  fi

  case "$SELECTED_ACTION" in
    "../ Back")
      if [ "${IS_ROOT_CA}" == "true" ]; then
        selectRootCA
      else
        selectCAActions $(getCAParentPath ${ACTIVE_CA_PATH})
      fi
      ;;
    "[+] Certificates"*)
      certificateSelectionScreen ${ACTIVE_CA_PATH}
      ;;
    "[+] Intermediate CAs"*)
      selectIntermediateCA ${ACTIVE_CA_PATH}
      ;;
    "[+] Signing CAs"*)
      selectSigningCA ${ACTIVE_CA_PATH}
      ;;
    *)
      echo "Invalid selection, exiting"
      exit 1
      ;;
  esac
}

#==============================================================================
# certificateSelectionScreen displays a list of certificates for a CA and allows the user to select one for further actions.
# $1 - CA Path
#==============================================================================
function certificateSelectionScreen {
  local CA_PATH=${1}
  local CA_TYPE=$(getCAType ${CA_PATH})
  local CERT_OPTIONS='../ Back\n[+] Create a new Certificate'
  local CERTIFICATES=$(find ${CA_PATH}/certs/ -maxdepth 1 -type f -name '*.cert.pem' -printf '%p\n' | grep -ve "^${CA_PATH}/certs/ca.cert.pem$" | sed '/^$/d' | sed 's|'${CA_PATH}'/certs/||g' | sed 's|.cert.pem||g')
  if [ ! -z "${CERTIFICATES}" ]; then
    CERT_OPTIONS=''${CERT_OPTIONS}'\n'${CERTIFICATES}''
  fi

  clear
  #echoBanner "[${CA_TYPE}] $(getBannerPath "${CA_PATH}") - Certificate Selection"
  echoBanner "[${CA_TYPE}] $(getCertificateCommonName ${ACTIVE_CA_PATH}/certs/ca.cert.pem) - Certificate Selection"
  echo "===== CA Path: $(getPKIPath ${CA_PATH})"
  
  local SELECTED_ACTION=$(echo -e "${CERT_OPTIONS}" | gum choose)
  if [ -z "$SELECTED_ACTION" ]; then
    echo "No action selected, exiting..."
    exit 1
  fi

  case "$SELECTED_ACTION" in
    "../ Back")
      selectCAActions ${CA_PATH}
      ;;
    "[+] Create a new Certificate")
      createNewCertificate ${CA_PATH}
      ;;
    *)
      clear
      viewCertificate "${CA_PATH}/certs/${SELECTED_ACTION}.cert.pem"
      ;;
  esac

}

#==============================================================================
# generateCAChain generates a certificate chain for any given certificate
# $1 - Certificate Path
# $2 - Include Root (default: false)
#
# Proper order of Certs in a chain:
#
# -----BEGIN CERTIFICATE-----
# [Server Certificate]
# -----END CERTIFICATE-----
# -----BEGIN CERTIFICATE-----
# [Intermediate certificate L1]
# -----END CERTIFICATE-----
# -----BEGIN CERTIFICATE-----
# [Intermediate certificate L2]
# -----END CERTIFICATE-----
# -----BEGIN CERTIFICATE-----
# [Root Certificate]
# -----END CERTIFICATE-----
#
#==============================================================================
function generateCAChain {
  local CERT_PATH=${1} # /path/to/pki/roots/ca/intermediate-ca/int/certs/ca.cert.pem
  local INCLUDE_ROOT=${2:-"false"}
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH})) # /path/to/pki/roots/ca/intermediate-ca/int
  local CERT_CA_PATH_PARENT_TYPE=$(basename $(dirname ${CERT_CA_PATH})) # intermediate-ca
  local CERT_CA_PEM=$(cat "${CERT_CA_PATH}/certs/ca.cert.pem")
  local CERT_CA_CN=$(getCertificateCommonName "${CERT_CA_PATH}/certs/ca.cert.pem")
  
  local CHAIN_PEM=""

  if [ "${CERT_CA_PATH_PARENT_TYPE}" != "roots" ]; then
    # If this is a signing or intermediate CA, cat out this cert, then suffix the parent cert via a loop
    echo "# ${CERT_CA_CN}"
    CHAIN_PEM=''${CERT_CA_PEM}'\n'$(generateCAChain "$(dirname $(dirname ${CERT_CA_PATH}))/certs/ca.cert.pem" "${INCLUDE_ROOT}")
  else
    # If this is a root CA, only cat out this cert if we're including the root
    if [ "${INCLUDE_ROOT}" == "true" ]; then
      echo "# ${CERT_CA_CN}"
      CHAIN_PEM=${CERT_CA_PEM}
    fi
  fi

  echo -e "${CHAIN_PEM}"
}

#==============================================================================
# isCertificateAuthority checks if a certificate is a Certificate Authority.
# $1 - Certificate Path
#==============================================================================
function isCertificateAuthority {
  local CERT_PATH=${1}
  local IS_CA=$(openssl x509 -noout -text -in ${CERT_PATH} | grep -e "CA:TRUE")
  if [ ! -z "${IS_CA}" ]; then
    echo "true"
  else
    echo "false"
  fi
}

#==============================================================================
# getRootCAPath - Get the Root CA for any given certificate
# $1 - Certificate Path
#==============================================================================
function getRootCAPath {
  local CERT_PATH=${1}
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))
  local CERT_CA_PARENT=$(basename $(dirname ${CERT_CA_PATH}))
  local CERT_CA_PARENT_CA_PATH=$(dirname $(dirname ${CERT_CA_PATH}))

  if [ "${CERT_CA_PARENT}" == "roots" ]; then
    echo ${CERT_CA_PATH}
  else
    getRootCAPath "${CERT_CA_PARENT_CA_PATH}/certs/ca.cert.pem"
  fi
}


#==============================================================================
# createCRLFile - Create a Certificate Revocation List (CRL) for a CA
# $1 - CA base Directory
#==============================================================================
function createCRLFile {
  local CA_DIR=${1}
  if [ ! -f ${CA_DIR}/crl/ca.crl.pem ]; then
    echo "- Creating Certificate Revocation List..."
    openssl ca -config ${CA_DIR}/openssl.cnf -gencrl -out ${CA_DIR}/crl/ca.crl.pem
  else
    echo "- CRL already exists: ${CA_DIR}/crl/ca.crl.pem"
  fi
}