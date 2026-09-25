+++
title = "Configuring the server"
description = "How to configure the hickory-dns server with TOML: listeners, authoritative zones, dynamic updates, DNSSEC, encrypted transports, forwarding, recursion and blocklists."

[extra]
applies_to = "This guide is for the **0.26.x** releases of `hickory-dns` only. Configuration options differ between releases, and settings shown here may be rejected by other versions."
+++

The `hickory-dns` server reads a single TOML file. The examples on this page are taken from the [test configurations](https://github.com/hickory-dns/hickory-dns/tree/release/0.26/tests/test-data/test_configs) on the `release/0.26` branch.

## Running the server

Several server roles and all encrypted transports are optional Cargo features. The default build includes authoritative zones, SQLite storage and the forwarder. Add the features you need when installing:

```sh
cargo install hickory-dns --features recursor,blocklist,dnssec-aws-lc-rs,https-aws-lc-rs,quic-aws-lc-rs
```

| Feature | Enables |
| --- | --- |
| `resolver` (default) | Forwarding to upstream resolvers |
| `sqlite` (default) | SQLite-backed zones and dynamic updates |
| `recursor` | Recursive resolution from the root servers |
| `blocklist` | Blocking names from domain lists, answering with a sinkhole address instead of resolving them |
| `dnssec-aws-lc-rs` or `dnssec-ring` | DNSSEC signing and validation, and TSIG authentication for zone transfers and updates |
| `tls-aws-lc-rs` or `tls-ring` | DNS over TLS |
| `https-aws-lc-rs` or `https-ring` | DNS over HTTPS (includes TLS) |
| `quic-aws-lc-rs` or `quic-ring` | DNS over QUIC (includes TLS) |
| `prometheus-metrics` | A Prometheus metrics endpoint |

Point the server at a configuration file and, optionally, a directory for zone files:

```sh
hickory-dns --config /etc/named.toml --zonedir /var/named
```

Use `--validate` to check a configuration without starting the server. Command line options such as `--port` and `--zonedir` take precedence over the values in the file.

## Listeners and general settings

All top-level settings are optional. These are the defaults:

```toml
listen_addrs_ipv4 = ["0.0.0.0"]
listen_addrs_ipv6 = ["::0"]
listen_port = 53

## Close idle TCP connections after this many seconds; 0 disables the timeout.
tcp_request_timeout = 5

## Zone files and other relative paths are resolved against this directory.
directory = "/var/named"
```

When started as root on Unix-like systems, the server binds its ports and then switches to the `user` and `group` you configure, or to `nobody` if you set neither. Set `drop_privileges = false` in containers where `/etc/passwd` is not available.

Individual protocols can be turned off with `disable_udp`, `disable_tcp`, `disable_tls`, `disable_https` and `disable_quic`.

### Restricting clients

`allow_networks` and `deny_networks` take lists of IPv4 or IPv6 networks in CIDR notation. With only an allow list, every other client is refused:

```toml
## Only local clients may query this server.
allow_networks = ["127.0.0.0/8", "::1/128"]
```

With only a deny list, clients in those networks are refused and everyone else is served. When a client matches both lists, the more specific entry wins, so an allow entry can carve an exception out of a larger denied network:

```toml
deny_networks = ["127.0.0.0/8"]
allow_networks = ["127.0.0.1/32"]
```

IPv4 and IPv6 are evaluated separately: an allow list containing only IPv4 networks does not restrict IPv6 clients.

## Authoritative zones

Each `[[zones]]` table declares one zone. For an authoritative zone, set `zone_type = "Primary"` and point `file` at a standard zone file, relative to `directory`:

```toml
[[zones]]
## The zone origin; a trailing '.' is implied.
zone = "example.com"
zone_type = "Primary"
file = "example.com.zone"

## Zone transfers are refused unless allowed here:
## "Deny" (default), "AllowAll", or "AllowSigned" (requires a valid TSIG signature).
axfr_policy = "Deny"
```

`AllowSigned` requires a `dnssec-*` feature. It also only works for zones stored in SQLite, because TSIG keys are configured on the SQLite store (see [dynamic updates](#dynamic-updates-with-sqlite)).

Most name servers should also serve the local zones for `localhost` and the loopback, broadcast and unspecified reverse zones. The repository's [`default/`](https://github.com/hickory-dns/hickory-dns/tree/release/0.26/tests/test-data/test_configs/default) directory has zone files for these:

```toml
[[zones]]
zone = "localhost"
zone_type = "Primary"
file = "default/localhost.zone"

[[zones]]
zone = "0.0.127.in-addr.arpa"
zone_type = "Primary"
file = "default/127.0.0.1.zone"

[[zones]]
zone = "0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa"
zone_type = "Primary"
file = "default/ipv6_1.zone"

[[zones]]
zone = "255.in-addr.arpa"
zone_type = "Primary"
file = "default/255.zone"

[[zones]]
zone = "0.in-addr.arpa"
zone_type = "Primary"
file = "default/0.zone"
```

The full annotated example is [`example.toml`](https://github.com/hickory-dns/hickory-dns/blob/release/0.26/tests/test-data/test_configs/example.toml).

## Dynamic updates with SQLite

To accept updates, store the zone in SQLite instead of a plain file. The zone file seeds the database on first start; after that, the journal is the source of truth.

```toml
[[zones]]
zone = "example.com"
zone_type = "Primary"

[zones.stores]
type = "sqlite"
zone_path = "example.com.zone"
journal_path = "example.com_dnssec_update.jrnl"
allow_update = true
```

The SQLite store reads the zone file from its own `zone_path`, so leave out the zone-level `file` key used for [plain zone files](#authoritative-zones). If both are set, the server also loads `file` as a second store for the same zone. The SQLite store answers every query first, so that copy is never used, and edits to it have no effect.

Updates must be signed with TSIG, which requires a `dnssec-*` feature. List the keys that may update the zone; unsigned updates are refused. With `axfr_policy = "AllowSigned"`, the same keys also authenticate zone transfers:

```toml
[[zones.stores.tsig_keys]]
name = "update-key"
## Raw (not base64-encoded) HMAC key bytes.
key_file = "tsig_update.key"
algorithm = "hmac-sha256"
## Allowed clock difference in seconds; 300 is the default.
fudge = 300
```

These examples are based on [`dnssec_with_update.toml`](https://github.com/hickory-dns/hickory-dns/blob/release/0.26/tests/test-data/test_configs/dnssec_with_update.toml).

## Signing zones with DNSSEC

Adding one or more `[[zones.keys]]` entries to a primary zone turns on online signing. With a SQLite store, records are re-signed after every update.

```toml
[[zones]]
zone = "example.com"
zone_type = "Primary"
file = "example.com.zone"

[[zones.keys]]
key_path = "/etc/hickory/keys/example.com.ecdsa_p256.pk8"
algorithm = "ECDSAP256SHA256"
```

The supported algorithms are `RSASHA256`, `RSASHA512`, `ECDSAP256SHA256`, `ECDSAP384SHA384` and `ED25519`. Keys are private keys in PKCS#8 form, either PEM or DER encoded; RSA keys may also be PKCS#1 PEM. Unlike zone files, `key_path` is not resolved against `directory`, so use an absolute path.

By default, the zone proves that names do not exist using NSEC. To use NSEC3 instead, set `nx_proof_kind`:

```toml
nx_proof_kind = { nsec3 = { iterations = 0 } }
```

These examples are based on [`all_supported_dnssec.toml`](https://github.com/hickory-dns/hickory-dns/blob/release/0.26/tests/test-data/test_configs/all_supported_dnssec.toml).

## Encrypted transports

DNS over TLS, HTTPS and QUIC share a single certificate. The server listens on each protocol that was compiled in, as soon as `tls_cert` is set:

```toml
[tls_cert]
## PEM file with the certificate chain.
path = "sec/example.cert.pem"
## PKCS#8 private key, PEM (.pem) or DER (.der or .key).
private_key = "sec/example.key"
endpoint_name = "ns.example.com"
```

The certificate must be a `.pem` file. The default ports and path can be changed:

```toml
tls_listen_port = 853
https_listen_port = 443
quic_listen_port = 853
http_endpoint = "/dns-query"
```

## Forwarding to upstream resolvers

A forwarder is an `External` zone with a `forward` store. Use `zone = "."` to forward every query, or a narrower name to forward only that part of the tree.

```toml
[[zones]]
zone = "."
zone_type = "External"

[zones.stores]
type = "forward"

[[zones.stores.name_servers]]
ip = "8.8.8.8"
trust_negative_responses = false
connections = [
    { protocol = { type = "udp" } },
    { protocol = { type = "tcp" } },
]

[zones.stores.options]
timeout = 20
positive_max_ttl = 3600
negative_max_ttl = 3600
edns_payload_len = 1232
```

With the TLS feature enabled, upstream connections can be encrypted, for example `{ protocol = { type = "tls", server_name = "dns.google" } }`. A `port` can be given for each connection; otherwise it defaults to the protocol's standard port.

To drop upstream answers that point into particular networks, such as private address space, set `deny_answers` in `options`. Entries in `allow_answers` override it:

```toml
allow_answers = ["192.168.1.1/32"]
deny_answers = ["10.0.0.0/8", "172.16.0.0/12", "192.168.1.0/24"]
```

Based on [`example_forwarder.toml`](https://github.com/hickory-dns/hickory-dns/blob/release/0.26/tests/test-data/test_configs/example_forwarder.toml).

## Recursive resolution

With the `recursor` feature, an `External` zone with a `recursor` store resolves names iteratively, starting from the root servers listed in a root hints file such as [`root.zone`](https://github.com/hickory-dns/hickory-dns/blob/release/0.26/tests/test-data/test_configs/default/root.zone).

```toml
[[zones]]
zone = "."
zone_type = "External"

[zones.stores]
type = "recursor"
roots = "default/root.zone"
ns_cache_size = 1024
response_cache_size = 1048576
recursion_limit = 24
ns_recursion_limit = 24
edns_payload_len = 1232

## "Strict" (default) or "Relaxed". Relaxed continues when an
## empty non-terminal returns NXDOMAIN.
qname_minimization = "Strict"

## Randomize the case of query names over UDP to make spoofing harder.
case_randomization = true

## Cap how long answers are cached, overall and per record type.
[zones.stores.cache_policy.default]
positive_max_ttl = 86400

[zones.stores.cache_policy.A]
positive_max_ttl = 3600

[zones.stores.cache_policy.AAAA]
positive_max_ttl = 3600
```

### Which servers the recursor will query

The recursor refuses to send queries to loopback, private, link-local, documentation and other special-purpose networks. Setting `deny_server` replaces that built-in list, and `allow_server` makes exceptions to it:

```toml
deny_server = ["0.0.0.0/8", "127.0.0.0/8", "::/128", "::1/128"]
allow_server = ["127.0.0.254/32"]
```

`allow_answers` and `deny_answers` filter the addresses in answers, as they do for the forwarder.

### DNSSEC validation

With a DNSSEC feature enabled, the recursor can validate answers from the root trust anchor down. Answers that fail validation get a SERVFAIL response.

```toml
[zones.stores.dnssec_policy.ValidateWithStaticKey]
## A custom trust anchor file; the built-in root anchor is used if omitted.
# path = "/etc/hickory/trust-anchor.key"
nsec3_soft_iteration_limit = 100
nsec3_hard_iteration_limit = 500
validation_cache_size = 1048576
```

Negative answers whose NSEC3 records use more iterations than the soft limit are treated as insecure; above the hard limit they are bogus.

### Opportunistic encryption

With the TLS or QUIC feature, the recursor can probe authoritative servers for encrypted transports as described in [RFC 9539](https://www.rfc-editor.org/rfc/rfc9539), and prefer them once discovered. Enable it with the defaults using `opportunistic_encryption = { enabled = {} }` in the store, or tune it:

```toml
[zones.stores.opportunistic_encryption.enabled]
## Seconds to remember a working encrypted transport.
persistence_period = 259200
## Seconds to wait before retrying a server whose probe failed.
damping_period = 86400
max_concurrent_probes = 10
## Save what was learned to disk every 600 seconds, and reload it on start.
persistence = { path = "opp_enc_state.toml", save_interval = 600 }
```

Based on [`example_recursor.toml`](https://github.com/hickory-dns/hickory-dns/blob/release/0.26/tests/test-data/test_configs/example_recursor.toml), [`example_recursor_dnssec.toml`](https://github.com/hickory-dns/hickory-dns/blob/release/0.26/tests/test-data/test_configs/example_recursor_dnssec.toml) and [`example_recursor_opportunistic_enc.toml`](https://github.com/hickory-dns/hickory-dns/blob/release/0.26/tests/test-data/test_configs/example_recursor_opportunistic_enc.toml).

## Blocklists

With the `blocklist` feature, a zone can chain several stores as a `[[zones.stores]]` array. Stores are tried in order, and the first one with an answer handles the query. Put a blocklist in front of a recursor or forwarder to answer blocked names with a sinkhole address:

```toml
[[zones]]
zone = "."
zone_type = "External"

[[zones.stores]]
type = "blocklist"
lists = ["default/blocklist.txt", "default/blocklist2.txt"]
wildcard_match = true
min_wildcard_depth = 2
sinkhole_ipv4 = "192.0.2.1"
sinkhole_ipv6 = "::ffff:c0:0:2:1"
block_message = "This query has been blocked by the DNS server"
log_clients = false

[[zones.stores]]
type = "recursor"
roots = "default/root.zone"
```

When a queried name is on one of the lists, the blocklist answers AAAA queries with `sinkhole_ipv6` and all other query types with an A record for `sinkhole_ipv4`. These default to `::` and `0.0.0.0`. If `block_message` is set, the response also includes it as a TXT record. Blocked answers have a TTL of `ttl` seconds, 86,400 by default. Names that are not on a list go on to the next store.

List files have one name per line, with `#` comments. Hosts-file lines such as `0.0.0.0 ads.example.com` are accepted too. A plain entry blocks only that exact name. An entry such as `*.example.com` blocks every name below `example.com`, but not `example.com` itself. Wildcard entries are only used while `wildcard_match` is on, which is the default. `min_wildcard_depth` (default 2) ignores wildcards with fewer labels than that after the `*`, so a stray `*.com` cannot block a whole top-level domain. Every match is logged, including the client's address unless `log_clients = false`.

A blocklist placed *after* another store is consulted once that store has answered. Its `consult_action` decides what happens: `"Disabled"` (the default) does nothing, `"Log"` logs matches, and `"Enforce"` logs them and replaces the answer. This lets you trial a list before enforcing it.

See [`chained_blocklist.toml`](https://github.com/hickory-dns/hickory-dns/blob/release/0.26/tests/test-data/test_configs/chained_blocklist.toml) and [`consulting_blocklist.toml`](https://github.com/hickory-dns/hickory-dns/blob/release/0.26/tests/test-data/test_configs/consulting_blocklist.toml).

## Tuning for high load

Under heavy query load, larger socket buffers and more UDP sockets can prevent dropped packets. The kernel may cap these values (for example through `net.core.rmem_max` and `net.core.somaxconn` on Linux).

```toml
[udp_socket]
recv_buffer_size = 4194304
send_buffer_size = 4194304
## Sockets per listen address, sharing the port with SO_REUSEPORT (Unix only).
sockets = 4

[tcp_socket]
## Pending connections the kernel will queue; 128 by default.
listen_backlog = 1024
## Responses that can be queued per connection; 32 by default.
response_buffer_size = 1024
```

With the `prometheus-metrics` feature, metrics are served on `127.0.0.1:9000` by default. Change this with `prometheus_listen_addr`, or turn it off with `disable_prometheus = true`.
