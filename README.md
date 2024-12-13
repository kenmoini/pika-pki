# Pika PKI

Pika PKI is a PKI management Text User Interface.  It's built using [gum](https://github.com/charmbracelet/gum?tab=readme-ov-file), which is a dependency.

## Dependencies

- [Gum](https://github.com/charmbracelet/gum)
- OpenSSL
- grep
- sed

## Getting Started

1. [Install gum](https://github.com/charmbracelet/gum?tab=readme-ov-file#installation).
2. Run `./pika-pki`

## Optional Parameters

To override some default behavior you can override some parameters via Environmental Variables.


| Variable | Default | Note |
|----------|---------|------|
| PIKA_PKI_DIR | `$(pwd)/.pika-pki` | By Default all assets will be created in a dot directory under the local execution directory |
