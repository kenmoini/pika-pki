#!/bin/bash

#trap ctrl_c INT
#
#function ctrl_c() {
#  exit 1
#}

function generatePrivateKey {
  local KEY_PATH=${1}
  local TYPE=${2:-""}
  local BIT_LENGTH=${3:-4096}
  local PW_FILE=$(mktemp)

  if [ ! -f ${KEY_PATH} ]; then
    echo "- No private key found, creating now..."
    KEY_PASS=$(gum input --password --prompt "Enter a password for the ${TYPE} private key: ")
    echo ${KEY_PASS} > ${PW_FILE}

    openssl genrsa -aes256 -passout file:${PW_FILE} -out ${KEY_PATH} ${BIT_LENGTH}
    rm -f ${PW_FILE}
    chmod 400 ${KEY_PATH}
  else
    echo "- Private key already exists: ${1}"
  fi
}

function echoBanner {
  local PKI_PATH=${1}
  echo "===== Workspace: ${PIKA_PKI_DIR} - ${PKI_PATH}"
}

function getBannerPath {
  local CA_PATH=${1}
  local CA_CN=$(getCertificateCommonName "${CA_PATH}/certs/ca.cert.pem")
  echo $CA_CN
}

function getCertificateCommonName {
  openssl x509 -noout -subject -in ${1} -nameopt multiline | awk -F' = ' '/commonName/ {print $2}'
}

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

function getCAParentPath {
  local ACTIVE_CA_PATH=${1}
  local PARENT_PATH=$(dirname $(dirname ${ACTIVE_CA_PATH}))
  echo $PARENT_PATH
}

function getCAType {
  local ACTIVE_CA_PATH=${1}
  local PARENT_PATH=$(basename $(dirname ${ACTIVE_CA_PATH}))
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

function getPKIPath {
  local ACTIVE_CA_PATH=${1}
  local BASE_PATH=$(sed 's|'$PIKA_PKI_DIR'/||g' <<< ${ACTIVE_CA_PATH})
  local ROOT=$(sed 's|roots/||' <<< ${BASE_PATH})
  local INTERMEDIATE=$(sed 's|/intermediate-ca/| > |' <<< ${ROOT})
  local SIGNING=$(sed 's|/signing-ca/| > |' <<< ${INTERMEDIATE})
  echo $SIGNING
}