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
  local ROOT_CA_COUNTRY_CODE=$(gum input --prompt "* Country Code: " --placeholder "US")
  if [ -z "$ROOT_CA_COUNTRY_CODE" ]; then
    promptNewRootCACountryCode
  else
    echo ${ROOT_CA_COUNTRY_CODE}
  fi
}

function promptNewRootCAState {
  local ROOT_CA_STATE=$(gum input --prompt "* State: " --placeholder "California")
  if [ -z "$ROOT_CA_STATE" ]; then
    promptNewRootCAState
  else
    echo ${ROOT_CA_STATE}
  fi
}

function promptNewRootCALocality {
  local ROOT_CA_LOCALITY=$(gum input --prompt "* City/Locality: " --placeholder "San Francisco")
  if [ -z "$ROOT_CA_LOCALITY" ]; then
    promptNewRootCALocality
  else
    echo ${ROOT_CA_LOCALITY}
  fi
}

function promptNewRootCAOrganization {
  local ROOT_CA_ORGANIZATION=$(gum input --prompt "* Organization: " --placeholder "ACME Corporation")
  if [ -z "$ROOT_CA_ORGANIZATION" ]; then
    promptNewRootCAOrganization
  else
    echo ${ROOT_CA_ORGANIZATION}
  fi
}

function promptNewRootCAOrganizationalUnit {
  local ROOT_CA_ORGANIZATIONAL_UNIT=$(gum input --prompt "* Organizational Unit: " --placeholder "InfoSec")
  if [ -z "$ROOT_CA_ORGANIZATIONAL_UNIT" ]; then
    promptNewRootCAOrganizationalUnit
  else
    echo ${ROOT_CA_ORGANIZATIONAL_UNIT}
  fi
}

function promptNewRootCAEmail {
  local ROOT_CA_EMAIL=$(gum input --prompt "* Email: " --placeholder "you@acme.com")
  if [ -z "$ROOT_CA_EMAIL" ]; then
    promptNewRootCAEmail
  else
    echo ${ROOT_CA_EMAIL}
  fi
}

function promptNewRootCACRLURL {
  local ROOT_CA_CRL_DIST_URI=$(gum input --prompt " [Optional] CRL URI: " --placeholder "https://acme.com/pki/crl")
  echo ${ROOT_CA_CRL_DIST_URI}
}

function createNewRootCA {
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
    generateOpenSSLConfFile "${ROOT_CA_DIR}" "root" "${ROOT_CA_COUNTRY_CODE}" "${ROOT_CA_STATE}" "${ROOT_CA_LOCALITY}" "${ROOT_CA_ORGANIZATION}" "${ROOT_CA_ORGANIZATIONAL_UNIT}" "${ROOT_CA_EMAIL}" 3650 "${ROOT_CA_CRL_DIST_URI}"
    
    #if [ ! -f ${ROOT_CA_DIR/private/ca.key.pem} ]; then
    #  echo "- No private key found, creating now..."
    #  ROOT_CA_PASS=$(gum input --password --prompt "Enter a password for the Root CA private key: ")
    #  PW_FILE=$(mktemp)
    #  echo ${ROOT_CA_PASS} > ${PW_FILE}
    #  generatePrivateKey "${ROOT_CA_DIR}/private/ca.key.pem" "${ROOT_CA_PASS}"
    #  rm -f ${PW_FILE}
    #else
    #  echo "- Private key already exists: ${ROOT_CA_DIR}/private/ca.key.pem"
    #fi
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
      if [ ! -f ${ROOT_CA_DIR}/crl/ca.crl.pem ]; then
        echo "- No CRL found, creating now..."
        openssl ca -config ${ROOT_CA_DIR}/openssl.cnf -gencrl -out ${ROOT_CA_DIR}/crl/ca.crl.pem
      else
        echo "- CRL already exists: ${ROOT_CA_DIR}/crl/ca.crl.pem"
      fi
    fi

    ROOT_CA_CHOICE="${ROOT_CA_NAME}"

  else
    echo "- Aborting..."
    exit 1
    #if [ ! -z "${ROOT_CA_CRL_DIST_URI}" ]; then
    #  nclr 10
    #else
    #  nclr 9
    #fi
  fi

}