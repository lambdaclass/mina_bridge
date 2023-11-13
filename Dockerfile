FROM debian:latest

RUN apt-get update \
    && apt-get install -y ocaml opam curl golang libbz2-dev capnproto \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

WORKDIR /app
