# Installation

There are two options to install `hickory-dns`. Either install `hickory-dns` via `cargo` using

```shell
cargo install hickory-dns --features=recursor,dnssec-openssl
```

or build it from source

```shell
cargo build --package hickory-dns --features=recursor,dnssec-openssl
```

Hickory uses [Cargo features](https://doc.rust-lang.org/cargo/reference/features.html) to enable or disable certain functionalities. Alternatively use feature `dnssec-ring` to use the cryptographic library `ring` instead of OpenSSL.

The `recursor` feature allows Hickory to run as a recursive resolver, for example to activate DNSSEC validation.

The list of features is explained in Hickory's [Readme](https://github.com/hickory-dns/hickory-dns/?tab=readme-ov-file#using-as-a-dependency-and-custom-features).
