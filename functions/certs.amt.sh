#!/bin/bash

#=======================================================================================================
# Intel AMT/vPro Certificate Functions
#=======================================================================================================

shopt -s extglob;

source ${SCRIPT_DIR}/functions/formatting.sh
source ${SCRIPT_DIR}/functions/common.sh

#=======================================================================================================
# createIntelAMTCertificateInputScreen - Create an Intel AMT certificate
# $1 - Parent CA Path
#=======================================================================================================
function createIntelAMTCertificateInputScreen {
  # Input variable assignments and inheritance information
  local PARENT_CA_PATH=${1}
  local PARENT_CA_NAME=$(getCertificateCommonName "${PARENT_CA_PATH}/certs/ca.cert.pem")
  local PARENT_CA_TYPE=$(getCAType ${PARENT_CA_PATH})

  # Header
  clear
  echoBanner "[${PARENT_CA_TYPE}] ${PARENT_CA_NAME} - Intel AMT/vPro Certificate Creation"
  echo "===== CA Path: $(getPKIPath ${PARENT_CA_PATH})"

  # Input prompts
  local AMT_CERT_DOMAIN=$(promptNewServerCertificateAMTDomain)
  local AMT_CERT_DNS_SAN=$(promptNewServerCertificateDNSSAN)
  local AMT_CERT_IP_SAN=$(promptNewServerCertificateIPSAN)
  local AMT_CERT_COUNTRY_CODE=$(promptNewServerCertificateCountryCode)
  local AMT_CERT_STATE=$(promptNewServerCertificateState)
  local AMT_CERT_LOCALITY=$(promptNewServerCertificateLocality)
  local AMT_CERT_ORGANIZATION=$(promptNewServerCertificateOrganization)
  local AMT_CERT_ORGANIZATIONAL_UNIT="Intel(R) Client Setup Certificate"
  local AMT_CERT_EMAIL=$(promptNewServerCertificateEmail)

  # Format the default DNS SANs
  local AMT_DNS_SANS_FRIENDLY="DNS:${AMT_CERT_NAME} (Automatically added)"
  local AMT_DNS_SANS_FORMATTED="DNS:${AMT_CERT_NAME}"
  local AMT_COMPILED_SANS="DNS:${AMT_CERT_NAME}"

  # Set the certificate name and path
  local AMT_CERT_FILENAME="$(echo "${AMT_CERT_NAME}" | sed 's/*/wildcard/')"
  local AMT_CERT_PATH="${PARENT_CA_PATH}/certs/${AMT_CERT_FILENAME}.cert.pem"

  # Append any additional IP SANs
  if [ ! -z "${AMT_CERT_IP_SAN}" ]; then
    local AMT_IP_SANS=$(echo "$(stripLastCommas ${AMT_CERT_IP_SAN})" | sed 's/,/,IP:/g')
    local AMT_IP_SANS_NL="$(echo ${AMT_IP_SANS} | sed 's/,/\n/g' | sed 's/IP:/  - /g')"
    AMT_COMPILED_SANS="${AMT_COMPILED_SANS},${AMT_IP_SANS}"
  fi

  # Append any additional DNS SANs
  if [ ! -z "${AMT_CERT_DNS_SAN}" ]; then
    local AMT_DNS_SANS=$(echo ${AMT_CERT_DNS_SAN} | sed 's/,/,DNS:/g')
    AMT_DNS_SANS_FRIENDLY="${AMT_DNS_SANS_FRIENDLY},DNS:${AMT_DNS_SANS}"
    AMT_DNS_SANS_FORMATTED="${AMT_DNS_SANS_FORMATTED},DNS:${AMT_DNS_SANS}"
    AMT_COMPILED_SANS="${AMT_COMPILED_SANS},DNS:${AMT_DNS_SANS}"
  fi

  AMT_COMPILED_SANS_NL="$(echo ${AMT_COMPILED_SANS} | sed 's/,/\n/g' | sed 's/DNS:/  - /g' | sed 's/IP:/  - /g')"

  # Display the certificate information
  echo -e "- $(bld 'Common Name:') ${AMT_CERT_NAME}\n- $(bld Country Code:) ${AMT_CERT_COUNTRY_CODE}\n- $(bld State:) ${AMT_CERT_STATE}\n- $(bld Locality:) ${AMT_CERT_LOCALITY}\n- $(bld Organization:) ${AMT_CERT_ORGANIZATION}\n- $(bld Organizational Unit, automatically set:) ${AMT_CERT_ORGANIZATIONAL_UNIT}\n- $(bld Email:) ${AMT_CERT_EMAIL}"
  echo -e "- $(bld 'SANs:')\n${AMT_COMPILED_SANS_NL}"

  if gum confirm; then
    # Prompt for the signing CA's password, save it to a temporary file
    local SIGNING_CA_CERT_PASS=$(gum input --password --prompt "Enter a password for the Signing CA \"${PARENT_CA_NAME}\" Certificate private key: ")
    local PW_FILE=$(mktemp)
    echo ${SIGNING_CA_CERT_PASS} > ${PW_FILE}

    # Create the certificate
    createAMTCertificate "${PARENT_CA_PATH}" \
      "${PW_FILE}" \
      "${AMT_CERT_NAME}" \
      "${AMT_CERT_FILENAME}" \
      "${AMT_CERT_COUNTRY_CODE}" \
      "${AMT_CERT_STATE}" \
      "${AMT_CERT_LOCALITY}" \
      "${AMT_CERT_ORGANIZATION}" \
      "${AMT_CERT_ORGANIZATIONAL_UNIT}" \
      "${AMT_CERT_EMAIL}" \
      "${AMT_COMPILED_SANS}"

    # Clean up the password file
    rm -f ${PW_FILE}

    # Display the certificate
    viewCertificate ${AMT_CERT_PATH}
  else
    # User has decided not to create the certificate - return to the CA action selection screen
    selectCAActions "${PARENT_CA_PATH}"
  fi
}

function createAMTCertificate {
  # Input variable assignments and inheritance information
  local PARENT_CA_PATH=${1}
  local PARENT_CA_NAME=$(getCertificateCommonName "${PARENT_CA_PATH}/certs/ca.cert.pem")
  local PARENT_CA_TYPE=$(getCAType ${PARENT_CA_PATH})
  local PARENT_CA_PASS=${2}
  local PASSWD_PARAMS=$(processPasswordParam ${PARENT_CA_PASS})

  # Filename in this instance should be for whatever the first CN is but with an asterisk replaced with "wildcard"
  local SERVER_CERT_NAME=${3}
  local SAFE_SERVER_CERT_NAME=$(echo "${SERVER_CERT_NAME}" | sed 's/*/wildcard/')
  local SERVER_CERT_FILENAME=${4:-""}
  if [ -z "${SERVER_CERT_FILENAME}" ]; then
    SERVER_CERT_FILENAME="${SAFE_SERVER_CERT_NAME}"
  fi

  local SERVER_CERT_COUNTRY_CODE=${5}
  local SERVER_CERT_STATE=${6}
  local SERVER_CERT_LOCALITY=${7}
  local SERVER_CERT_ORGANIZATION=${8}
  local SERVER_CERT_ORGANIZATIONAL_UNIT=${9}
  local SERVER_CERT_EMAIL=${10}
  local SERVER_SANS_FORMATTED=${11}

  # Set the certificate component paths
  local SERVER_KEY_PATH="${PARENT_CA_PATH}/private/${SERVER_CERT_FILENAME}.key.pem"
  local SERVER_CSR_PATH="${PARENT_CA_PATH}/csr/${SERVER_CERT_FILENAME}.csr.pem"
  local SERVER_CERT_PATH="${PARENT_CA_PATH}/certs/${SERVER_CERT_FILENAME}.cert.pem"
  
  # Make sure the certificate name is unique
  if [ -f "${SERVER_CERT_PATH}" ] || [ -f "${SERVER_KEY_PATH}" ] || [ -f "${SERVER_CSR_PATH}" ]; then
    echo "Certificate components with name '${SERVER_CERT_NAME}' already exists.  Exiting..."
    if [ -f "${SERVER_KEY_PATH}" ]; then echo "- Key Path: ${SERVER_KEY_PATH}"; fi
    if [ -f "${SERVER_CSR_PATH}" ]; then echo "- CSR Path: ${SERVER_CSR_PATH}"; fi
    if [ -f "${SERVER_CERT_PATH}" ]; then echo "- Certificate Path: ${SERVER_CERT_PATH}"; fi
    exit 1
  fi

  # Generate the RSA Private Key
  generatePrivateKey "${SERVER_KEY_PATH}" "Certificate"

  # Generate a Certificate Signing Request (CSR) if it does not already exist
  if [ ! -f "${SERVER_CSR_PATH}" ]; then
    echo -e "- Creating Certificate Signing Request (CSR)..."

    # Generate the CSR
    openssl req -new -sha256 \
      -config ${PARENT_CA_PATH}/openssl.cnf \
      -key ${SERVER_KEY_PATH} \
      -out ${SERVER_CSR_PATH} \
      -addext 'subjectAltName = '${SERVER_SANS_FORMATTED}'' \
      -subj "/emailAddress=${SERVER_CERT_EMAIL}/C=${SERVER_CERT_COUNTRY_CODE}/ST=${SERVER_CERT_STATE}/L=${SERVER_CERT_LOCALITY}/O=${SERVER_CERT_ORGANIZATION}/OU=${SERVER_CERT_ORGANIZATIONAL_UNIT}/CN=${SERVER_CERT_NAME}"
  else
    echo "- CSR already exists: ${SERVER_CSR_PATH}"
  fi

  # Generate a server certificate if it does not exist, in either case, display the certificate actions
  if [ ! -f "${SERVER_CERT_PATH}" ]; then
    echo "- Signing CSR with Certificate Authority..."

    # Create the certificate
    openssl ca -config ${PARENT_CA_PATH}/openssl.cnf \
      -extensions intel_amt_cert -days 375 -notext -md sha256 \
      ${PASSWD_PARAMS} \
      -batch -in ${SERVER_CSR_PATH} \
      -out ${SERVER_CERT_PATH}

  else
    echo "- Certificate already exists: ${SERVER_CERT_PATH}"
  fi
}