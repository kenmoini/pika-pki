#!/bin/bash

#trap ctrl_c INT
#
#function ctrl_c() {
#  exit 1
#}

#======================================================================================================================================
# Helper Functions
#======================================================================================================================================

#==============================================================================
# showHelpMenu - Show the help menu
#==============================================================================
function showHelpMenu {
  echo "Usage:"
  echo "pika-pki.sh         # Start the Text User Interface (TUI)"
  echo "pika-pki.sh [-h] [-m createCertificate|rotateCertificate|signCSR|rotateCRL|copyBundles]  # Batch parameters"
  echo ""
  echo "   -h     help (this output)"
  echo "   -m     mode (createCertificate | rotateCertificate | revokeCertificate | signCSR | rotateCRL | copyBundles)"
  echo "   -a     Certificate Authority Path"
  echo "   -c     Country Code"
  echo "   -e     Email"
  echo "   -f     Certificate Path"
  echo "   -l     Locality"
  echo "   -n     Common Name"
  echo "   -o     Organization"
  echo "   -p     Password or file path with password for the CA private key - if not provided, will be prompted"
  echo "   -s     Subject Alternative Names (SANs) eg 'DNS:example.com,DNS:www.example.com,IP:1.2.3.4'"
  echo "   -t     State"
  echo "   -u     Organizational Unit"
  echo ""
  echo "# Copy public bundles to the public_bundles directories"
  echo "  pika-pki.sh -m copyBundles"
  echo ""
  echo "# Rotate a CA CRL"
  echo "  pika-pki.sh -m rotateCRL -a .pika-pki/root/kemo-root/ -p CApasswordOrPathToPasswordFile"
  echo ""
  echo "# Revoke a Certificate"
  echo "  pika-pki.sh -m revokeCertificate -f .pika-pki/root/kemo-root/certs/example.com.cert.pem -p CApasswordOrPathToPasswordFile"
  echo ""
  echo "# Rotate a Certificate"
  echo "  pika-pki.sh -m rotateCertificate -f .pika-pki/root/kemo-root/certs/example.com.cert.pem -p CApasswordOrPathToPasswordFile"
  echo ""
  echo "# Recreate a Certificate - Revoke, Delete, Recreate everything"
  echo "  pika-pki.sh -m recreateCertificate -f .pika-pki/root/kemo-root/certs/example.com.cert.pem -p CApasswordOrPathToPasswordFile"
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

function getCSRCommonName {
  local CSR_PATH=${1}
  openssl req -noout -subject -in ${CSR_PATH} -nameopt multiline | awk -F' = ' '/commonName/ {print $2}'
}

function getCertificateOrganization {
  local CERT_PATH=${1}
  openssl x509 -noout -subject -in ${CERT_PATH} -nameopt multiline | awk -F' = ' '/organizationName/ {print $2}'
}

function getCertificateOrganizationalUnit {
  local CERT_PATH=${1}
  openssl x509 -noout -subject -in ${CERT_PATH} -nameopt multiline | awk -F' = ' '/organizationalUnitName/ {print $2}'
}

function getCertificateCountry {
  local CERT_PATH=${1}
  openssl x509 -noout -subject -in ${CERT_PATH} -nameopt multiline | awk -F' = ' '/countryName/ {print $2}'
}

function getCertificateState {
  local CERT_PATH=${1}
  openssl x509 -noout -subject -in ${CERT_PATH} -nameopt multiline | awk -F' = ' '/stateOrProvinceName/ {print $2}'
}

function getCertificateLocality {
  local CERT_PATH=${1}
  openssl x509 -noout -subject -in ${CERT_PATH} -nameopt multiline | awk -F' = ' '/localityName/ {print $2}'
}

function getCertificateEmail {
  local CERT_PATH=${1}
  openssl x509 -noout -subject -in ${CERT_PATH} -nameopt multiline | awk -F' = ' '/emailAddress/ {print $2}'
}

function getCertificateSANS {
  local CERT_PATH=${1}
  openssl x509 -noout -ext subjectAltName -in ${CERT_PATH} | sed 's/subjectAltName=//g' | sed 's/,/\n/g' | tail -n +2 | tr -d '[:blank:]' | tr '\n' ',' | sed 's|,*$||'
}

function getCAURIBase {
  local CA_PATH=${1}
  local CA_URI_BASE=$(cat ${CA_PATH}/openssl.cnf | grep -e "#  - Distribution URI: " | awk -F'URI: ' '{ print $2 }')
  echo ${CA_URI_BASE}
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
# doesCAHaveCRL - Check if a CA has a Certificate Revocation List (CRL)
# $1 - CA Certificate Path
#==============================================================================
function doesCAHaveCRL {
  local CERT_CA_CERT_PATH=${1}
  local CA_CRL_CHECK=$(openssl x509 -text -in ${CERT_CA_CERT_PATH} |grep -A4 'CRL Distribution Points' | tail -n1 | sed 's/URI://g' | sed 's/ //g')

  if [ ! -z "${CA_CRL_CHECK}" ]; then
    echo "true"
  else
    echo "false"
  fi
}

#==============================================================================
# processPasswordParam - Process the password parameter for a CA
# $1 - Password
#==============================================================================
function processPasswordParam {
  local CA_PASS=${1}
  local DIRECTION=${2:-"in"}
  local PASS_PARAM=""

  if [ ! -z "${CA_PASS}" ]; then
    if [ -f "${CA_PASS}" ]; then
      PASS_PARAM="-pass${DIRECTION} file:${CA_PASS}"
    else
      PASS_PARAM="-pass${DIRECTION} pass:${CA_PASS}"
    fi
  fi

  echo ${PASS_PARAM}
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
  local INTERMEDIATE=$(sed 's|/intermediate-ca/| > |g' <<< ${ROOT})
  local SIGNING=$(sed 's|/signing-ca/| > |' <<< ${INTERMEDIATE})
  echo $SIGNING
}

#======================================================================================================================================
# Common PKI Functions
#======================================================================================================================================

#==============================================================================
# generatePrivateKey - Generate a private key at a given path
# $1 - Key Path
# $2 - Type (default: "") [Certificate, Root CA, Intermediate CA, Signing CA]
# $3 - Password (default: "")
# $4 - Bit Length (default: 4096)
#==============================================================================
function generatePrivateKey {
  local KEY_PATH=${1}
  local TYPE=${2:-""}
  local PASSWORD=${3:-""}
  local BIT_LENGTH=${4:-4096}
  local PW_FILE=$(mktemp)
  local PASSWD_PARAMS=$(processPasswordParam ${PASSWORD} "out")

  if [ ! -f ${KEY_PATH} ]; then
    echo "- Generating private key..."
    if [ "${TYPE}" == "Certificate" ] && [ "false" == "${PIKA_PKI_CERT_KEY_ENCRYPTION}" ]; then
      openssl genrsa -out ${KEY_PATH} ${BIT_LENGTH}
    else
      #local KEY_PASS=$(gum input --password --prompt "Enter a password for the ${TYPE} private key: ")
      #echo ${KEY_PASS} > ${PW_FILE}
      #openssl genrsa -aes256 -passout file:${PW_FILE} -out ${KEY_PATH} ${BIT_LENGTH}
      if [ -z "${PASSWORD}" ]; then
        openssl genrsa -aes256 -out ${KEY_PATH} ${BIT_LENGTH}
      else
        openssl genrsa -aes256 ${PASSWD_PARAMS} -out ${KEY_PATH} ${BIT_LENGTH}
      fi
      #rm -f ${PW_FILE}
    fi
    chmod 400 ${KEY_PATH}
  else
    echo "- Private key already exists: ${1}"
  fi
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
# createCRLFile - Create a Certificate Revocation List (CRL) for a CA
# $1 - CA base Directory
#==============================================================================
function createCRLFile {
  local CA_DIR=${1}
  local CA_PASS=${2}
  local PASSWD_PARAMS=$(processPasswordParam ${CA_PASS})

  #if [ ! -f ${CA_DIR}/crl/ca.crl.pem ]; then
    echo "- Creating Certificate Revocation List..."
    openssl ca -config ${CA_DIR}/openssl.cnf -batch ${PASSWD_PARAMS} -gencrl -out ${CA_DIR}/crl/ca.crl.pem
  #else
    #echo "- CRL already exists: ${CA_DIR}/crl/ca.crl.pem"
  #fi
  copyCAPublicBundles ${CA_DIR}
}

#======================================================================================================================================
# Menus
#======================================================================================================================================

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
        selectRootCAScreen
      else
        selectCAActions $(getCAParentPath ${ACTIVE_CA_PATH})
      fi
      ;;
    "[+] Certificates"*)
      selectCertificateScreen ${ACTIVE_CA_PATH}
      ;;
    "[+] Intermediate CAs"*)
      selectIntermediateCAScreen ${ACTIVE_CA_PATH}
      ;;
    "[+] Signing CAs"*)
      selectSigningCAScreen ${ACTIVE_CA_PATH}
      ;;
    *)
      echo "Invalid selection, exiting"
      exit 1
      ;;
  esac
}

#==============================================================================
# selectCertificateScreen displays a list of certificates for a CA and allows the user to select one for further actions.
# $1 - CA Path
#==============================================================================
function selectCertificateScreen {
  local CA_PATH=${1}
  local CA_TYPE=$(getCAType ${CA_PATH})
  local CERT_OPTIONS='../ Back'
  local CERTIFICATES=$(find ${CA_PATH}/certs/ -maxdepth 1 -type f -name '*.cert.pem' -printf '%p\n' | grep -ve "^${CA_PATH}/certs/ca.cert.pem$" | sed '/^$/d' | sed 's|'${CA_PATH}'/certs/||g' | sed 's|.cert.pem||g')
  if [ ! -z "${CERTIFICATES}" ]; then
    CERT_OPTIONS=''${CERT_OPTIONS}'\n'${CERTIFICATES}''
  fi
  CERT_OPTIONS+='\n[+] Create a new Certificate'

  clear
  #echoBanner "[${CA_TYPE}] $(getBannerPath "${CA_PATH}") - Certificate Selection"
  #echoBanner "[${CA_TYPE}] $(getCertificateCommonName ${ACTIVE_CA_PATH}/certs/ca.cert.pem) - Certificate Selection"
  echoBanner "[${CA_TYPE}] $(getCertificateCommonName ${CA_PATH}/certs/ca.cert.pem) - Certificate Selection"
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
      createNewCertificateTypeScreen ${CA_PATH}
      ;;
    *)
      clear
      viewCertificate "${CA_PATH}/certs/${SELECTED_ACTION}.cert.pem"
      ;;
  esac

}

#======================================================================================================================================
# Process Functions
#======================================================================================================================================

#==============================================================================
# processCAChainPublicBundles takes in a CA directory and copies the public bundles to the public_bundles directories and any sub-CAs
# $1 - CA Directory
#==============================================================================
function processCAChainPublicBundles {
  local CA_DIR=${1}
  local CA_CERT=${CA_DIR}/certs/ca.cert.pem
  if [ "$(isCertificateAuthority ${CA_CERT})" == "false" ]; then
    return
  fi

  copyCAPublicBundles ${CA_DIR}

  # Check if there are any folders in the intermediate-ca or signing-ca directories
  if [ -d "${CA_DIR}/intermediate-ca" ]; then
    local INTERMEDIATE_CA_DIR_COUNT=$(ls -1 ${CA_DIR}/intermediate-ca/ | wc -l)
    if [ ${INTERMEDIATE_CA_DIR_COUNT} -gt 0 ]; then
      for INTERMEDIATE_CA_DIR in $(find ${CA_DIR}/intermediate-ca/ -maxdepth 1 -type d -printf '%p\n' | grep -ve "^${CA_DIR}/intermediate-ca/$"); do
        processCAChainPublicBundles ${INTERMEDIATE_CA_DIR}
      done
    fi
  fi
  if [ -d "${CA_DIR}/signing-ca" ]; then
    local SIGNING_CA_DIR_COUNT=$(ls -1 ${CA_DIR}/signing-ca/ | wc -l)
    if [ ${SIGNING_CA_DIR_COUNT} -gt 0 ]; then
      for SIGNING_CA_DIR in $(find ${CA_DIR}/signing-ca/ -maxdepth 1 -type d -printf '%p\n' | grep -ve "^${CA_DIR}/signing-ca/$"); do
        processCAChainPublicBundles ${SIGNING_CA_DIR}
      done
    fi
  fi
}

#==============================================================================
# copyCAPublicBundles - Copy the public bundles for a given CA to the public_bundles directories
# $1 - CA Directory
#==============================================================================
function copyCAPublicBundles {
  local CA_DIR=${1}
  local CA_CERT=${CA_DIR}/certs/ca.cert.pem
  local FRIENDLY_CA_DIR=${CA_DIR//"$PIKA_PKI_DIR"/}

  echo -e "- Copying Public Bundles for CA in ${FRIENDLY_CA_DIR}"

  local CA_CN=$(getCertificateCommonName ${CA_CERT})
  local CA_SLUG=$(slugify "${CA_CN}")
  local CA_TYPE=$(getCAType ${CA_DIR})

  # Determine CA Type
  case "${CA_TYPE}" in
    "Root")
      local CA_CERT_FILENAME="root-ca.${CA_SLUG}.${CERT_PEM_FILE_EXTENSION}"
      local CA_CRL_FILENAME="root-ca.${CA_SLUG}.crl"
      local CA_DER_FILENAME="root-ca.${CA_SLUG}.${CERT_DER_FILE_EXTENSION}"
      ;;
    "Intermediate")
      local CA_CERT_FILENAME="intermediate-ca.${CA_SLUG}.${CERT_PEM_FILE_EXTENSION}"
      local CA_CRL_FILENAME="intermediate-ca.${CA_SLUG}.crl"
      local CA_DER_FILENAME="intermediate-ca.${CA_SLUG}.${CERT_DER_FILE_EXTENSION}"
      ;;
    "Signing")
      local CA_CERT_FILENAME="signing-ca.${CA_SLUG}.${CERT_PEM_FILE_EXTENSION}"
      local CA_CRL_FILENAME="signing-ca.${CA_SLUG}.crl"
      local CA_DER_FILENAME="signing-ca.${CA_SLUG}.${CERT_DER_FILE_EXTENSION}"
      ;;
  esac

  # Copy the CA Cert to the public_bundles directory
  cp ${CA_CERT} ${CA_DIR}/public_bundles/certs/${CA_CERT_FILENAME}
  cp ${CA_CERT} ${PIKA_PKI_DIR}/public_bundles/certs/${CA_CERT_FILENAME}
  createCertificateDER ${CA_CERT} ${CA_DIR}/public_bundles/certs/${CA_DER_FILENAME}
  createCertificateDER ${CA_CERT} ${PIKA_PKI_DIR}/public_bundles/certs/${CA_DER_FILENAME}

  # Copy the CRL if it exists
  if [ $(doesCAHaveCRL ${CA_CERT}) == "true" ]; then
    cp ${CA_DIR}/crl/ca.crl.pem ${CA_DIR}/public_bundles/crls/${CA_CRL_FILENAME}
    cp ${CA_DIR}/crl/ca.crl.pem ${PIKA_PKI_DIR}/public_bundles/crls/${CA_CRL_FILENAME}
  fi
  
  # Copy the CA Chain files
  local CA_CHAIN=$(generateCAChain ${CA_CERT})
  local CA_FULL_CHAIN=$(generateCAChain ${CA_CERT} "true")
  if [ ! -z "${CA_CHAIN}" ]; then
    if [ "$(echo -e "${CA_CHAIN}" | tail -n +2)" != "$(cat ${CA_CERT})" ]; then
      echo -e "${CA_CHAIN}" > ${CA_DIR}/public_bundles/certs/${CA_CERT_FILENAME}.chain.pem
      echo -e "${CA_CHAIN}" > ${PIKA_PKI_DIR}/public_bundles/certs/${CA_CERT_FILENAME}.chain.pem
    fi
  fi
  if [ ! -z "${CA_FULL_CHAIN}" ]; then
    if [ "$(echo -e "${CA_FULL_CHAIN}" | tail -n +2)" != "$(cat ${CA_CERT})" ]; then
      echo -e "${CA_FULL_CHAIN}" > ${CA_DIR}/public_bundles/certs/${CA_CERT_FILENAME}.full-chain.pem
      echo -e "${CA_FULL_CHAIN}" > ${PIKA_PKI_DIR}/public_bundles/certs/${CA_CERT_FILENAME}.full-chain.pem
    fi
  fi

}

#==============================================================================
# createCertificateDER - Create a DER formatted certificate from a PEM formatted certificate
# $1 - Certificate Path
# $2 - DER Path
#==============================================================================
function createCertificateDER {
  local CERT_PATH=${1}
  local DER_PATH=${2}
  openssl x509 -outform der -in ${CERT_PATH} -out ${DER_PATH}
}