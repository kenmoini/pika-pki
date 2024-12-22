#!/bin/bash

#======================================================================================================================================
# Root CA Prompts
#======================================================================================================================================
function promptNewRootCAName {
  local ROOT_CA_NAME=$(gum input --prompt "* Root CA [Common] Name: " --placeholder "ACME Root Certificate Authority")
  if [ -z "$ROOT_CA_NAME" ]; then
    promptNewRootCAName
  else
    echo ${ROOT_CA_NAME}
  fi
}

function promptNewRootCACountryCode {
  local ROOT_CA_COUNTRY_CODE=$(gum input --prompt "* Country Code: " --placeholder "US" --value "${PIKA_PKI_DEFAULT_COUNTRY}")
  if [ -z "$ROOT_CA_COUNTRY_CODE" ]; then
    promptNewRootCACountryCode
  else
    echo ${ROOT_CA_COUNTRY_CODE}
  fi
}

function promptNewRootCAState {
  local ROOT_CA_STATE=$(gum input --prompt "* State: " --placeholder "California" --value "${PIKA_PKI_DEFAULT_STATE}")
  if [ -z "$ROOT_CA_STATE" ]; then
    promptNewRootCAState
  else
    echo ${ROOT_CA_STATE}
  fi
}

function promptNewRootCALocality {
  local ROOT_CA_LOCALITY=$(gum input --prompt "* City/Locality: " --placeholder "San Francisco" --value "${PIKA_PKI_DEFAULT_LOCALITY}")
  if [ -z "$ROOT_CA_LOCALITY" ]; then
    promptNewRootCALocality
  else
    echo ${ROOT_CA_LOCALITY}
  fi
}

function promptNewRootCAOrganization {
  local ROOT_CA_ORGANIZATION=$(gum input --prompt "* Organization: " --placeholder "ACME Corporation" --value "${PIKA_PKI_DEFAULT_ORG}")
  if [ -z "$ROOT_CA_ORGANIZATION" ]; then
    promptNewRootCAOrganization
  else
    echo ${ROOT_CA_ORGANIZATION}
  fi
}

function promptNewRootCAOrganizationalUnit {
  local ROOT_CA_ORGANIZATIONAL_UNIT=$(gum input --prompt "* Organizational Unit: " --placeholder "InfoSec" --value "${PIKA_PKI_DEFAULT_ORGUNIT}")
  if [ -z "$ROOT_CA_ORGANIZATIONAL_UNIT" ]; then
    promptNewRootCAOrganizationalUnit
  else
    echo ${ROOT_CA_ORGANIZATIONAL_UNIT}
  fi
}

function promptNewRootCAEmail {
  local ROOT_CA_EMAIL=$(gum input --prompt "* Email: " --placeholder "you@acme.com" --value "${PIKA_PKI_DEFAULT_EMAIL}")
  if [ -z "$ROOT_CA_EMAIL" ]; then
    promptNewRootCAEmail
  else
    echo ${ROOT_CA_EMAIL}
  fi
}

function promptNewRootCACRLURL {
  local ROOT_CA_CRL_DIST_URI=$(gum input --prompt " [Optional] CRL URI Root: " --placeholder "https://acme.com/pki/crl" --value "${PIKA_PKI_DEFAULT_CRL_URI_BASE}")
  echo ${ROOT_CA_CRL_DIST_URI}
}

#======================================================================================================================================
# Intermediate CA Prompts
#======================================================================================================================================
function promptNewIntermediateCAName {
  local INTERMEDIATE_CA_NAME=$(gum input --prompt "* Intermediate CA [Common] Name: " --placeholder "ACME Intermediate Certificate Authority")
  if [ -z "$INTERMEDIATE_CA_NAME" ]; then
    promptNewIntermediateCAName
  else
    echo ${INTERMEDIATE_CA_NAME}
  fi
}

function promptNewIntermediateCACountryCode {
  local INTERMEDIATE_CA_COUNTRY_CODE=$(gum input --prompt "* Country Code: " --placeholder "US" --value "${PIKA_PKI_DEFAULT_COUNTRY}")
  if [ -z "$INTERMEDIATE_CA_COUNTRY_CODE" ]; then
    promptNewIntermediateCACountryCode
  else
    echo ${INTERMEDIATE_CA_COUNTRY_CODE}
  fi
}

function promptNewIntermediateCAState {
  local INTERMEDIATE_CA_STATE=$(gum input --prompt "* State: " --placeholder "California" --value "${PIKA_PKI_DEFAULT_STATE}")
  if [ -z "$INTERMEDIATE_CA_STATE" ]; then
    promptNewIntermediateCAState
  else
    echo ${INTERMEDIATE_CA_STATE}
  fi
}

function promptNewIntermediateCALocality {
  local INTERMEDIATE_CA_LOCALITY=$(gum input --prompt "* City/Locality: " --placeholder "San Francisco" --value "${PIKA_PKI_DEFAULT_LOCALITY}")
  if [ -z "$INTERMEDIATE_CA_LOCALITY" ]; then
    promptNewIntermediateCALocality
  else
    echo ${INTERMEDIATE_CA_LOCALITY}
  fi
}

function promptNewIntermediateCAOrganization {
  local INTERMEDIATE_CA_ORGANIZATION=$(gum input --prompt "* Organization: " --placeholder "ACME Corporation" --value "${PIKA_PKI_DEFAULT_ORG}")
  if [ -z "$INTERMEDIATE_CA_ORGANIZATION" ]; then
    promptNewIntermediateCAOrganization
  else
    echo ${INTERMEDIATE_CA_ORGANIZATION}
  fi
}

function promptNewIntermediateCAOrganizationalUnit {
  local INTERMEDIATE_CA_ORGANIZATIONAL_UNIT=$(gum input --prompt "* Organizational Unit: " --placeholder "InfoSec" --value "${PIKA_PKI_DEFAULT_ORGUNIT}")
  if [ -z "$INTERMEDIATE_CA_ORGANIZATIONAL_UNIT" ]; then
    promptNewIntermediateCAOrganizationalUnit
  else
    echo ${INTERMEDIATE_CA_ORGANIZATIONAL_UNIT}
  fi
}

function promptNewIntermediateCAEmail {
  local INTERMEDIATE_CA_EMAIL=$(gum input --prompt "* Email: " --placeholder "you@acme.com" --value "${PIKA_PKI_DEFAULT_EMAIL}")
  if [ -z "$INTERMEDIATE_CA_EMAIL" ]; then
    promptNewIntermediateCAEmail
  else
    echo ${INTERMEDIATE_CA_EMAIL}
  fi
}

function promptNewIntermediateCACRLURL {
  local INTERMEDIATE_CA_CRL_DIST_URI=$(gum input --prompt " [Optional] CRL URI Root: " --placeholder "https://acme.com/pki/crl" --value "${PIKA_PKI_DEFAULT_CRL_URI_BASE}")
  echo ${INTERMEDIATE_CA_CRL_DIST_URI}
}

#======================================================================================================================================
# Signing CA Prompts
#======================================================================================================================================
function promptNewSigningCAName {
  local SIGNING_CA_NAME=$(gum input --prompt "* Signing CA [Common] Name: " --placeholder "ACME Signing Certificate Authority")
  if [ -z "$SIGNING_CA_NAME" ]; then
    promptNewSigningCAName
  else
    echo ${SIGNING_CA_NAME}
  fi
}

function promptNewSigningCACountryCode {
  local SIGNING_CA_COUNTRY_CODE=$(gum input --prompt "* Country Code: " --placeholder "US" --value "${PIKA_PKI_DEFAULT_COUNTRY}")
  if [ -z "$SIGNING_CA_COUNTRY_CODE" ]; then
    promptNewSigningCACountryCode
  else
    echo ${SIGNING_CA_COUNTRY_CODE}
  fi
}

function promptNewSigningCAState {
  local SIGNING_CA_STATE=$(gum input --prompt "* State: " --placeholder "California" --value "${PIKA_PKI_DEFAULT_STATE}")
  if [ -z "$SIGNING_CA_STATE" ]; then
    promptNewSigningCAState
  else
    echo ${SIGNING_CA_STATE}
  fi
}

function promptNewSigningCALocality {
  local SIGNING_CA_LOCALITY=$(gum input --prompt "* City/Locality: " --placeholder "San Francisco" --value "${PIKA_PKI_DEFAULT_LOCALITY}")
  if [ -z "$SIGNING_CA_LOCALITY" ]; then
    promptNewSigningCALocality
  else
    echo ${SIGNING_CA_LOCALITY}
  fi
}

function promptNewSigningCAOrganization {
  local SIGNING_CA_ORGANIZATION=$(gum input --prompt "* Organization: " --placeholder "ACME Corporation" --value "${PIKA_PKI_DEFAULT_ORG}")
  if [ -z "$SIGNING_CA_ORGANIZATION" ]; then
    promptNewSigningCAOrganization
  else
    echo ${SIGNING_CA_ORGANIZATION}
  fi
}

function promptNewSigningCAOrganizationalUnit {
  local SIGNING_CA_ORGANIZATIONAL_UNIT=$(gum input --prompt "* Organizational Unit: " --placeholder "InfoSec" --value "${PIKA_PKI_DEFAULT_ORGUNIT}")
  if [ -z "$SIGNING_CA_ORGANIZATIONAL_UNIT" ]; then
    promptNewSigningCAOrganizationalUnit
  else
    echo ${SIGNING_CA_ORGANIZATIONAL_UNIT}
  fi
}

function promptNewSigningCAEmail {
  local SIGNING_CA_EMAIL=$(gum input --prompt "* Email: " --placeholder "you@acme.com" --value "${PIKA_PKI_DEFAULT_EMAIL}")
  if [ -z "$SIGNING_CA_EMAIL" ]; then
    promptNewSigningCAEmail
  else
    echo ${SIGNING_CA_EMAIL}
  fi
}

function promptNewSigningCACRLURL {
  local SIGNING_CA_CRL_DIST_URI=$(gum input --prompt " [Optional] CRL URI Root: " --placeholder "https://acme.com/pki/crl" --value "${PIKA_PKI_DEFAULT_CRL_URI_BASE}")
  echo ${SIGNING_CA_CRL_DIST_URI}
}
