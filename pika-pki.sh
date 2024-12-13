#!/bin/bash

#set -e
shopt -s extglob
clear

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source ${SCRIPT_DIR}/functions/common.sh
source ${SCRIPT_DIR}/functions/formatting.sh
source ${SCRIPT_DIR}/functions/config.sh
source ${SCRIPT_DIR}/functions/root-ca.sh
source ${SCRIPT_DIR}/functions/intermediate-ca.sh
source ${SCRIPT_DIR}/functions/signing-ca.sh

export PIKA_PKI_DIR=${PIKA_PKI_DIR:="$(pwd)/.pika-pki"}

echo "===== Working PKI Base Directory: ${PIKA_PKI_DIR}"
echo "Do you want to continue with this directory?"
gum confirm && echo -e "- Continuing...\n" || exit 1

#=======================================================================================================================
# Root CA Selection
#=======================================================================================================================
mkdir -p ${PIKA_PKI_DIR}/roots

ROOT_CA_CHOICE=""
ROOT_CA_COMMON_NAMES=()
ROOT_CA_GLUE=()
ROOT_CA_GLUE_STR=''
ROOT_CA_COMMON_NAMES_STR='[+] Create a new Root CA'

ROOT_CA_DIRS=$(find ${PIKA_PKI_DIR}/roots/ -maxdepth 1 -type d -printf '%p\n' | grep -ve "^${PIKA_PKI_DIR}/roots/$")

function setRootCASelectionVariables {
  ROOT_CA_DIRS=$(find ${PIKA_PKI_DIR}/roots/ -maxdepth 1 -type d -printf '%p\n' | grep -ve "^${PIKA_PKI_DIR}/roots/$")

  ROOT_CA_CERT=""
  ROOT_CA_COMMON_NAME=""
  ROOT_CA_GLUE=()
  ROOT_CA_GLUE_STR=''
  ROOT_CA_COMMON_NAMES_STR="[+] Create a new Root CA"
  ROOT_CA_COMMON_NAMES=()

  while IFS= read -r line; do
    if [ -z "$line" ]; then
      continue
    fi
    ROOT_CA_CERT="${line}/certs/ca.cert.pem"
    ROOT_CA_COMMON_NAME="$(getCertificateCommonName ${ROOT_CA_CERT})"
    ROOT_CA_GLUE+=("${line}|${ROOT_CA_COMMON_NAME}")
    ROOT_CA_GLUE_STR="${ROOT_CA_GLUE_STR}${line}|${ROOT_CA_COMMON_NAME}\n"
    ROOT_CA_COMMON_NAMES+=("${ROOT_CA_COMMON_NAME}")
    ROOT_CA_COMMON_NAMES_STR+="\n$ROOT_CA_COMMON_NAME"
  done <<< "$ROOT_CA_DIRS"
}

function rootCASelectionScreen {
  setRootCASelectionVariables
  ROOT_CA_CHOICE=$(echo -e $ROOT_CA_COMMON_NAMES_STR | gum choose)
  setRootCASelectionVariables

  case $ROOT_CA_CHOICE in
    "[+] Create a new Root CA")
      createNewRootCA
      ROOT_CA_CHOICE=$(rootCASelectionScreen)
      ;;
    +[:blank:])
      exit 1
      ;;
  esac
  echo $ROOT_CA_CHOICE
}

function selectRootCA {
  clear
  echoBanner "Root CA Selection"
  setRootCASelectionVariables

  # If empty, prompt to create a new Root CA
  if [ -z "$ROOT_CA_DIRS" ]; then
    echo "===== No PKI initialized.  Creating new Root CA..."
    createNewRootCA
    ROOT_CA_CHOICE=$(rootCASelectionScreen)
    if [ -z "$ROOT_CA_CHOICE" ]; then
      echo "No Root CA selected.  Exiting..."
      exit 1
    fi
  else
    #setRootCASelectionVariables
    ROOT_CA_CHOICE=$(rootCASelectionScreen)
    if [ -z "$ROOT_CA_CHOICE" ]; then
      echo "No Root CA selected.  Exiting..."
      exit 1
    fi
    #setRootCASelectionVariables
  fi

  ROOT_CA_CN=$(echo -e ${ROOT_CA_GLUE_STR} | grep -e "|${ROOT_CA_CHOICE}\$" | cut -d"|" -f2)
  ROOT_CA_DIR=$(echo -e ${ROOT_CA_GLUE_STR} | grep -e "|${ROOT_CA_CHOICE}\$" | cut -d"|" -f1)
  echo -e "- $(bld "Working with Root CA:") ${ROOT_CA_CN} - ${ROOT_CA_DIR}\n"
  selectCAActions "${ROOT_CA_DIR}"
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
  local CA_ACTIONS='../ Back\n[+] Create a new Certificate\n[+] Get Certificate Bundle'
  
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

  case "$SELECTED_ACTION" in
    "../ Back")
      if [ "${IS_ROOT_CA}" == "true" ]; then
        selectRootCA
      else
        selectCAActions $(getCAParentPath ${ACTIVE_CA_PATH})
      fi
      ;;
    "[+] Create a new Certificate")
      createNewCertificate
      ;;
    "[+] Get Certificate Bundle")
      getCertificateBundle
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

selectRootCA