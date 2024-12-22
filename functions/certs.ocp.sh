#!/bin/bash

#=======================================================================================================
# OpenShift Certificate Functions
#=======================================================================================================

shopt -s extglob;

source ${SCRIPT_DIR}/functions/formatting.sh
source ${SCRIPT_DIR}/functions/common.sh

#=======================================================================================================
# createOpenshiftAPICertificateInputScreen - Create an OpenShift API certificate with a given cluster base domain
# $1 - Parent CA Path
#=======================================================================================================
function createOpenshiftAPICertificateInputScreen {
  # Input variable assignments and inheritance information
  local PARENT_CA_PATH=${1}
  local PARENT_CA_NAME=$(getCertificateCommonName "${PARENT_CA_PATH}/certs/ca.cert.pem")
  local PARENT_CA_TYPE=$(getCAType ${PARENT_CA_PATH})

  # Header
  clear
  echoBanner "[${PARENT_CA_TYPE}] ${PARENT_CA_NAME} - OpenShift API Certificate Creation"
  echo "===== CA Path: $(getPKIPath ${PARENT_CA_PATH})"

  # Input prompts
  local SERVER_CERT_OCP_CLUSTER_BASE_DOMAIN=$(promptNewServerCertificateOCPDomain)
  local SERVER_CERT_NAME="api.${SERVER_CERT_OCP_CLUSTER_BASE_DOMAIN}"
  local SERVER_CERT_DNS_SAN="api-int.${SERVER_CERT_OCP_CLUSTER_BASE_DOMAIN}"
  local SERVER_CERT_COUNTRY_CODE=$(promptNewServerCertificateCountryCode)
  local SERVER_CERT_STATE=$(promptNewServerCertificateState)
  local SERVER_CERT_LOCALITY=$(promptNewServerCertificateLocality)
  local SERVER_CERT_ORGANIZATION=$(promptNewServerCertificateOrganization)
  local SERVER_CERT_ORGANIZATIONAL_UNIT=$(promptNewServerCertificateOrganizationalUnit)
  local SERVER_CERT_EMAIL=$(promptNewServerCertificateEmail)

  # Filename in this instance can just be the SERVER_CERT_NAME
  local SAFE_SERVER_CERT_NAME=${SERVER_CERT_NAME}

  # Format the default DNS SANs
  local SERVER_DNS_SANS_FRIENDLY="DNS:${SERVER_CERT_NAME} (Automatically added)"
  local SERVER_DNS_SANS_FORMATTED="DNS:${SERVER_CERT_NAME}"

  # Append any additional DNS SANs
  if [ ! -z "${SERVER_CERT_DNS_SAN}" ]; then
    local SERVER_DNS_SANS=$(echo ${SERVER_CERT_DNS_SAN} | sed 's/,/,DNS:/g')
    SERVER_DNS_SANS_FRIENDLY="${SERVER_DNS_SANS_FRIENDLY},DNS:${SERVER_DNS_SANS}"
    SERVER_DNS_SANS_FORMATTED="${SERVER_DNS_SANS_FORMATTED},DNS:${SERVER_DNS_SANS}"
  fi

  # Format the DNS SANs for display
  local SERVER_DNS_SANS_NL="$(echo ${SERVER_DNS_SANS_FRIENDLY} | sed 's/,/\n/g' | sed 's/DNS:/  - /g')"

  # Display the certificate information
  echo -e "- $(bld 'Common Name:') ${SERVER_CERT_NAME}\n- $(bld Country Code:) ${SERVER_CERT_COUNTRY_CODE}\n- $(bld State:) ${SERVER_CERT_STATE}\n- $(bld Locality:) ${SERVER_CERT_LOCALITY}\n- $(bld Organization:) ${SERVER_CERT_ORGANIZATION}\n- $(bld Organizational Unit:) ${SERVER_CERT_ORGANIZATIONAL_UNIT}\n- $(bld Email:) ${SERVER_CERT_EMAIL}"
  echo -e "- $(bld 'DNS SANs:')\n${SERVER_DNS_SANS_NL}"

  if gum confirm; then
    # Set the certificate component paths
    local SERVER_KEY_PATH="${PARENT_CA_PATH}/private/${SAFE_SERVER_CERT_NAME}.key.pem"
    local SERVER_CSR_PATH="${PARENT_CA_PATH}/csr/${SAFE_SERVER_CERT_NAME}.csr.pem"
    local SERVER_CERT_PATH="${PARENT_CA_PATH}/certs/${SAFE_SERVER_CERT_NAME}.cert.pem"
    
    # Make sure the certificate name is unique
    if [ -f "${SERVER_CERT_PATH}" ] || [ -f "${SERVER_KEY_PATH}" ] || [ -f "${SERVER_CSR_PATH}" ]; then
      echo "Certificate with name '${SAFE_SERVER_CERT_NAME}' already exists.  Exiting..."
      if [ -f "${SERVER_CERT_PATH}" ]; then echo "- Certificate Path: ${SERVER_CERT_PATH}"; fi
      if [ -f "${SERVER_CSR_PATH}" ]; then echo "- CSR Path: ${SERVER_CSR_PATH}"; fi
      if [ -f "${SERVER_KEY_PATH}" ]; then echo "- Key Path: ${SERVER_KEY_PATH}"; fi
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
        -addext 'subjectAltName = '${SERVER_DNS_SANS_FORMATTED}'' \
        -subj "/emailAddress=${SERVER_CERT_EMAIL}/C=${SERVER_CERT_COUNTRY_CODE}/ST=${SERVER_CERT_STATE}/L=${SERVER_CERT_LOCALITY}/O=${SERVER_CERT_ORGANIZATION}/OU=${SERVER_CERT_ORGANIZATIONAL_UNIT}/CN=${SERVER_CERT_NAME}"
    else
      echo "- CSR already exists: ${SERVER_CSR_PATH}"
    fi

    # Generate a server certificate if it does not exist, in either case, display the certificate actions
    if [ ! -f "${SERVER_CERT_PATH}" ]; then
      echo "- Signing CSR with Certificate Authority..."

      # Prompt for the signing CA's password, save it to a temporary file
      local SIGNING_CA_CERT_PASS=$(gum input --password --prompt "Enter a password for the Signing CA Certificate private key: ")
      local PW_FILE=$(mktemp)
      echo ${SIGNING_CA_CERT_PASS} > ${PW_FILE}

      # Create the certificate
      openssl ca -config ${PARENT_CA_PATH}/openssl.cnf \
        -extensions server_cert -days 375 -notext -md sha256 \
        -passin file:${PW_FILE} \
        -batch -in ${SERVER_CSR_PATH} \
        -out ${SERVER_CERT_PATH}

      # Clean up the password file
      rm -f ${PW_FILE}
    else
      echo "- Certificate already exists: ${SERVER_CERT_PATH}"
    fi
    # Display the certificate
    viewCertificate ${SERVER_CERT_PATH}
  else
    # User has decided not to create the certificate - return to the CA action selection screen
    selectCAActions "${PARENT_CA_PATH}"
  fi

}

#=======================================================================================================
# createOpenshiftRouterCertificateInputScreen - Create an OpenShift Router certificate with a given cluster base domain
# $1 - Parent CA Path
#=======================================================================================================
function createOpenshiftIngressCertificateInputScreen {
  # Input variable assignments and inheritance information
  local PARENT_CA_PATH=${1}
  local PARENT_CA_NAME=$(getCertificateCommonName "${PARENT_CA_PATH}/certs/ca.cert.pem")
  local PARENT_CA_TYPE=$(getCAType ${PARENT_CA_PATH})

  # Header
  clear
  echoBanner "[${PARENT_CA_TYPE}] ${PARENT_CA_NAME} - OpenShift Ingress Certificate Creation"
  echo "===== CA Path: $(getPKIPath ${PARENT_CA_PATH})"

  # Input prompts
  local SERVER_CERT_OCP_CLUSTER_BASE_DOMAIN=$(promptNewServerCertificateOCPDomain)
  local SERVER_CERT_NAME="*.apps.${SERVER_CERT_OCP_CLUSTER_BASE_DOMAIN}"
  local SERVER_CERT_DNS_SAN=$(promptNewServerCertificateDNSSAN)
  local SERVER_CERT_COUNTRY_CODE=$(promptNewServerCertificateCountryCode)
  local SERVER_CERT_STATE=$(promptNewServerCertificateState)
  local SERVER_CERT_LOCALITY=$(promptNewServerCertificateLocality)
  local SERVER_CERT_ORGANIZATION=$(promptNewServerCertificateOrganization)
  local SERVER_CERT_ORGANIZATIONAL_UNIT=$(promptNewServerCertificateOrganizationalUnit)
  local SERVER_CERT_EMAIL=$(promptNewServerCertificateEmail)

  # Filename in this instance should be the ingress endpoint but with an asterisk replaced with "wildcard"
  local SAFE_SERVER_CERT_NAME=$(echo "${SERVER_CERT_NAME}" | sed 's/*/wildcard/')

  # Format the default DNS SANs
  local SERVER_DNS_SANS_FRIENDLY="DNS:${SAFE_SERVER_CERT_NAME} (Automatically added)"
  local SERVER_DNS_SANS_FORMATTED="DNS:${SERVER_CERT_NAME}"

  # Append any additional DNS SANs
  if [ ! -z "${SERVER_CERT_DNS_SAN}" ]; then
    local SERVER_DNS_SANS=$(echo ${SERVER_CERT_DNS_SAN} | sed 's/,/,DNS:/g')
    SERVER_DNS_SANS_FRIENDLY="${SERVER_DNS_SANS_FRIENDLY},DNS:${SERVER_DNS_SANS}"
    SERVER_DNS_SANS_FORMATTED="${SERVER_DNS_SANS_FORMATTED},DNS:${SERVER_DNS_SANS}"
  fi

  # Format the DNS SANs for display
  local SERVER_DNS_SANS_NL="$(echo ${SERVER_DNS_SANS_FRIENDLY} | sed 's/,/\n/g' | sed 's/DNS:/  - /g')"

  # Display the certificate information
  echo -e "- $(bld 'Common Name:') ${SERVER_CERT_NAME}\n- $(bld Country Code:) ${SERVER_CERT_COUNTRY_CODE}\n- $(bld State:) ${SERVER_CERT_STATE}\n- $(bld Locality:) ${SERVER_CERT_LOCALITY}\n- $(bld Organization:) ${SERVER_CERT_ORGANIZATION}\n- $(bld Organizational Unit:) ${SERVER_CERT_ORGANIZATIONAL_UNIT}\n- $(bld Email:) ${SERVER_CERT_EMAIL}"
  echo -e "- $(bld 'DNS SANs:')\n${SERVER_DNS_SANS_NL}"

  if gum confirm; then
    # Set the certificate component paths
    local SERVER_KEY_PATH="${PARENT_CA_PATH}/private/${SAFE_SERVER_CERT_NAME}.key.pem"
    local SERVER_CSR_PATH="${PARENT_CA_PATH}/csr/${SAFE_SERVER_CERT_NAME}.csr.pem"
    local SERVER_CERT_PATH="${PARENT_CA_PATH}/certs/${SAFE_SERVER_CERT_NAME}.cert.pem"
    
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
        -addext 'subjectAltName = '${SERVER_DNS_SANS_FORMATTED}'' \
        -subj "/emailAddress=${SERVER_CERT_EMAIL}/C=${SERVER_CERT_COUNTRY_CODE}/ST=${SERVER_CERT_STATE}/L=${SERVER_CERT_LOCALITY}/O=${SERVER_CERT_ORGANIZATION}/OU=${SERVER_CERT_ORGANIZATIONAL_UNIT}/CN=${SERVER_CERT_NAME}"
    else
      echo "- CSR already exists: ${SERVER_CSR_PATH}"
    fi

    # Generate a server certificate if it does not exist, in either case, display the certificate actions
    if [ ! -f "${SERVER_CERT_PATH}" ]; then
      echo "- Signing CSR with Certificate Authority..."

      # Prompt for the signing CA's password, save it to a temporary file
      local SIGNING_CA_CERT_PASS=$(gum input --password --prompt "Enter a password for the Signing CA Certificate private key: ")
      local PW_FILE=$(mktemp)
      echo ${SIGNING_CA_CERT_PASS} > ${PW_FILE}

      # Create the certificate
      openssl ca -config ${PARENT_CA_PATH}/openssl.cnf \
        -extensions server_cert -days 375 -notext -md sha256 \
        -passin file:${PW_FILE} \
        -batch -in ${SERVER_CSR_PATH} \
        -out ${SERVER_CERT_PATH}

      # Clean up the password file
      rm -f ${PW_FILE}
    else
      echo "- Certificate already exists: ${SERVER_CERT_PATH}"
    fi
    # Display the certificate
    viewCertificate ${SERVER_CERT_PATH}
  else
    # User has decided not to create the certificate - return to the CA action selection screen
    selectCAActions "${PARENT_CA_PATH}"
  fi
}

#=======================================================================================================
# createOpenshiftComboCertificate - Create an OpenShift Combo certificate (both API and Ingress) with a given cluster base domain
# $1 - Parent CA Path
#=======================================================================================================
function createOpenshiftComboCertificateInputScreen {
  # Input variable assignments and inheritance information
  local PARENT_CA_PATH=${1}
  local PARENT_CA_NAME=$(getCertificateCommonName "${PARENT_CA_PATH}/certs/ca.cert.pem")
  local PARENT_CA_TYPE=$(getCAType ${PARENT_CA_PATH})

  # Header
  clear
  echoBanner "[${PARENT_CA_TYPE}] ${PARENT_CA_NAME} - OpenShift Combo Certificate Creation"
  echo "===== CA Path: $(getPKIPath ${PARENT_CA_PATH})"

  # Input prompts
  local SERVER_CERT_OCP_CLUSTER_BASE_DOMAIN=$(promptNewServerCertificateOCPDomain)
  local SERVER_CERT_NAME="api.${SERVER_CERT_OCP_CLUSTER_BASE_DOMAIN}"
  local SERVER_CERT_DNS_SAN=$(promptNewServerCertificateDNSSAN)
  local SERVER_CERT_COUNTRY_CODE=$(promptNewServerCertificateCountryCode)
  local SERVER_CERT_STATE=$(promptNewServerCertificateState)
  local SERVER_CERT_LOCALITY=$(promptNewServerCertificateLocality)
  local SERVER_CERT_ORGANIZATION=$(promptNewServerCertificateOrganization)
  local SERVER_CERT_ORGANIZATIONAL_UNIT=$(promptNewServerCertificateOrganizationalUnit)
  local SERVER_CERT_EMAIL=$(promptNewServerCertificateEmail)

  # Filename in this instance should be for the whole cluster
  local SAFE_SERVER_CERT_NAME="combo-${SERVER_CERT_OCP_CLUSTER_BASE_DOMAIN}"

  # Format the default DNS SANs
  local SERVER_DNS_SANS_FORMATTED="DNS:${SERVER_CERT_NAME},DNS:api-int.${SERVER_CERT_OCP_CLUSTER_BASE_DOMAIN},DNS:*.apps.${SERVER_CERT_OCP_CLUSTER_BASE_DOMAIN}"
  local SERVER_DNS_SANS_FRIENDLY="DNS:${SERVER_CERT_NAME} (Automatically added)\nDNS:api-int.${SERVER_CERT_OCP_CLUSTER_BASE_DOMAIN} (Automatically added)\nDNS:*.apps.${SERVER_CERT_OCP_CLUSTER_BASE_DOMAIN} (Automatically added)"
  
  # Append any additional DNS SANs
  if [ ! -z "${SERVER_CERT_DNS_SAN}" ]; then
    local SERVER_DNS_SANS=$(echo ${SERVER_CERT_DNS_SAN} | sed 's/,/,DNS:/g')
    SERVER_DNS_SANS_FRIENDLY="${SERVER_DNS_SANS_FRIENDLY},DNS:${SERVER_DNS_SANS}"
    SERVER_DNS_SANS_FORMATTED="${SERVER_DNS_SANS_FORMATTED},DNS:${SERVER_DNS_SANS}"
  fi

  # Format the DNS SANs for display
  local SERVER_DNS_SANS_NL="$(echo ${SERVER_DNS_SANS_FRIENDLY} | sed 's/,/\n/g' | sed 's/DNS:/  - /g')"

  # Display the certificate information
  echo -e "- $(bld 'Common Name:') ${SERVER_CERT_NAME}\n- $(bld Country Code:) ${SERVER_CERT_COUNTRY_CODE}\n- $(bld State:) ${SERVER_CERT_STATE}\n- $(bld Locality:) ${SERVER_CERT_LOCALITY}\n- $(bld Organization:) ${SERVER_CERT_ORGANIZATION}\n- $(bld Organizational Unit:) ${SERVER_CERT_ORGANIZATIONAL_UNIT}\n- $(bld Email:) ${SERVER_CERT_EMAIL}"
  echo -e "- $(bld 'DNS SANs:')\n${SERVER_DNS_SANS_NL}"

  if gum confirm; then
    # Set the certificate component paths
    local SERVER_KEY_PATH="${PARENT_CA_PATH}/private/${SAFE_SERVER_CERT_NAME}.key.pem"
    local SERVER_CSR_PATH="${PARENT_CA_PATH}/csr/${SAFE_SERVER_CERT_NAME}.csr.pem"
    local SERVER_CERT_PATH="${PARENT_CA_PATH}/certs/${SAFE_SERVER_CERT_NAME}.cert.pem"
    
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
        -addext 'subjectAltName = '${SERVER_DNS_SANS_FORMATTED}'' \
        -subj "/emailAddress=${SERVER_CERT_EMAIL}/C=${SERVER_CERT_COUNTRY_CODE}/ST=${SERVER_CERT_STATE}/L=${SERVER_CERT_LOCALITY}/O=${SERVER_CERT_ORGANIZATION}/OU=${SERVER_CERT_ORGANIZATIONAL_UNIT}/CN=${SERVER_CERT_NAME}"
    else
      echo "- CSR already exists: ${SERVER_CSR_PATH}"
    fi

    # Generate a server certificate if it does not exist, in either case, display the certificate actions
    if [ ! -f "${SERVER_CERT_PATH}" ]; then
      echo "- Signing CSR with Certificate Authority..."

      # Prompt for the signing CA's password, save it to a temporary file
      local SIGNING_CA_CERT_PASS=$(gum input --password --prompt "Enter a password for the Signing CA Certificate private key: ")
      local PW_FILE=$(mktemp)
      echo ${SIGNING_CA_CERT_PASS} > ${PW_FILE}

      # Create the certificate
      openssl ca -config ${PARENT_CA_PATH}/openssl.cnf \
        -extensions server_cert -days 375 -notext -md sha256 \
        -passin file:${PW_FILE} \
        -batch -in ${SERVER_CSR_PATH} \
        -out ${SERVER_CERT_PATH}

      # Clean up the password file
      rm -f ${PW_FILE}
    else
      echo "- Certificate already exists: ${SERVER_CERT_PATH}"
    fi
    # Display the certificate
    viewCertificate ${SERVER_CERT_PATH}
  else
    # User has decided not to create the certificate - return to the CA action selection screen
    selectCAActions "${PARENT_CA_PATH}"
  fi
}
