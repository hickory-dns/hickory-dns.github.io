+++
title = "Hickory DNS"
description = "A memory-safe DNS server and DNS libraries, written in Rust: authoritative server, recursive and stub resolvers, DNSSEC, and encrypted DNS transports."

[extra]
headline = "Memory-safe DNS, written in Rust"
lede = "Hickory DNS provides a stub resolver, a recursive resolver and an authoritative server and a set of Rust libraries for everything from parsing a DNS message to resolving a name. It is open source and extensively tested."

[[extra.highlights]]
title = "Memory safe"
body = "Message parsing, zone handling and resolution are written in safe Rust, removing whole classes of vulnerabilities that have long affected DNS software written in C."

[[extra.highlights]]
title = "Encrypted transports"
body = "DNS over TLS, HTTPS, QUIC and HTTP/3, for both serving and resolving, built on [rustls](https://github.com/rustls/rustls) with your choice of *aws-lc-rs* or *ring* for cryptography."

[[extra.highlights]]
title = "DNSSEC"
body = "Validation back to the root trust anchor, including authenticated denial of existence with NSEC and NSEC3. The server can sign zones online and re-sign them on every update."

[[extra.highlights]]
title = "Portable"
body = "Runs on Linux, macOS, Windows and Android, using each platform's native resolver configuration. The protocol crate also works in `no_std` environments and WebAssembly."

[[extra.highlights]]
title = "Extensively tested"
body = "Extensive coverage via unit tests, integration tests and conformance tests help improve reliability and correctness of the implementation."

[[extra.highlights]]
title = "Permissively licensed"
body = "Dual-licensed under MIT and Apache 2.0, so it fits in commercial products and other open source projects alike."

[extra.server]
title = "Run a DNS server"
intro = "The `hickory-dns` binary is a single, self-contained server configured [with one TOML file](config/). Run it as an authoritative name server, a resolver, or both at once."

[[extra.server.features]]
title = "Authoritative"
body = "Serve primary and secondary zones from standard zone files or from SQLite, with zone transfers under your control."

[[extra.server.features]]
title = "Dynamic updates"
body = "Accept updates authenticated with TSIG or SIG(0), journaled to SQLite and re-signed automatically when DNSSEC is on."

[[extra.server.features]]
title = "Recursive resolver"
body = "Resolve from the root servers with DNSSEC validation, per-type cache policies, and opportunistic encryption to authoritative servers."

[[extra.server.features]]
title = "Forwarder"
body = "Forward queries to upstream resolvers over plain or encrypted transports, with caching."

[[extra.server.features]]
title = "Blocklists and access control"
body = "Filter names with blocklists, and allow or deny clients by network."

[[extra.server.features]]
title = "Easy to operate"
body = "Prometheus metrics, systemd integration, privilege dropping after binding ports, and a [Docker image](https://github.com/hickory-dns/docker)."

[extra.libraries]
title = "Build with the libraries"
intro = "Every part of the server is a library you can use on its own. The crates are async and built on Tokio, and each optional protocol or dependency sits behind a Cargo feature."
note = "Android uses `hickory-proto` to [parse DNS responses in the firmware of the Pixel 10](https://blog.google/security/bringing-rust-to-the-pixel-baseband/)."

[[extra.libraries.crates]]
name = "hickory-resolver"
title = "Stub resolver"
body = "An in-process replacement for the system resolver. Reads the system configuration on Unix, macOS, Windows and Android; prefers the fastest upstream name servers. DNSSEC validation and encrypted transports are optional features."

[[extra.libraries.crates]]
name = "hickory-resolver"
feature = "recursor"
title = "Recursive resolver"
body = "Full iterative resolution starting from the root servers, with DNSSEC validation, for applications that need answers without trusting an upstream resolver."

[[extra.libraries.crates]]
name = "hickory-server"
title = "Server framework"
body = "The building blocks of `hickory-dns`: listeners for every transport, plus zone handlers for authoritative data, forwarding, recursion and blocklists, or your own."

[[extra.libraries.crates]]
name = "hickory-proto"
title = "Protocol"
body = "DNS message encoding and decoding and a wide range of record types. Supports `no_std`."

[[extra.libraries.crates]]
name = "hickory-net"
title = "Transports"
body = "Asynchronous DNS clients and connections over UDP, TCP, TLS, HTTPS, QUIC and HTTP/3."
+++
