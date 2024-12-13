#!/bin/bash

shopt -s extglob;

source ${SCRIPT_DIR}/functions/formatting.sh
source ${SCRIPT_DIR}/functions/common.sh

function promptNewServerCertificateName {
  local SERVER_CERT_NAME=$(gum input --prompt "* Server Certificate [Common] Name: " --placeholder "server.acme.com")
  if [ -z "$SERVER_CERT_NAME" ]; then
    promptNewServerCertificateName
  else
    echo ${SERVER_CERT_NAME}
  fi
}

function promptNewServerCertificateDNSSAN {
  local SERVER_CERT_DNS_SAN=$(gum input --prompt "[Optional] DNS SAN(s): " --placeholder "*.apps.server.acme.com,api.server.acme.com")
  echo ${SERVER_CERT_DNS_SAN}
}

function promptNewServerCertificateCountryCode {
  local SERVER_CERT_COUNTRY_CODE=$(gum input --prompt "* Country Code: " --placeholder "US" --value "${PIKA_PKI_DEFAULT_COUNTRY}")
  if [ -z "$SERVER_CERT_COUNTRY_CODE" ]; then
    promptNewServerCertificateCountryCode
  else
    echo ${SERVER_CERT_COUNTRY_CODE}
  fi
}

function promptNewServerCertificateState {
  local SERVER_CERT_STATE=$(gum input --prompt "* State: " --placeholder "California" --value "${PIKA_PKI_DEFAULT_STATE}")
  if [ -z "$SERVER_CERT_STATE" ]; then
    promptNewServerCertificateState
  else
    echo ${SERVER_CERT_STATE}
  fi
}

function promptNewServerCertificateLocality {
  local SERVER_CERT_LOCALITY=$(gum input --prompt "* City/Locality: " --placeholder "San Francisco" --value "${PIKA_PKI_DEFAULT_LOCALITY}")
  if [ -z "$SERVER_CERT_LOCALITY" ]; then
    promptNewServerCertificateLocality
  else
    echo ${SERVER_CERT_LOCALITY}
  fi
}

function promptNewServerCertificateOrganization {
  local SERVER_CERT_ORGANIZATION=$(gum input --prompt "* Organization: " --placeholder "ACME Corporation" --value "${PIKA_PKI_DEFAULT_ORG}")
  if [ -z "$SERVER_CERT_ORGANIZATION" ]; then
    promptNewServerCertificateOrganization
  else
    echo ${SERVER_CERT_ORGANIZATION}
  fi
}

function promptNewServerCertificateOrganizationalUnit {
  local SERVER_CERT_ORGANIZATIONAL_UNIT=$(gum input --prompt "* Organizational Unit: " --placeholder "InfoSec" --value "${PIKA_PKI_DEFAULT_OU}")
  if [ -z "$SERVER_CERT_ORGANIZATIONAL_UNIT" ]; then
    promptNewServerCertificateOrganizationalUnit
  else
    echo ${SERVER_CERT_ORGANIZATIONAL_UNIT}
  fi
}

function promptNewServerCertificateEmail {
  local SERVER_CERT_EMAIL=$(gum input --prompt "* Email: " --placeholder "you@acme.com" --value "${PIKA_PKI_DEFAULT_EMAIL}")
  if [ -z "$SERVER_CERT_EMAIL" ]; then
    promptNewServerCertificateEmail
  else
    echo ${SERVER_CERT_EMAIL}
  fi
}

function promptNewServerCertificateOCPDomain {
  local SERVER_CERT_OCP_DOMAIN=$(gum input --prompt "* OpenShift Cluster: " --placeholder "cluster-name.example.com")
  if [ -z "$SERVER_CERT_OCP_DOMAIN" ]; then
    promptNewServerCertificateOCPDomain
  else
    echo ${SERVER_CERT_OCP_DOMAIN}
  fi
}

function createNewCertificate {
  local CA_PATH=${1}
  local CA_CN=$(getCertificateCommonName "${CA_PATH}/certs/ca.cert.pem")
  local CA_TYPE=$(getCAType ${CA_PATH})

  clear
  echoBanner "[${CA_TYPE}] ${CA_CN} - Certificate Creation, Type Selection"
  echo "===== Path: $(getPKIPath ${CA_PATH})"

  echo "- Creating a new certificate..."
  local CERT_OPTIONS='Server Certificate\nClient Certificate\nOpenShift API Certificate\nOpenShift Ingress Certificate'
  local CERT_CHOICE=$(echo -e "$CERT_OPTIONS" | gum choose)
  if [ -z "$CERT_CHOICE" ]; then
    echo "No Certificate Type selected.  Exiting..."
    exit 1
  fi
  
  case $CERT_CHOICE in
    "Server Certificate")
      createServerCertificate "${CA_PATH}"
      ;;
    "Client Certificate")
      echo "Not implemented yet."
      ;;
    "OpenShift API Certificate")
      echo "Not implemented yet."
      ;;
    "OpenShift Ingress Certificate")
      echo "Not implemented yet."
      ;;
    *)
      echo "Invalid selection.  Exiting..."
      exit 1
      ;;
  esac
}

function createServerCertificate {
  local PARENT_CA_PATH=${1}
  local PARENT_CA_NAME=$(getCertificateCommonName "${PARENT_CA_PATH}/certs/ca.cert.pem")
  local PARENT_CA_TYPE=$(getCAType ${PARENT_CA_PATH})

  clear
  echoBanner "[${PARENT_CA_TYPE}] ${PARENT_CA_NAME} - Server Certificate Creation"
  echo "===== Path: $(getPKIPath ${PARENT_CA_PATH})"

  local SERVER_CERT_NAME=$(promptNewServerCertificateName)
  local SERVER_CERT_DNS_SAN=$(promptNewServerCertificateDNSSAN)
  local SERVER_CERT_COUNTRY_CODE=$(promptNewServerCertificateCountryCode)
  local SERVER_CERT_STATE=$(promptNewServerCertificateState)
  local SERVER_CERT_LOCALITY=$(promptNewServerCertificateLocality)
  local SERVER_CERT_ORGANIZATION=$(promptNewServerCertificateOrganization)
  local SERVER_CERT_ORGANIZATIONAL_UNIT=$(promptNewServerCertificateOrganizationalUnit)
  local SERVER_CERT_EMAIL=$(promptNewServerCertificateEmail)

  local SAFE_SERVER_CERT_NAME=$(echo "${SERVER_CERT_NAME}" | tr '*' 'wildcard')
  local SERVER_DNS_SANS_FRIENDLY="DNS:${SERVER_CERT_NAME} (Automatically added)"
  local SERVER_DNS_SANS_FORMATTED="DNS:${SERVER_CERT_NAME}"
  
  if [ ! -z "${SERVER_CERT_DNS_SAN}" ]; then
    local SERVER_DNS_SANS=$(echo ${SERVER_CERT_DNS_SAN} | sed 's/,/,DNS:/g')
    SERVER_DNS_SANS_FRIENDLY="${SERVER_DNS_SANS_FRIENDLY},DNS:${SERVER_DNS_SANS}"
    SERVER_DNS_SANS_FORMATTED="${SERVER_DNS_SANS_FORMATTED},DNS:${SERVER_DNS_SANS}"
  fi
  
  local SERVER_DNS_SANS_NL="$(echo ${SERVER_DNS_SANS_FRIENDLY} | sed 's/,/\n/g' | sed 's/DNS:/  - /g')"

  echo -e "- $(bld 'Common Name:') ${SERVER_CERT_NAME}\n- $(bld Country Code:) ${SERVER_CERT_COUNTRY_CODE}\n- $(bld State:) ${SERVER_CERT_STATE}\n- $(bld Locality:) ${SERVER_CERT_LOCALITY}\n- $(bld Organization:) ${SERVER_CERT_ORGANIZATION}\n- $(bld Organizational Unit:) ${SERVER_CERT_ORGANIZATIONAL_UNIT}\n- $(bld Email:) ${SERVER_CERT_EMAIL}"
  echo -e "- $(bld 'DNS SANs:')\n${SERVER_DNS_SANS_NL}"

  echo ""

  if gum confirm; then
    # Make sure the certificate name is unique
    local SERVER_CERT_PATH="${PARENT_CA_PATH}/certs/${SAFE_SERVER_CERT_NAME}.cert.pem"
    local SERVER_KEY_PATH="${PARENT_CA_PATH}/private/${SAFE_SERVER_CERT_NAME}.key.pem"
    
    if [ -f "${SERVER_CERT_PATH}" ] || [ -f "${SERVER_KEY_PATH}" ]; then
      echo "Certificate with name '${SERVER_CERT_NAME}' already exists.  Exiting..."
      exit 1
    fi

    generatePrivateKey "${SERVER_KEY_PATH}" "Certificate"

    if [ ! -f "${PARENT_CA_PATH}/csr/${SAFE_SERVER_CERT_NAME}.csr.pem" ]; then
      echo -e "- Creating Certificate Signing Request (CSR)..."
      
      openssl req -new -sha256 \
        -config ${PARENT_CA_PATH}/openssl.cnf \
        -key ${PARENT_CA_PATH}/private/${SAFE_SERVER_CERT_NAME}.key.pem \
        -out ${PARENT_CA_PATH}/csr/${SAFE_SERVER_CERT_NAME}.csr.pem \
        -addext 'subjectAltName = '${SERVER_DNS_SANS_FORMATTED}'' \
        -subj "/emailAddress=${SERVER_CERT_EMAIL}/C=${SERVER_CERT_COUNTRY_CODE}/ST=${SERVER_CERT_STATE}/L=${SERVER_CERT_LOCALITY}/O=${SERVER_CERT_ORGANIZATION}/OU=${SERVER_CERT_ORGANIZATIONAL_UNIT}/CN=${SERVER_CERT_NAME}"
    else
      echo "- CSR already exists: ${PARENT_CA_PATH}/csr/${SAFE_SERVER_CERT_NAME}.csr.pem"
    fi

    if [ ! -f "${SERVER_CERT_PATH}" ]; then
      echo "- No certificate found, creating now..."
      SIGNING_CA_CERT_PASS=$(gum input --password --prompt "Enter a password for the Signing CA Certificate private key: ")
      PW_FILE=$(mktemp)
      echo ${SIGNING_CA_CERT_PASS} > ${PW_FILE}

      openssl ca -config ${PARENT_CA_PATH}/openssl.cnf \
        -extensions server_cert -days 375 -notext -md sha256 \
        -passin file:${PW_FILE} \
        -batch -in ${PARENT_CA_PATH}/csr/${SAFE_SERVER_CERT_NAME}.csr.pem \
        -out ${SERVER_CERT_PATH}
      
      rm -f ${PW_FILE}
    else
      echo "- Certificate already exists: ${SERVER_CERT_PATH}"
    fi
  else
    selectCAActions "${PARENT_CA_PATH}"
  fi

}