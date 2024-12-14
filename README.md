# Pika PKI

Pika PKI is a PKI management Text User Interface (TUI).  It's built using [gum](https://github.com/charmbracelet/gum?tab=readme-ov-file), which is a dependency.

<table border="0"><tbody><tr><td><center><img width="200" alt="Pika PKI Logo, a picture of a lock with a lightning bolt as the keyhole" src="./pika-pki-logo.png" /></center></td><td>

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

### The Cloud Native Containers-for-everything Wway

```bash
# Create a directory to store the PKI assets
mkdir pika-pki

# Run the container???
podman run --rm -it -v ./pika-pki:/data:Z quay.io/kenmoini/pika-pki:latest
```

## Optional Parameters

To override some default behavior you can override some parameters via Environmental Variables.

| Variable | Default | Note |
|----------|---------|------|
| PIKA_PKI_DIR | `$(pwd)/.pika-pki` | By Default all assets will be created in a dot directory under the local execution directory |
| PIKA_PKI_DEFAULT_ORG | `""` | Will provide a default answer for the questions asking for an Organization |
| PIKA_PKI_DEFAULT_OU | `""` | Will provide a default answer for the questions asking for an Organization Unit |
| PIKA_PKI_DEFAULT_COUNTRY | `""` | Will provide a default answer for the questions asking for a Country |
| PIKA_PKI_DEFAULT_STATE | `""` | Will provide a default answer for the questions asking for a State |
| PIKA_PKI_DEFAULT_LOCALITY | `""` | Will provide a default answer for the questions asking for a Locaity  |
| PIKA_PKI_DEFAULT_EMAIL | `""` | Will provide a default answer for the questions asking for an email address |
| PIKA_PKI_CERT_KEY_ENCRYPTION | `"false"` | By default non-CA leaf certificates do not encrypt their private keys - set to `true` to password encrypt certificate keys |

## TODO

- CRL Rotation
- CRL Distribution
- Proper GitHub software releases?
