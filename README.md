# Pika PKI

Pika PKI is a PKI management Text User Interface.  It's built using [gum](https://github.com/charmbracelet/gum?tab=readme-ov-file), which is a dependency.

## Dependencies

- [Gum](https://github.com/charmbracelet/gum)
- OpenSSL
- grep
- sed

## Getting Started

1. [Install gum](https://github.com/charmbracelet/gum?tab=readme-ov-file#installation).
2. Clone this repo `git clone https://github.com/kenmoini/pika-pki`
3. Enter the directory `cd pika-pki`
4. Run `./pika-pki`
5. ???????
6. *PROFIT!!!!!!1*

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
