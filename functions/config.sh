#!/bin/bash

#==============================================================================
# generateOpenSSLConfFile - Create a new OpenSSL configuration file for a CA.
# $1 - CA Path
# $2 - CA Common Name
# $3 - CA Slug
# $4 - CA Type
# $5 - Country Code
# $6 - State
# $7 - City
# $8 - Organization
# $9 - Organizational Unit
# $10 - Email
# $11 - Days Valid
# $12 - CRL Distribution URI
#==============================================================================
function generateOpenSSLConfFile {
  local CA_PATH=${1}
  local CA_CN=${2}
  local CA_SLUG=${3}
  local CA_TYPE=${4}
  local CA_COUNTRY_CODE=${5}
  local CA_STATE=${6}
  local CA_LOCALITY=${7}
  local CA_ORG=${8}
  local CA_ORG_UNIT=${9}
  local CA_EMAIL=${10}
  local CA_DAYS_VALID=${11}
  local CA_CRL_DIST_URI=${12}

  if [ ! -f ${CA_PATH}/openssl.cnf ]; then
    cat << EOF > ${CA_PATH}/openssl.cnf
# OpenSSL "${CA_CN}" ${CA_TYPE} CA configuration file.
# Copy to ${CA_PATH}/openssl.cnf.

[ ca ]
# 'man ca'
default_ca        = CA_default

[ CA_default ]
# Directory and file locations.
dir               = ${CA_PATH}
certs             = \$dir/certs
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
RANDFILE          = \$dir/private/.rand

# The CA key and CA certificate.
private_key       = \$dir/private/ca.key.pem
certificate       = \$dir/certs/ca.cert.pem

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = ${CA_DAYS_VALID}
preserve          = no
copy_extensions   = copy
policy            = policy_${CA_TYPE}

EOF

    if [ ! -z "${CA_CRL_DIST_URI}" ]; then
      cat << EOF >> ${CA_PATH}/openssl.cnf
# For certificate revocation lists.
crl_dir           = \$dir/crl
crlnumber         = \$dir/crlnumber
crl               = \$dir/crl/ca.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

EOF
    fi

    cat << EOF >> ${CA_PATH}/openssl.cnf

[ policy_root ]
# The root CA should only sign intermediate certificates that match the same Organization.
# See the POLICY FORMAT section of 'man ca'.
countryName             = supplied
stateOrProvinceName     = supplied
localityName            = supplied
organizationName        = supplied
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = supplied

[ policy_intermediate ]
# The intermediate CAs should only sign signing certificates that match.
# See the POLICY FORMAT section of 'man ca'.
countryName             = supplied
stateOrProvinceName     = supplied
localityName            = supplied
organizationName        = supplied
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = supplied

[ policy_signing ]
# Allow the signing CAs to sign a more diverse range of certificates.
# See the POLICY FORMAT section of 'man ca'.
countryName             = supplied
stateOrProvinceName     = supplied
localityName            = supplied
organizationName        = supplied
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = supplied

## TODO: Add a policy for LDAP CAs?

[ req ]
# Options for the 'req' tool ('man req').
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_${CA_TYPE}_ca

[ req_distinguished_name ]
# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

# Optionally, specify some defaults.
countryName_default             = ${CA_COUNTRY_CODE}
stateOrProvinceName_default     = ${CA_STATE}
localityName_default            = ${CA_LOCALITY}
0.organizationName_default      = ${CA_ORG}
organizationalUnitName_default  = ${CA_ORG_UNIT}
emailAddress_default            = ${CA_EMAIL}

[ v3_root_ca ]
# Extensions for a Root CA ('man x509v3_config').
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer:always
basicConstraints        = critical, CA:true
keyUsage                = critical, digitalSignature, cRLSign, keyCertSign
nsComment               = "Pika PKI Generated Root CA Certificate"
$(if [ ! -z "${CA_CRL_DIST_URI}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ v3_intermediate_ca ]
# Extensions for an Intermediate CA ('man x509v3_config').
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer:always
basicConstraints        = critical, CA:true
keyUsage                = critical, digitalSignature, cRLSign, keyCertSign
nsComment               = "Pika PKI Generated Intermediate CA Certificate"
$(if [ ! -z "${CA_CRL_DIST_URI}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ v3_signing_ca ]
# Extensions for a Signing CA ('man x509v3_config').
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer:always
basicConstraints        = critical, CA:true, pathlen:0
keyUsage                = critical, digitalSignature, cRLSign, keyCertSign
nsComment               = "Pika PKI Generated Signing CA Certificate"
$(if [ ! -z "${CA_CRL_DIST_URI}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ v3_ldap_ca ]
# Extensions for a FreeIPA/RH IDM CA ('man x509v3_config').
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer:always
nsComment               = "Pika PKI Generated LDAP CA Certificate"
basicConstraints        = critical, CA:true
keyUsage                = critical, digitalSignature, nonRepudiation, cRLSign, keyCertSign, dataEncipherment, keyEncipherment
extendedKeyUsage        = clientAuth, emailProtection, serverAuth, codeSigning, OCSPSigning, ipsecIKE, timeStamping
$(if [ ! -z "${CA_CRL_DIST_URI}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ user_cert ]
# Extensions for client certificates ('man x509v3_config').
basicConstraints        = CA:FALSE
nsCertType              = client, email
nsComment               = "Pika PKI Generated Client Certificate"
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
keyUsage                = critical, nonRepudiation, digitalSignature, keyEncipherment
issuerAltName           = issuer:copy
extendedKeyUsage        = clientAuth, emailProtection
$(if [ ! -z "${CA_CRL_DIST_URI}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ server_cert ]
# Extensions for server certificates ('man x509v3_config').
basicConstraints        = CA:FALSE
nsCertType              = server
nsComment               = "Pika PKI Generated Server Certificate"
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer:always
keyUsage                = critical, digitalSignature, keyEncipherment
extendedKeyUsage        = serverAuth
issuerAltName           = issuer:copy
$(if [ ! -z "${CA_CRL_DIST_URI}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ openvpn_server_cert ]
# OpenVPN Server Certificate Extensions
basicConstraints        = CA:FALSE
keyUsage                = critical, digitalSignature, dataEncipherment, keyEncipherment
extendedKeyUsage        = critical, serverAuth
subjectKeyIdentifier    = hash
nsCertType              = server
nsComment               = "Pika PKI Generated OpenVPN Server Certificate"
authorityKeyIdentifier  = keyid,issuer:always
issuerAltName           = issuer:copy
$(if [ ! -z "${CA_CRL_DIST_URI}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ openvpn_client_cert ]
# Extensions for client certificates ('man x509v3_config').
basicConstraints        = CA:FALSE
nsCertType              = client
nsComment               = "Pika PKI Generated OpenVPN Client Certificate"
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
keyUsage                = critical, nonRepudiation, digitalSignature, dataEncipherment, keyEncipherment
issuerAltName           = issuer:copy
extendedKeyUsage        = clientAuth
$(if [ ! -z "${CA_CRL_DIST_URI}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ ocsp ]
# Extension for OCSP signing certificates ('man ocsp').
basicConstraints        = CA:FALSE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
keyUsage                = critical, digitalSignature
extendedKeyUsage        = critical, OCSPSigning

EOF

    if [ ! -z "${CA_CRL_DIST_URI}" ]; then
      cat << EOF >> ${CA_PATH}/openssl.cnf
[ crl_ext ]
# Extension for CRLs ('man x509v3_config').
authorityKeyIdentifier  = keyid:always
issuerAltName           = issuer:copy

[ crl_dist ]
# CRL Download address for the ${CA_TYPE} CA
fullname                = URI:${CA_CRL_DIST_URI}/crls/${CA_TYPE}-ca.${CA_SLUG}.crl

EOF
    fi
  fi
}