FROM docker.io/fedora:latest

USER 1001
COPY . /app
USER 0

RUN cp /app/charm.repo /etc/yum.repos.d/charm.repo \
 && rpm --import https://repo.charm.sh/yum/gpg.key \
 && dnf install -y openssl gum ncurses tree sed grep

USER 1001

WORKDIR /data
ENV TERM xterm-256color

CMD "/app/pika-pki.sh"