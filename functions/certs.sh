#!/bin/bash

shopt -s extglob;

source ${SCRIPT_DIR}/functions/formatting.sh
source ${SCRIPT_DIR}/functions/common.sh
source ${SCRIPT_DIR}/functions/certs.ocp.sh
source ${SCRIPT_DIR}/functions/prompts.certs.sh

#=====================================================================================================================
# createNewCertificateTypeScreen - Prompts the user with a menu to select what type of certificate to create
# {1} CA_PATH: The path to the CA to create the certificate at
#=====================================================================================================================
function createNewCertificateTypeScreen {
  local CA_PATH=${1}
  local CA_CN=$(getCertificateCommonName "${CA_PATH}/certs/ca.cert.pem")
  local CA_TYPE=$(getCAType ${CA_PATH})

  clear
  echoBanner "[${CA_TYPE}] ${CA_CN} - Certificate Creation, Type Selection"
  echo "===== CA Path: $(getPKIPath ${CA_PATH})"

  echo "- Creating a new certificate..."
  local CERT_OPTIONS='Server Certificate\nClient Certificate\nOpenShift API Certificate\nOpenShift Ingress Certificate\nOpenShift Combo Certificate (API & Ingress)'
  local CERT_CHOICE=$(echo -e "${CERT_OPTIONS}" | gum choose)
  if [ -z "$CERT_CHOICE" ]; then
    echo "No Certificate Type selected.  Exiting..."
    exit 1
  fi
  
  case $CERT_CHOICE in
    "Server Certificate")
      createServerCertificateInputScreen "${CA_PATH}"
      ;;
    "Client Certificate")
      echo "Not implemented yet."
      ;;
    "OpenShift API Certificate")
      createOpenshiftAPICertificateInputScreen "${CA_PATH}"
      ;;
    "OpenShift Ingress Certificate")
      createOpenshiftIngressCertificateInputScreen "${CA_PATH}"
      ;;
    "OpenShift Combo Certificate (API & Ingress)")
      createOpenshiftComboCertificateInputScreen "${CA_PATH}"
      ;;
    *)
      echo "Invalid selection.  Exiting..."
      exit 1
      ;;
  esac
}

#=====================================================================================================================
# createServerCertcreateServerCertificateInputScreenficate - Prompts the user for information to create a new server certificate
#=====================================================================================================================
function createServerCertificateInputScreen {
  # Input variable assignments and inheritance information
  local PARENT_CA_PATH=${1}
  local PARENT_CA_NAME=$(getCertificateCommonName "${PARENT_CA_PATH}/certs/ca.cert.pem")
  local PARENT_CA_TYPE=$(getCAType ${PARENT_CA_PATH})

  # Header
  clear
  echoBanner "[${PARENT_CA_TYPE}] ${PARENT_CA_NAME} - Server Certificate Creation"
  echo "===== CA Path: $(getPKIPath ${PARENT_CA_PATH})"

  # Input prompts
  local SERVER_CERT_NAME=$(promptNewServerCertificateName)
  local SERVER_CERT_DNS_SAN=$(promptNewServerCertificateDNSSAN)
  local SERVER_CERT_COUNTRY_CODE=$(promptNewServerCertificateCountryCode)
  local SERVER_CERT_STATE=$(promptNewServerCertificateState)
  local SERVER_CERT_LOCALITY=$(promptNewServerCertificateLocality)
  local SERVER_CERT_ORGANIZATION=$(promptNewServerCertificateOrganization)
  local SERVER_CERT_ORGANIZATIONAL_UNIT=$(promptNewServerCertificateOrganizationalUnit)
  local SERVER_CERT_EMAIL=$(promptNewServerCertificateEmail)

  # Format the default DNS SANs
  local SERVER_DNS_SANS_FRIENDLY="DNS:${SERVER_CERT_NAME} (Automatically added)"
  local SERVER_DNS_SANS_FORMATTED="DNS:${SERVER_CERT_NAME}"

  # Set the certificate name and path
  local SERVER_CERT_FILENAME="$(echo "${SERVER_CERT_NAME}" | sed 's/*/wildcard/')"
  local SERVER_CERT_PATH="${PARENT_CA_PATH}/certs/${SERVER_CERT_FILENAME}.cert.pem"

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
    # Prompt for the signing CA's password, save it to a temporary file
    local SIGNING_CA_CERT_PASS=$(gum input --password --prompt "Enter a password for the Signing CA \"${PARENT_CA_NAME}\" Certificate private key: ")
    local PW_FILE=$(mktemp)
    echo ${SIGNING_CA_CERT_PASS} > ${PW_FILE}

    # Create the certificate
    createServerCertificate "${PARENT_CA_PATH}" \
      "${PW_FILE}" \
      "${SERVER_CERT_NAME}" \
      "${SERVER_CERT_FILENAME}" \
      "${SERVER_CERT_COUNTRY_CODE}" \
      "${SERVER_CERT_STATE}" \
      "${SERVER_CERT_LOCALITY}" \
      "${SERVER_CERT_ORGANIZATION}" \
      "${SERVER_CERT_ORGANIZATIONAL_UNIT}" \
      "${SERVER_CERT_EMAIL}" \
      "${SERVER_DNS_SANS_FORMATTED}"

    # Clean up the password file
    rm -f ${PW_FILE}

    # Display the certificate
    viewCertificate ${SERVER_CERT_PATH}
  else
    # User has decided not to create the certificate - return to the CA action selection screen
    selectCAActions "${PARENT_CA_PATH}"
  fi

}

function createServerCertificate {
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
      -extensions server_cert -days 375 -notext -md sha256 \
      ${PASSWD_PARAMS} \
      -batch -in ${SERVER_CSR_PATH} \
      -out ${SERVER_CERT_PATH}

  else
    echo "- Certificate already exists: ${SERVER_CERT_PATH}"
  fi
}

#=======================================================================================================
# selectCertificateActions will display the options for a certificate
# {1} CERT_PATH: The path to the certificate to select
# {2} HEADER_OFF: Whether to display the header or not, defaults to "false"
#=======================================================================================================
function selectCertificateActions {
  local CERT_PATH=${1}
  local HEADER_OFF=${2:-"false"}
  local CERT_CN=$(getCertificateCommonName ${CERT_PATH})
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))
  local CERT_CA_CERT_PATH="${CERT_CA_PATH}/certs/ca.cert.pem"

  if [ "${HEADER_OFF}" == "false" ]; then
    clear
    echoBanner "[Certificate] ${CERT_CN} - Certificate Actions"
    echo "===== CA Path: $(getPKIPath ${CERT_CA_PATH})"
  fi

  #local CERT_OPTIONS='../ Back\n[+] Save Certificate\n[+] View Certificate'
  local CERT_OPTIONS='../ Back\n[+] Save Certificate\n[+] Recreate Certificate\n[+] Rotate Certificate'

  # Check to see if the CA has a CRL
  CA_CRL_CHECK=$(openssl x509 -text -in ${CERT_CA_CERT_PATH} |grep -A4 'CRL Distribution Points' | tail -n1 | sed 's/URI://g' | sed 's/ //g')
  if [ ! -z "${CA_CRL_CHECK}" ]; then
    CERT_OPTIONS=''${CERT_OPTIONS}'\n[+] Revoke Certificate'
  else
    CERT_OPTIONS=''${CERT_OPTIONS}'\n[+] Delete Certificate (CRL not available)'
  fi

  local SELECTED_ACTION=$(echo -e "${CERT_OPTIONS}" | gum choose)
  if [ -z "$SELECTED_ACTION" ]; then
    echo "No action selected, exiting..."
    exit 1
  fi

  case "$SELECTED_ACTION" in
    "../ Back")
      selectCertificateScreen ${CERT_CA_PATH}
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
    "[+] Recreate Certificate")
      recreateCertificateConfirmation ${CERT_PATH}
      ;;
    "[+] Revoke Certificate")
      revokeCertificateConfirmation ${CERT_PATH}
      ;;
    "[+] Rotate Certificate")
      rotateCertificateConfirmation ${CERT_PATH}
      ;;
    *)
      echo "Invalid selection, exiting"
      exit 1
      ;;
  esac
}

#=======================================================================================================
# viewCertificate will display the details of a certificate
# {1} CERT_PATH: The path to the certificate to view
#=======================================================================================================
function viewCertificate {
  local CERT_PATH=${1}
  local CERT_FILENAME=$(basename ${CERT_PATH})
  local CERT_CN=$(getCertificateCommonName ${CERT_PATH})
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))

  clear
  echoBanner "[Certificate] ${CERT_FILENAME} - View Certificate"
  echo "===== CA Path: $(getPKIPath ${CERT_CA_PATH})"

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

#=======================================================================================================
# deleteCertificate will delete a certificate and its associated files
# {1} CERT_PATH: The path to the certificate to delete
#=======================================================================================================
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
  echo "===== CA Path: $(getPKIPath ${CERT_CA_PATH})"

  echo -e "\n====== DANGER ZONE ======\n====== DANGER ZONE ======\n====== DANGER ZONE ======\n"
  echo "Are you sure you want to DELETE the certificate?"

  if gum confirm; then
    sed -i '/[[:blank:]]'${CERT_SERIAL}'[[:blank:]]/d' ${CERT_CA_PATH}/index.txt
    rm -f ${CERT_PATH} ${CSR_PATH} ${KEY_PATH} ${CERT_SERIAL_CERT_PATH}
    echo "Certificate deleted: ${CERT_CN}"
    selectCertificateScreen ${CERT_CA_PATH}
  else
    echo "Certificate deletion cancelled."
    viewCertificate ${CERT_PATH}
  fi
}

#=======================================================================================================
# revokeCertificateConfirmation will prompt the user to revoke a certificate and its associated files
# {1} CERT_PATH: The path to the certificate to revoke
#=======================================================================================================
function revokeCertificateConfirmation {
  local CERT_PATH=${1}
  local CERT_CN=$(getCertificateCommonName ${CERT_PATH})
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))

  clear
  echoBanner "[Certificate] ${CERT_CN} - Revoke Certificate"
  echo "===== CA Path: $(getPKIPath ${CERT_CA_PATH})"

  echo -e "\n====== DANGER ZONE ======\n====== DANGER ZONE ======\n====== DANGER ZONE ======\n"
  echo "Are you sure you want to REVOKE the certificate?"

  if gum confirm; then
    revokeCertificate ${CERT_PATH}
    selectCertificateScreen ${CERT_CA_PATH}
  else
    viewCertificate ${CERT_PATH}
  fi
}

#=======================================================================================================
# revokeCertificate will revoke a certificate and its associated files, with or without a provided password
# {1} CERT_PATH: The path to the certificate to revoke
# {2} CA_PASSWORD: The password for the CA
# {3} REVOKED_FILE_SUFFIX: The suffix to append to the revoked files, defaults to ".revoked-$(date +%s)"
#=======================================================================================================
function revokeCertificate {
  local CERT_PATH=${1}
  local CA_PASSWORD=${2}
  local REVOKED_FILE_SUFFIX=${3:-".revoked-$(date +%s)"}

  local CSR_PATH=$(echo ${CERT_PATH} | sed 's|.cert.pem|.csr.pem|g' | sed 's|certs/|csr/|g')
  local KEY_PATH=$(echo ${CERT_PATH} | sed 's|.cert.pem|.key.pem|g' | sed 's|certs/|private/|g')
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))
  local PASSWD_PARAMS=$(processPasswordParam ${CA_PASSWORD})

  if [ "$(doesCAHaveCRL ${CERT_CA_PATH}/certs/ca.cert.pem)" == "false" ]; then
    echo "No CRL available for the CA, exiting..."
    exit 1
  fi

  # Revoke the certificate
  openssl ca -config ${CERT_CA_PATH}/openssl.cnf \
    ${PASSWD_PARAMS} -revoke ${CERT_PATH}

  # Move files with a suffix
  mv ${CERT_PATH} ${CERT_PATH}${REVOKED_FILE_SUFFIX}
  mv ${CSR_PATH} ${CSR_PATH}${REVOKED_FILE_SUFFIX}
  mv ${KEY_PATH} ${KEY_PATH}${REVOKED_FILE_SUFFIX}

  # Generate a new CRL
  createCRLFile "${CERT_CA_PATH}" "${CA_PASSWORD}"
}

#=======================================================================================================
# Save Certificate Actions
# {1} CERT_PATH: The path to the certificate to save
# {2} HEADER_OFF: Whether to display the header or not, defaults to "false"
#=======================================================================================================
function saveCertificateActions {
  local CERT_PATH=${1}
  local HEADER_OFF=${2:-"false"}
  local CERT_CN=$(getCertificateCommonName ${CERT_PATH})
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))

  if [ "${HEADER_OFF}" == "false" ]; then
    clear
    echoBanner "[Certificate] ${CERT_CN} - Save Certificate Type"
    echo "===== CA Path: $(getPKIPath ${CERT_CA_PATH})"
  fi

  local CERT_OPTIONS='../ Back\n[+] Save Certificate as PKCS#12\n[+] Save Certificate as PEM\n[+] Save HAProxy Bundle'

  local SELECTED_ACTION=$(echo -e "${CERT_OPTIONS}" | gum choose)
  if [ -z "$SELECTED_ACTION" ]; then
    echo "No action selected, exiting..."
    exit 1
  fi

  case "$SELECTED_ACTION" in
    "../ Back")
      viewCertificate ${CERT_PATH}
      ;;
    "[+] Save Certificate as PKCS#12")
      saveCertificateFiles ${CERT_PATH} "pkcs12"
      ;;
    "[+] Save Certificate as PEM")
      saveCertificateFiles ${CERT_PATH} "pem"
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

#=======================================================================================================
# Save Certificate Files
#=======================================================================================================
function saveCertificateFiles {
  local CERT_PATH=${1}
  local SAVE_TYPE=${2}
  local CERT_CN=$(getCertificateCommonName ${CERT_PATH})
  local CERT_CN_SLUG=$(slugify "${CERT_CN}")
  local CERT_KEY_PATH=$(echo ${CERT_PATH} | sed 's|.cert.pem|.key.pem|g' | sed 's|certs/|private/|g')
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))

  clear
  echoBanner "[Certificate] ${CERT_CN} - Save Certificate Bundle"
  echo -e "===== CA Path: $(getPKIPath ${CERT_CA_PATH})\n"
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
  if [ "${SAVE_TYPE}" == "pem" ]; then
    cp ${CERT_PATH} ${SAVE_PATH}/cert.pem
    rm -f ${SAVE_PATH}/key.pem
    cp ${CERT_KEY_PATH} ${SAVE_PATH}/key.pem
    cp ${CERT_CA_PATH}/certs/ca.cert.pem ${SAVE_PATH}/ca.pem

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

#=======================================================================================================
# rotateCertificateConfirmation will prompt the user to rotate a certificate
# {1} CERT_PATH: The path to the certificate to rotate
#=======================================================================================================
function rotateCertificateConfirmation {
  local CERT_PATH=${1}
  local CERT_CN=$(getCertificateCommonName ${CERT_PATH})
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))

  clear
  echoBanner "[Certificate] ${CERT_CN} - Rotate Certificate"
  echo "===== CA Path: $(getPKIPath ${CERT_CA_PATH})"

  echo -e "\n====== DANGER ZONE ======\n====== DANGER ZONE ======\n====== DANGER ZONE ======\n"
  echo "Are you sure you want to ROTATE the certificate?"
  echo "While this is technically a non-destructive action, a new certificate from the existing CSR will be created."

  if gum confirm; then
    rotateCertificate ${CERT_PATH}
  fi

  viewCertificate ${CERT_PATH}
}

#=======================================================================================================
# rotateCertificate will rotate a certificate, and optionally revoke and delete the old certificate
# {1} CERT_PATH: The path to the certificate to rotate
# {2} CA_PASSWORD: The password for the CA
# {3} REVOKE_CERT: Whether to revoke the certificate, defaults to "false"
#=======================================================================================================
function rotateCertificate {
  local CERT_PATH=${1}
  local CA_PASSWORD=${2}
  local REVOKE_CERT=${3:-"false"}

  local PARENT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))
  local CSR_PATH=$(echo ${CERT_PATH} | sed 's|.cert.pem|.csr.pem|g' | sed 's|certs/|csr/|g')
  local KEY_PATH=$(echo ${CERT_PATH} | sed 's|.cert.pem|.key.pem|g' | sed 's|certs/|private/|g')
  local PASSWD_PARAMS=$(processPasswordParam ${CA_PASSWORD})

  # Check if the certificate exists
  if [ ! -f "${CERT_PATH}" ]; then
    echo "Certificate at path ${CERT_PATH} does not exist.  Exiting..."
    exit 1
  fi

  # Backup the certificate components
  local CERT_BACKUP_PATH="${CERT_PATH}.bak-$(date +%s)"
  local KEY_BACKUP_PATH="${KEY_PATH}.bak-$(date +%s)"
  local CSR_BACKUP_PATH="${CSR_PATH}.bak-$(date +%s)"
  cp ${CERT_PATH} ${CERT_BACKUP_PATH}
  cp ${KEY_PATH} ${KEY_BACKUP_PATH}
  cp ${CSR_PATH} ${CSR_BACKUP_PATH}

  if [ "${REVOKE_CERT}" == "false" ]; then
    # Rotate the certificate
    openssl ca -config ${PARENT_CA_PATH}/openssl.cnf \
      -extensions server_cert -days 375 -notext -md sha256 \
      ${PASSWD_PARAMS} \
      -batch -in ${CSR_PATH} \
      -out ${CERT_PATH}
  else
    # Otherwise if we're revoking, we're also deleting the certificate
    local CERT_CN=$(getCertificateCommonName ${CERT_PATH})
    local CERT_ORG=$(getCertificateOrganization ${CERT_PATH})
    local CERT_ORG_UNIT=$(getCertificateOrganizationalUnit ${CERT_PATH})
    local CERT_COUNTRY=$(getCertificateCountry ${CERT_PATH})
    local CERT_STATE=$(getCertificateState ${CERT_PATH})
    local CERT_LOCALITY=$(getCertificateLocality ${CERT_PATH})
    local CERT_EMAIL=$(getCertificateEmail ${CERT_PATH})
    local CERT_SANS=$(getCertificateSANS ${CERT_PATH})

    revokeCertificate "${CERT_PATH}" "${CA_PASSWORD}"
    # Even if it does not have a CRL, we'll delete they key, csr, and cert files
    rm -f ${CERT_PATH} ${CSR_PATH} ${KEY_PATH}

    # Create a new certificate
    createServerCertificate "${PARENT_CA_PATH}" \
      "${CA_PASSWORD}" \
      "${CERT_CN}" \
      "" \
      "${CERT_COUNTRY}" \
      "${CERT_STATE}" \
      "${CERT_LOCALITY}" \
      "${CERT_ORG}" \
      "${CERT_ORG_UNIT}" \
      "${CERT_EMAIL}" \
      "${CERT_SANS}"
  fi
}

#=======================================================================================================
# recreateCertificateConfirmation will prompt the user to recreate a certificate
# {1} CERT_PATH: The path to the certificate to recreate
#=======================================================================================================
function recreateCertificateConfirmation {
  local CERT_PATH=${1}
  local CERT_CN=$(getCertificateCommonName ${CERT_PATH})
  local CERT_CA_PATH=$(dirname $(dirname ${CERT_PATH}))

  clear
  echoBanner "[Certificate] ${CERT_CN} - Recreate Certificate"
  echo "===== CA Path: $(getPKIPath ${CERT_CA_PATH})"

  echo -e "\n====== DANGER ZONE ======\n====== DANGER ZONE ======\n====== DANGER ZONE ======\n"
  echo "Are you sure you want to RECREATE the certificate?"
  echo "This is a DESTRUCTIVE ACTION, existing keys, CSRs, and certificates will be revoked and/or deleted!"

  if gum confirm; then
    # Prompt for the signing CA's password, save it to a temporary file
    local SIGNING_CA_CERT_PASS=$(gum input --password --prompt "Enter a password for the Signing CA \"${PARENT_CA_NAME}\" Certificate private key: ")
    local PW_FILE=$(mktemp)
    echo ${SIGNING_CA_CERT_PASS} > ${PW_FILE}

    rotateCertificate ${CERT_PATH} "${PW_FILE}" "true"

    # Clean up the password file
    rm -f ${PW_FILE}
  fi

  viewCertificate ${CERT_PATH}
}


#=======================================================================================================
# signExternalCSR - Signs an external CSR with the selected CA
#=======================================================================================================
function signExternalCSR {
  local CA_PATH=${1}
  local CSR_FILE=${2}
  local CA_PASSWORD=${3}
  
  local PASSWD_PARAMS=$(processPasswordParam ${CA_PASSWORD})
  local CSR_CN=$(getCSRCommonName ${CSR_FILE})
  local CSR_CN_SLUG=$(slugify "${CSR_CN}")

  local CERT_PATH="${CA_PATH}/certs/${CSR_CN_SLUG}.cert.pem"

  # Generate a server certificate if it does not exist, in either case, display the certificate actions
  if [ ! -f "${CERT_PATH}" ]; then
    echo "- Signing CSR with Certificate Authority..."

    # Create the certificate
    openssl ca -config ${CA_PATH}/openssl.cnf \
      -extensions server_cert -days 375 -notext -md sha256 \
      ${PASSWD_PARAMS} \
      -batch -in ${CSR_FILE} \
      -out ${CERT_PATH}

  else
    echo "- Certificate already exists: ${CERT_PATH}"
  fi
}