#!/bin/bash

#=====================================================================================================================
# promptSavePath will prompt the user to select a path to save a file
# {1} PATH_START: The path to start searching from
#=====================================================================================================================
function promptSavePath {
  local PATH_START=${1}
  local SAVE_PATH=$(GUM_FILE_DIRECTORY="true" GUM_FILE_FILE="false" GUM_FILE_ALL="true" GUM_FILE_HEIGHT="16" gum file ${PATH_START})
  if [ -z "$SAVE_PATH" ]; then
    promptSavePath
  else
    echo ${SAVE_PATH}
  fi
}

#=====================================================================================================================
# promptNewServerCertificateName will prompt the user for a new server certificate [common] name
#=====================================================================================================================
function promptNewServerCertificateName {
  local SERVER_CERT_NAME=$(gum input --prompt "* Server Certificate [Common] Name: " --placeholder "server.acme.com")
  if [ -z "$SERVER_CERT_NAME" ]; then
    promptNewServerCertificateName
  else
    echo ${SERVER_CERT_NAME}
  fi
}

#=====================================================================================================================
# promptNewServerCertificateDNSSAN will prompt the user for a new server certificate's additional DNS SANs
#=====================================================================================================================
function promptNewServerCertificateDNSSAN {
  local SERVER_CERT_DNS_SAN=$(gum input --prompt "[Optional] Additional DNS SAN(s): " --placeholder "*.apps.server.acme.com,api.server.acme.com")
  echo ${SERVER_CERT_DNS_SAN}
}

#=====================================================================================================================
# promptNewServerCertificateCountryCode will prompt the user for a new server certificate's country code
#=====================================================================================================================
function promptNewServerCertificateCountryCode {
  local SERVER_CERT_COUNTRY_CODE=$(gum input --prompt "* Country Code: " --placeholder "US" --value "${PIKA_PKI_DEFAULT_COUNTRY}")
  if [ -z "$SERVER_CERT_COUNTRY_CODE" ]; then
    promptNewServerCertificateCountryCode
  else
    echo ${SERVER_CERT_COUNTRY_CODE}
  fi
}

#=====================================================================================================================
# promptNewServerCertificateState will prompt the user for a new server certificate's state
#=====================================================================================================================
function promptNewServerCertificateState {
  local SERVER_CERT_STATE=$(gum input --prompt "* State: " --placeholder "California" --value "${PIKA_PKI_DEFAULT_STATE}")
  if [ -z "$SERVER_CERT_STATE" ]; then
    promptNewServerCertificateState
  else
    echo ${SERVER_CERT_STATE}
  fi
}

#=====================================================================================================================
# promptNewServerCertificateLocality will prompt the user for a new server certificate's locality/city
#=====================================================================================================================
function promptNewServerCertificateLocality {
  local SERVER_CERT_LOCALITY=$(gum input --prompt "* City/Locality: " --placeholder "San Francisco" --value "${PIKA_PKI_DEFAULT_LOCALITY}")
  if [ -z "$SERVER_CERT_LOCALITY" ]; then
    promptNewServerCertificateLocality
  else
    echo ${SERVER_CERT_LOCALITY}
  fi
}

#=====================================================================================================================
# promptNewServerCertificateOrganization will prompt the user for a new server certificate's organization
#=====================================================================================================================
function promptNewServerCertificateOrganization {
  local SERVER_CERT_ORGANIZATION=$(gum input --prompt "* Organization: " --placeholder "ACME Corporation" --value "${PIKA_PKI_DEFAULT_ORG}")
  if [ -z "$SERVER_CERT_ORGANIZATION" ]; then
    promptNewServerCertificateOrganization
  else
    echo ${SERVER_CERT_ORGANIZATION}
  fi
}

#=====================================================================================================================
# promptNewServerCertificateOrganizationalUnit will prompt the user for a new server certificate's organizational unit
#=====================================================================================================================
function promptNewServerCertificateOrganizationalUnit {
  local SERVER_CERT_ORGANIZATIONAL_UNIT=$(gum input --prompt "* Organizational Unit: " --placeholder "InfoSec" --value "${PIKA_PKI_DEFAULT_ORGUNIT}")
  if [ -z "$SERVER_CERT_ORGANIZATIONAL_UNIT" ]; then
    promptNewServerCertificateOrganizationalUnit
  else
    echo ${SERVER_CERT_ORGANIZATIONAL_UNIT}
  fi
}

#=====================================================================================================================
# promptNewServerCertificateEmail will prompt the user for a new server certificate's requester email
#=====================================================================================================================
function promptNewServerCertificateEmail {
  local SERVER_CERT_EMAIL=$(gum input --prompt "* Email: " --placeholder "you@acme.com" --value "${PIKA_PKI_DEFAULT_EMAIL}")
  if [ -z "$SERVER_CERT_EMAIL" ]; then
    promptNewServerCertificateEmail
  else
    echo ${SERVER_CERT_EMAIL}
  fi
}

#=====================================================================================================================
# promptNewServerCertificateOCPDomain will prompt the user for the base OpenShift domain to a cluster
#=====================================================================================================================
function promptNewServerCertificateOCPDomain {
  local SERVER_CERT_OCP_DOMAIN=$(gum input --prompt "* OpenShift Cluster Base URL: " --placeholder "cluster-name.example.com")
  if [ -z "$SERVER_CERT_OCP_DOMAIN" ]; then
    promptNewServerCertificateOCPDomain
  else
    echo ${SERVER_CERT_OCP_DOMAIN}
  fi
}