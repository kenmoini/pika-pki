#!/bin/bash

shopt -s extglob;

source ${SCRIPT_DIR}/functions/formatting.sh
source ${SCRIPT_DIR}/functions/common.sh

# promptSavePath will prompt the user to select a path to save a file
# {1} PATH_START: The path to start searching from
function promptSavePath {
  local PATH_START=${1}
  local SAVE_PATH=$(GUM_FILE_DIRECTORY="true" GUM_FILE_FILE="false" GUM_FILE_ALL="true" GUM_FILE_HEIGHT="16" gum file ${PATH_START})
  if [ -z "$SAVE_PATH" ]; then
    promptSavePath
  else
    echo ${SAVE_PATH}
  fi
}

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
  local SERVER_CERT_ORGANIZATIONAL_UNIT=$(gum input --prompt "* Organizational Unit: " --placeholder "InfoSec" --value "${PIKA_PKI_DEFAULT_ORGUNIT}")
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
    selectCertificateActions ${SERVER_CERT_PATH}
  else
    selectCAActions "${PARENT_CA_PATH}"
  fi

}

# selectCertificateActions will display the options for a certificate
# {1} CERT_PATH: The path to the certificate to select
# {2} HEADER_OFF: Whether to display the header or not, defaults to "false"
function selectCertificateActions {
  local CERT_PATH=${1}
  local HEADER_OFF=${2:-"false"}
  local CERT_CN=$(getCertificateCommonName ${CERT_PATH})
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))
  local CERT_CA_CERT_PATH="${CERT_CA_PATH}/certs/ca.cert.pem"

  if [ "${HEADER_OFF}" == "false" ]; then
    clear
    echoBanner "[Certificate] ${CERT_CN} - Certificate Actions"
    echo "===== Path: $(getPKIPath ${CERT_CA_PATH})"
  fi

  local CERT_OPTIONS='../ Back\n[+] Save Certificate\n[+] View Certificate'

  # Check to see if the CA has a CRL
  CA_CRL_CHECK=$(openssl x509 -text -in ${CERT_CA_CERT_PATH} |grep -A4 'CRL Distribution Points' | tail -n1 | sed 's/URI://g' | sed 's/ //g')
  if [ ! -z "${CA_CRL_CHECK}" ]; then
    CERT_OPTIONS=''${CERT_OPTIONS}'\n[+] Revoke Certificate'
  else
    CERT_OPTIONS=''${CERT_OPTIONS}'\n[+] Delete Certificate (CRL not available)'
  fi

  local SELECTED_ACTION=$(echo -e $CERT_OPTIONS | gum choose)
  if [ -z "$SELECTED_ACTION" ]; then
    echo "No action selected, exiting..."
    exit 1
  fi

  case "$SELECTED_ACTION" in
    "../ Back")
      certificateSelectionScreen ${CERT_CA_PATH}
      ;;
    "[+] Save Certificate")
      saveCertificateActions ${CERT_PATH}
      ;;
    "[+] View Certificate")
      viewCertificate ${CERT_PATH}
      ;;
    "[+] Delete Certificate"*)
      deleteCertificate ${CERT_PATH}
      ;;
    "[+] Revoke Certificate")
      revokeCertificate ${CERT_PATH}
      ;;
    *)
      echo "Invalid selection, exiting"
      exit 1
      ;;
  esac
}

# viewCertificate will display the details of a certificate
# {1} CERT_PATH: The path to the certificate to view
function viewCertificate {
  local CERT_PATH=${1}
  local CERT_CN=$(getCertificateCommonName ${CERT_PATH})
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))

  clear
  echoBanner "[Certificate] ${CERT_CN} - View Certificate"
  echo "===== Path: $(getPKIPath ${CERT_CA_PATH})"

  local CERT_ORG=$(openssl x509 -noout -subject -in ${CERT_PATH} -nameopt multiline | awk -F' = ' '/organizationName/ {print $2}')
  local CERT_ORG_UNIT=$(openssl x509 -noout -subject -in ${CERT_PATH} -nameopt multiline | awk -F' = ' '/organizationalUnitName/ {print $2}')
  local CERT_START_DATE=$(openssl x509 -noout -startdate -in ${CERT_PATH} | cut -d'=' -f2)
  local CERT_END_DATE=$(openssl x509 -noout -enddate -in ${CERT_PATH} | cut -d'=' -f2)
  local CERT_FINGERPRINT=$(openssl x509 -noout -fingerprint -in ${CERT_PATH} | cut -d'=' -f2)
  local CERT_SERIAL=$(openssl x509 -noout -serial -in ${CERT_PATH} | cut -d'=' -f2)
  local CERT_LOCATION="$(openssl x509 -noout -subject -in ${CERT_PATH} -nameopt multiline | awk -F' = ' '/localityName/ {print $2}') $(openssl x509 -noout -subject -in ${CERT_PATH} -nameopt multiline | awk -F' = ' '/stateOrProvinceName/ {print $2}'), $(openssl x509 -noout -subject -in ${CERT_PATH} -nameopt multiline | awk -F' = ' '/countryName/ {print $2}')"

  echo "- Common Name: ${CERT_CN}"
  echo "- Organization, Unit: ${CERT_ORG}, ${CERT_ORG_UNIT}"
  echo "- Location: ${CERT_LOCATION}"
  echo "- Validity: ${CERT_START_DATE} - ${CERT_END_DATE}"
  echo "- Fingerprint: ${CERT_FINGERPRINT}"
  echo "- Serial: ${CERT_SERIAL}"
  echo -e "- $(openssl x509 -noout -ext subjectAltName -in ${CERT_PATH} | sed 's/,/\n   /g')"
  echo ""
  selectCertificateActions ${CERT_PATH} "true"
}

# deleteCertificate will delete a certificate and its associated files
# {1} CERT_PATH: The path to the certificate to delete
function deleteCertificate {
  local CERT_PATH=${1}
  local CSR_PATH=$(echo ${CERT_PATH} | sed 's|.cert.pem|.csr.pem|g' | sed 's|certs/|csr/|g')
  local KEY_PATH=$(echo ${CERT_PATH} | sed 's|.cert.pem|.key.pem|g' | sed 's|certs/|private/|g')
  local CERT_CN=$(getCertificateCommonName ${CERT_PATH})
  local CERT_SERIAL=$(openssl x509 -noout -serial -in ${CERT_PATH} | cut -d'=' -f2)
  local CERT_SERIAL_CERT_PATH=$(echo ${CERT_PATH} | sed 's|.cert.pem|.pem|g' | sed 's|/certs/|/newcerts/|g')
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))

  clear
  echoBanner "[Certificate] ${CERT_CN} - Delete Certificate"
  echo "===== Path: $(getPKIPath ${CERT_CA_PATH})"

  echo -e "\n====== DANGER ZONE ======\n====== DANGER ZONE ======\n====== DANGER ZONE ======\n"
  echo "Are you sure you want to DELETE the certificate?"

  if gum confirm; then
    sed -i '/[[:blank:]]'${CERT_SERIAL}'[[:blank:]]/d' ${CERT_CA_PATH}/index.txt
    rm -f ${CERT_PATH} ${CSR_PATH} ${KEY_PATH} ${CERT_SERIAL_CERT_PATH}
    echo "Certificate deleted: ${CERT_CN}"
    certificateSelectionScreen ${CERT_CA_PATH}
  else
    echo "Certificate deletion cancelled."
    selectCertificateActions ${CERT_PATH}
  fi
}

# revokeCertificate will revoke a certificate and its associated files
# {1} CERT_PATH: The path to the certificate to revoke
function revokeCertificate {
  local CERT_PATH=${1}
  local CSR_PATH=$(echo ${CERT_PATH} | sed 's|.cert.pem|.csr.pem|g' | sed 's|certs/|csr/|g')
  local KEY_PATH=$(echo ${CERT_PATH} | sed 's|.cert.pem|.key.pem|g' | sed 's|certs/|private/|g')
  local CERT_CN=$(getCertificateCommonName ${CERT_PATH})
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))

  clear
  echoBanner "[Certificate] ${CERT_CN} - Revoke Certificate"
  echo "===== Path: $(getPKIPath ${CERT_CA_PATH})"

  echo -e "\n====== DANGER ZONE ======\n====== DANGER ZONE ======\n====== DANGER ZONE ======\n"
  echo "Are you sure you want to REVOKE the certificate?"

  if gum confirm; then
    openssl ca -config ${CERT_CA_PATH}/openssl.cnf \
      revoke ${CERT_PATH}

    mv ${CERT_PATH} ${CERT_PATH}.revoked
    mv ${CSR_PATH} ${CSR_PATH}.revoked
    mv ${KEY_PATH} ${KEY_PATH}.revoked

    #echo "Certificate revoked: ${CERT_CN}"
    certificateSelectionScreen ${CERT_CA_PATH}
  else
    #echo "Certificate deletion cancelled."
    selectCertificateActions ${CERT_PATH}
  fi
}

function saveCertificateActions {
  local CERT_PATH=${1}
  local HEADER_OFF=${2:-"false"}
  local CERT_CN=$(getCertificateCommonName ${CERT_PATH})
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))

  if [ "${HEADER_OFF}" == "false" ]; then
    clear
    echoBanner "[Certificate] ${CERT_CN} - Save Certificate Type"
    echo "===== Path: $(getPKIPath ${CERT_CA_PATH})"
  fi

  local CERT_OPTIONS='../ Back\n[+] Save Certificate as PKCS#12\n[+] Save Certificate as PEM\n[+] Save Certificate Bundle\n[+] Save HAProxy Bundle'

  local SELECTED_ACTION=$(echo -e $CERT_OPTIONS | gum choose)
  if [ -z "$SELECTED_ACTION" ]; then
    echo "No action selected, exiting..."
    exit 1
  fi

  case "$SELECTED_ACTION" in
    "../ Back")
      selectCertificateActions ${CERT_PATH}
      ;;
    "[+] Save Certificate as PKCS#12")
      saveCertificateFiles ${CERT_PATH} "pkcs12"
      ;;
    "[+] Save Certificate as PEM")
      saveCertificateFiles ${CERT_PATH} "pem"
      ;;
    "[+] Save Certificate Bundle")
      saveCertificateFiles ${CERT_PATH} "bundle"
      ;;
    "[+] Save HAProxy Bundle")
      saveCertificateFiles ${CERT_PATH} "haproxy"
      ;;
    *)
      echo "Invalid selection, exiting"
      exit 1
      ;;
  esac
}

function saveCertificateFiles {
  local CERT_PATH=${1}
  local SAVE_TYPE=${2}
  local CERT_CN=$(getCertificateCommonName ${CERT_PATH})
  local CERT_CN_SLUG=$(slugify "${CERT_CN}")
  local CERT_KEY_PATH=$(echo ${CERT_PATH} | sed 's|.cert.pem|.key.pem|g' | sed 's|certs/|private/|g')
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))

  clear
  echoBanner "[Certificate] ${CERT_CN} - Save Certificate Bundle"
  echo -e "===== Path: $(getPKIPath ${CERT_CA_PATH})\n"
  echo "Use your keyboard to select a path to save the certificate bundle."
  echo -e " Up | Down | Left = Parent Directory | Right = Enter Directory | Enter = Select Directory\n"

  local SAVE_PATH_SELECTION=$(promptSavePath ${PIKA_PKI_DIR})

  if [ "$(isCertificateAuthority ${CERT_PATH})" == "true" ]; then
    local SAVE_PATH=${SAVE_PATH_SELECTION}/${CERT_CN_SLUG}
  else
    local SAVE_PATH=${SAVE_PATH_SELECTION}/${CERT_CN}
  fi

  mkdir -p ${SAVE_PATH}
  
  # Copy the Root CA over - that's always handy
  cp "$(getRootCAPath ${CERT_PATH})/certs/ca.cert.pem" ${SAVE_PATH}/root-ca.pem

  # Basic certificate bundle and PEM files
  if [ "${SAVE_TYPE}" == "pem" ] || [ "${SAVE_TYPE}" == "bundle" ]; then
    cp ${CERT_PATH} ${SAVE_PATH}/cert.pem
    cp ${CERT_KEY_PATH} ${SAVE_PATH}/key.pem
    cp ${CERT_CA_PATH}/certs/ca.cert.pem ${SAVE_PATH}/ca.pem
  fi

  # Generate the CA chain files
  if [ "${SAVE_TYPE}" == "bundle" ]; then
    generateCAChain ${CERT_PATH} > ${SAVE_PATH}/chain.pem
    generateCAChain ${CERT_PATH} "true" > ${SAVE_PATH}/full-chain.pem

    # Concatenate the cert and chain files
    cat ${CERT_PATH} ${SAVE_PATH}/chain.pem > ${SAVE_PATH}/cert-chain.pem
    cat ${CERT_PATH} ${SAVE_PATH}/full-chain.pem > ${SAVE_PATH}/cert-full-chain.pem
  fi

  if [ "${SAVE_TYPE}" == "haproxy" ]; then
    cat ${CERT_KEY_PATH} ${CERT_PATH} > ${SAVE_PATH}/haproxy.pem
    cat ${CERT_KEY_PATH} ${CERT_PATH} > ${SAVE_PATH}/haproxy-chain.pem
    cat ${CERT_KEY_PATH} ${CERT_PATH} > ${SAVE_PATH}/haproxy-full-chain.pem

    generateCAChain ${CERT_PATH} >> ${SAVE_PATH}/haproxy-chain.pem
    generateCAChain ${CERT_PATH} "true" >> ${SAVE_PATH}/haproxy-full-chain.pem
  fi

  # https://jackstromberg.com/2013/01/generating-a-pkcs12-file-with-openssl/
  if [ "${SAVE_TYPE}" == "pkcs12" ]; then
    local PKCS12_PASS=$(gum input --password --prompt "Enter a password for the PKCS#12 file: ")
    openssl pkcs12 -export -out ${SAVE_PATH}/cert.p12 -inkey ${CERT_KEY_PATH} -in ${CERT_PATH} -certfile ${CERT_CA_PATH}/certs/ca.cert.pem -passout pass:${PKCS12_PASS}
  fi

  tree ${SAVE_PATH}

  saveCertificateActions ${CERT_PATH} "true"
}