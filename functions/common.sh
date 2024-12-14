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
    if [ "${TYPE}" == "Certificate" ] && [ "false" == "${PIKA_PKI_CERT_KEY_ENCRYPTION}" ]; then
      openssl genrsa -out ${KEY_PATH} ${BIT_LENGTH}
    else
      KEY_PASS=$(gum input --password --prompt "Enter a password for the ${TYPE} private key: ")
      echo ${KEY_PASS} > ${PW_FILE}

      openssl genrsa -aes256 -passout file:${PW_FILE} -out ${KEY_PATH} ${BIT_LENGTH}
      rm -f ${PW_FILE}
    fi
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
  local CERTIFICATES=$(find ${ACTIVE_CA_PATH}/certs/ -maxdepth 1 -type f -printf '%p\n' | grep -ve "^${ACTIVE_CA_PATH}/certs/ca.cert.pem$")
  local CERTIFICATE_COUNT=$(echo -e "${CERTIFICATES}" | sed '/^$/d' | wc -l)
  local CA_ACTIONS='../ Back\n[+] Certificates ('$CERTIFICATE_COUNT')'
  
  clear
  echoBanner "[${CA_TYPE}] $(getBannerPath "${ACTIVE_CA_PATH}")"
  echo "===== Path: $(getPKIPath ${ACTIVE_CA_PATH})"

  if [ "$CA_TYPE" != "Signing" ]; then
    local INTERMEDIATE_CA_DIRS=$(find ${ACTIVE_CA_PATH}/intermediate-ca/ -maxdepth 1 -type d -printf '%p\n' | grep -ve "^${ACTIVE_CA_PATH}/intermediate-ca/$")
    local SIGNING_CA_DIRS=$(find ${ACTIVE_CA_PATH}/signing-ca/ -maxdepth 1 -type d -printf '%p\n' | grep -ve "^${ACTIVE_CA_PATH}/signing-ca/$")
    local INTERMEDIATE_CA_COUNT=$(echo -e "${INTERMEDIATE_CA_DIRS}" | sed '/^$/d' | wc -l)
    local SIGNING_CA_COUNT=$(echo -e "${SIGNING_CA_DIRS}" | sed '/^$/d' | wc -l)
    CA_ACTIONS=${CA_ACTIONS}'\n[+] Intermediate CAs ('$INTERMEDIATE_CA_COUNT')\n[+] Signing CAs ('$SIGNING_CA_COUNT')'
  fi

  local SELECTED_ACTION=$(echo -e $CA_ACTIONS | gum choose)
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

function certificateSelectionScreen {
  local CA_PATH=${1}
  local CA_TYPE=$(getCAType ${CA_PATH})
  local CERT_OPTIONS='../ Back\n[+] Create a new Certificate'
  local CERTIFICATES=$(find ${CA_PATH}/certs/ -maxdepth 1 -type f -printf '%p\n' | grep -ve "^${CA_PATH}/certs/ca.cert.pem$" | sed '/^$/d' | sed 's|'${CA_PATH}'/certs/||g' | sed 's|.cert.pem||g')
  if [ ! -z "${CERTIFICATES}" ]; then
    CERT_OPTIONS=''${CERT_OPTIONS}'\n'${CERTIFICATES}''
  fi

  clear
  echoBanner "[${CA_TYPE}] $(getBannerPath "${CA_PATH}") - Certificate Selection"
  echo "===== Path: $(getPKIPath ${CA_PATH})"
  
  local SELECTED_ACTION=$(echo -e $CERT_OPTIONS | gum choose)
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
      selectCertificateActions "${CA_PATH}/certs/${SELECTED_ACTION}.cert.pem"
      ;;
  esac

}
