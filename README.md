# Pika PKI

Pika PKI is a PKI management Text User Interface (TUI).  It's built using [gum](https://github.com/charmbracelet/gum?tab=readme-ov-file), which is a dependency.

<table style="border:none"><tbody><tr><td style="border:none"><center><img width="200" alt="Pika PKI Logo, a picture of a lock with a lightning bolt as the keyhole" src="./pika-pki-logo.png" /></center></td><td style="border:none">

- Create multiple Root Certificate Authorities
- Define your PKI Chain however you want with Intermediate CAs and Signing CAs
- Sign certificates anywhere along the chain
- Built on standard OpenSSL commands and configurations
- Easily create certificates bundles for HAProxy, OpenShift, and more

</td></tr></tbody></table>

## Dependencies

- [Gum](https://github.com/charmbracelet/gum)
- OpenSSL
- ncurses
- grep
- sed
- tree

Or, just Docker/Podman.

## Getting Started

### The Old Fashioned Way

1. [Install gum](https://github.com/charmbracelet/gum?tab=readme-ov-file#installation) and above other dependencies.
2. Clone this repo `git clone https://github.com/kenmoini/pika-pki`
3. Enter the directory `cd pika-pki`
4. Run `./pika-pki`
5. ???????
6. ***PROFIT!!!!!!1***

### The Cloud Native Containers-for-everything Way

```bash
# Create a directory to store the PKI assets
mkdir pika-pki

# Run the container???
podman run --rm -it -v ./pika-pki:/data:Z quay.io/kenmoini/pika-pki:latest
```

## Concepts

- You can create as many Root Certificate Authorities as you want
- There can be any number of Intermediate CAs under a Root CA or other Intermediate CAs
- Signing CAs denote the last CA in the chain - it cannot sign Certificates for a subordinate CA
- Any CA along the chain can sign Certificates of any sort, but it's best to leave that to a Signing CA at the end of the chain
- The Workspace directory stores all the assets for the PKI - in that directory structure you will find a `public_bundles` folder with a set of subdirectories called `certs` and `crls`.  This is where public Certificates like CA Certificates and CRLs will be stored.  You should be able to copy or symlink the path to where a web server can host those assets.

## Optional Parameters

To override some default behavior you can override some parameters via Environmental Variables.

| Variable | Default | Note |
|----------|---------|------|
| PIKA_PKI_DIR | `$(pwd)/.pika-pki` | Workspace directory - where PKI assets are stored |
| PIKA_PKI_DEFAULT_ORG | `""` | Will provide a default answer for the questions asking for an Organization |
| PIKA_PKI_DEFAULT_ORGUNIT | `""` | Will provide a default answer for the questions asking for an Organization Unit |
| PIKA_PKI_DEFAULT_COUNTRY | `""` | Will provide a default answer for the questions asking for a Country |
| PIKA_PKI_DEFAULT_STATE | `""` | Will provide a default answer for the questions asking for a State |
| PIKA_PKI_DEFAULT_LOCALITY | `""` | Will provide a default answer for the questions asking for a Locaity  |
| PIKA_PKI_DEFAULT_EMAIL | `""` | Will provide a default answer for the questions asking for an email address |
| PIKA_PKI_CERT_KEY_ENCRYPTION | `"false"` | By default non-CA leaf certificates do not encrypt their private keys - set to `true` to password encrypt certificate keys |

## Advanced Usage

### Certificate Revokation Lists

When creating a Certificate Authority, you will be prompted for an optional parameter, "CRL URI Root".  This is the base path where the CRL will be served for clients to query revoked certificates.

You should provide the base URI to where a public server is available - eg if you provide `https://ca.example.com/public` then the CRL will be configured and presented as `https://ca.example.com/public/crls/root-ca.my-root-ca.crl`.

The format is `${URI_ROOT}/crls/${CA_TYPE}-ca.${CA_CN_SLUG}.crl`.

If you'd like the CRL to be hosted on a different path, then modify the default OpenSSL Configuration.

### Overriding OpenSSL Configuration

The default configuration can be found in `functions/config.sh`.  There is some logic and templating involved which is why it is embedded in a Bash script.

To override these defaults, create a folder called `overrides` in this directory, copy the `functions/config.sh` file into it, and modify as needed.

## TODO

- CRL Rotation
- CRL Distribution
- CA Distribution
- Proper GitHub software releases?
- Signing of externally generated CSRs
