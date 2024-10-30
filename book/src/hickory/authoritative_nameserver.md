# Authoritative Name server

Hickory DNS can be configured as an [authoritative name server](https://en.wikipedia.org/wiki/Name_server#Authoritative_name_server).
This type of name server has authoritty over its own zones and can answer queries for which it is responsible.

## Setup

Either install `hickory-dns` via `cargo` using

```shell
cargo install hickory-dns --features=dnssec-openssl
```

or build it from source

```shell
cargo build --package hickory-dns --features=dnssec-openssl
```

Hickory uses [Cargo features](https://doc.rust-lang.org/cargo/reference/features.html) to enable or disable certain functionalities. Alternatively use feature `dnssec-ring` to use the cryptographic library `ring` instead of OpenSSL.


## Configuration



