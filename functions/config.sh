#!/bin/bash

#generateOpenSSLConfFile "$ROOT_CA_PATH" root "$ROOT_CA_COUNTRY_CODE" "$ROOT_CA_STATE" "$ROOT_CA_CITY" "$ROOT_CA_ORG" "$ROOT_CA_ORG_UNIT" "$ROOT_CA_EMAIL" $ROOT_CA_DAYS_VALID $ROOT_CA_CRL_DIST_URI
function generateOpenSSLConfFile {
  if [ ! -f ${1}/openssl.cnf ]; then
    cat << EOF > ${1}/openssl.cnf
# OpenSSL ${2} CA configuration file.
# Copy to ${1}/openssl.cnf.

[ ca ]
# 'man ca'
default_ca        = CA_default

[ CA_default ]
# Directory and file locations.
dir               = ${1}
certs             = \$dir/certs
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
RANDFILE          = \$dir/private/.rand

# The CA key and CA certificate.
private_key       = \$dir/private/ca.key.pem
certificate       = \$dir/certs/ca.cert.pem

EOF

    if [ ! -z "${10}" ]; then
      cat << EOF >> ${1}/openssl.cnf
# For certificate revocation lists.
crl_dir           = \$dir/crl
crlnumber         = \$dir/crlnumber
crl               = \$dir/crl/${2}.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

EOF
    fi

    cat << EOF >> ${1}/openssl.cnf
# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = ${9}
preserve          = no
copy_extensions   = copy
policy            = policy_${2}

[ policy_root ]
# The root CA should only sign intermediate certificates that match.
# See the POLICY FORMAT section of 'man ca'.
countryName             = supplied
stateOrProvinceName     = supplied
localityName            = supplied
organizationName        = match
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

[ req ]
# Options for the 'req' tool ('man req').
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_${2}_ca

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
countryName_default             = ${3}
stateOrProvinceName_default     = ${4}
localityName_default            = ${5}
0.organizationName_default      = ${6}
organizationalUnitName_default  = ${7}
emailAddress_default            = ${8}

[ v3_root_ca ]
# Extensions for a Root CA ('man x509v3_config').
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints        = critical, CA:true
keyUsage                = critical, digitalSignature, cRLSign, keyCertSign
#crlDistributionPoints   = crl_dist
$(if [ ! -z "${10}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ v3_intermediate_ca ]
# Extensions for an Intermediate CA ('man x509v3_config').
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints        = critical, CA:true
keyUsage                = critical, digitalSignature, cRLSign, keyCertSign
#crlDistributionPoints   = crl_dist
$(if [ ! -z "${10}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ v3_signing_ca ]
# Extensions for a Signing CA ('man x509v3_config').
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints        = critical, CA:true, pathlen:0
keyUsage                = critical, digitalSignature, cRLSign, keyCertSign
#crlDistributionPoints   = crl_dist
$(if [ ! -z "${10}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ v3_ldap_ca ]
# Extensions for a FreeIPA/RH IDM CA ('man x509v3_config').
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints        = critical, CA:true
keyUsage                = critical, digitalSignature, nonRepudiation, cRLSign, keyCertSign, dataEncipherment, keyEncipherment
extendedKeyUsage        = clientAuth, emailProtection, serverAuth, codeSigning, OCSPSigning, ipsecIKE, timeStamping
#crlDistributionPoints   = crl_dist
$(if [ ! -z "${10}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ user_cert ]
# Extensions for client certificates ('man x509v3_config').
basicConstraints        = CA:FALSE
nsCertType              = client, email
nsComment               = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
keyUsage                = critical, nonRepudiation, digitalSignature, keyEncipherment
issuerAltName           = issuer:copy
extendedKeyUsage        = clientAuth, emailProtection
#crlDistributionPoints   = crl_dist
$(if [ ! -z "${10}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ server_cert ]
# Extensions for server certificates ('man x509v3_config').
basicConstraints        = CA:FALSE
nsCertType              = server
nsComment               = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer:always
keyUsage                = critical, digitalSignature, keyEncipherment
extendedKeyUsage        = serverAuth
issuerAltName           = issuer:copy
#crlDistributionPoints   = crl_dist
$(if [ ! -z "${10}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ openvpn_server_cert ]
# OpenVPN Server Certificate Extensions
basicConstraints        = CA:FALSE
keyUsage                = critical, digitalSignature, dataEncipherment, keyEncipherment
extendedKeyUsage        = critical, serverAuth
subjectKeyIdentifier    = hash
nsCertType              = server
nsComment               = "OpenSSL Generated OpenVPN Server Certificate"
authorityKeyIdentifier  = keyid,issuer:always
issuerAltName           = issuer:copy
#crlDistributionPoints   = crl_dist
$(if [ ! -z "${10}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ openvpn_client_cert ]
# Extensions for client certificates ('man x509v3_config').
basicConstraints        = CA:FALSE
nsCertType              = client
nsComment               = "OpenSSL Generated OpenVPN Client Certificate"
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
keyUsage                = critical, nonRepudiation, digitalSignature, dataEncipherment, keyEncipherment
issuerAltName           = issuer:copy
extendedKeyUsage        = clientAuth
#crlDistributionPoints   = crl_dist
$(if [ ! -z "${10}" ]; then echo "crlDistributionPoints   = crl_dist"; fi)

[ ocsp ]
# Extension for OCSP signing certificates ('man ocsp').
basicConstraints        = CA:FALSE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
keyUsage                = critical, digitalSignature
extendedKeyUsage        = critical, OCSPSigning

EOF

    if [ ! -z "${10}" ]; then
      cat << EOF >> ${1}/openssl.cnf
[ crl_ext ]
# Extension for CRLs ('man x509v3_config').
authorityKeyIdentifier  = keyid:always
issuerAltName           = issuer:copy

[ crl_dist ]
# CRL Download address for the ${2} CA
fullname                = URI:${10}

EOF
    fi
  fi
}