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

To configure Hickory as an authoritative name server the setup requires a few steps.

* set up one or more zone files to have authority over
* generate a zone signing key (ZSK)
* configure Hickory to define zones, use the key, to sign all zones and generate additional records


### Zone File(s)

First at least one zone file has to be created to be authority over. An example of a zone file looks as follows:

```txt
.	86400	IN	SOA	primary0.example.com. admin0.example.com. 2024010101 1800 900 604800 86400
.	86400	IN	NS	primary0.example.com.
primary0.example.com.	86400	IN	A	127.0.0.1
```

This file defines a `SOA` record (Start of Authority), a `NS` record (Namespace) and an `A` record (IPv4 Address).

A list of zone files can be found in the [`test_configs/default`](https://github.com/hickory-dns/hickory-dns/tree/main/tests/test-data/test_configs/default) folder as part of the test suite.


### Zone Signing Key

The second step is to generate a zone signing key (ZSK) Hickory uses to sign all zones with. During startup of Hickory
this key to sign all zone files with. Additionally a key signing key is generated as well internally.

To generate a compatible ZSK use `openssl` command line tool:

```shell
openssl genpkey -quiet -algorithm RSA -out zsk.key
```

This generates a new key using the `RSASHA256` algorithm and stores the private key in `zsk.key`.


### `config.toml`

Last step is to create a `config.toml` file for Hickory.

```toml
# config.toml
listen_addrs_ipv4 = ["0.0.0.0"]

[[zones]]
zone = "."
zone_type = "Primary"
file = "root.zone"
enable_dnssec = true

[[zones.keys]]
key_path = "zsk.key"
algorithm = "RSASHA256"
is_zone_signing_key = true
```

This configuration consists of the following fields:

* `listen_addrs_ipv4` - specifies the list of addresses the DNS server will accept connections on.
* `[[zones]]` - A block to define a zone.
  * `zone` - The zone to sign, in this case root `"."`.
  * `zone_type` - `Primary` indicates that hickory is the authority.
  * `file` - The name of the zone file that contains all DNS records.
  * `enable_dnssec` - When `true` Hickory generates additional DNSSEC records for all records in the zone file on startup.
* `[[zones.keys]]` - A block to define a zone key.
  * `key_path` - The path to the signing key, e.g. `zsk.key`
  * `algorithm` - The cryptographic algorithm the key was generated with.
  * `is_zone_signing_key` - When `true` marks the key as zone signing key.

Please note that `enable_dnssec` in this context does not mean DNSSEC validation is active, it's used to generate all relevant
DNSSEC records during startup. Multiple zones can be specified by `[[zones]]` blocks with different zone files.


## Run Hickory

Let's start `hickory-dns` now, we assume zone files and ZSK are in the same folder.

```shell
hickory-dns --port 2345 --debug --config=./config.toml --zone-dir=.
```

This starts `hickory-dns` on port `2345` with debug log level. Feel free to pick a different port, typically port `53` is already
taken by the DNS service of the operating system. The `--config` option specifies the location of the `config.toml`
otherwise it checks the default file path at `/etc/named.toml`. The `--zone-dir` option specifies the path to check zone
files in, e.g. `root.zone`, the default directoy is `/var/named`.

The debug log of Hickory should contain output that loads a `ZoneConfig`, the authority loads zone records and signs the
zone `.` using the generated zone signing key. The `hickory-dns` server should now run and accept DNS queries,
for example via `dig` or `delv`.


### `dig`

To fetch the `A` record for domain `primary0.example.com.` use the `dig` command:

```shell
dig @127.0.0.1 -p 2345 primary0.example.com. +norecurse
```

which returns

```txt
; <<>> DiG 9.20.2 <<>> @127.0.0.1 -p 2345 primary0.example.com. +norecurse
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 39369
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags: do; udp: 1232
; OPT=5: 08 0d 0e 0f ("....")
; OPT=6: 08 0d 0e 0f ("....")
;; QUESTION SECTION:
;primary0.example.com.	IN	A

;; ANSWER SECTION:
primary0.example.com. 86400 IN	A	127.0.0.1

;; Query time: 0 msec
;; SERVER: 127.0.0.1#2345(127.0.0.1) (UDP)
;; WHEN: Mon Oct 21 15:15:19 CEST 2024
;; MSG SIZE  rcvd: 117
```

Please note the authoritative name server is configured to not send queries to other servers, therefore the `+norecurse`
option is passed in. The following lines provide a bit more information on the response.

```txt
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 39369
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
```

The DNS server responded with status `NOERROR`, indicating a valid response. The `flags` field is a bitset with
different flags, displayed as `qr aa rd`.

* `qr` - means it's a query response
* `aa` - means it's an authoritative answer
* `rd` - means recursion desired, the name server is allowed to forward the query to other upstream name servers

The `dig` CLI sets the `+recurse` flag as default, which explains why the `rd` flag is set in the response.

In order to check that the DNS server created the associated `RRSIG` record to the `A` record, use `dig`'s `+dnssec`
option to return both records.

```shell
dig @127.0.0.1 -p 2345 primary0.example.com. +dnssec +multiline
```

The `+multiline` option will wrap the text to a reasonable width, otherwise the output gets unwieldy.
This will return the associated `RRSIG` record in the `ANSWERS` section as well.

```txt
;; ANSWER SECTION:
primary0.example.com. 86400 IN A 127.0.0.1
primary0.example.com. 86400 IN RRSIG A 8 3 86400 (
				20251020134506 20241021134506 57797 .
				FyZW3yHIdEfN0eakLvgsZQkzx5MhcLM24h8wNPiEcosX
				3TTOr0NwvXAHqtbxYTJssfjR3DZhG3EgBdlZ18FpBKoY
				+VA3Vg+NYtuKpGduXU7Dreh3La5L8GlKC6uFc1ay0hR6
				qTq8M07JyzlMWE+U6r1n2R9bATKiWufhuDtnoINJbDMi
				TwaJ/ZxE7lfttpQ1gUKoNoEcOGkZUP18JlnyXoKrNkVH
				DdD0J/K8LTp/lnZ7AuAQ7ixJRNxroth6meeCHAQHNqyL
				9H6zKAiSRw4RVi4swodhyzCzn+oXhXjGVDmZlHFz8+QO
				S43iTumVhKaI8Fe/8/tgNMGZM+m7Z9N1GA== )
```

The DNS server has a single zone config for zone `"."`. To return the associated `DNSKEY` record(s) we can query them:

``` shell
dig @127.0.0.1 -p 2345 . DNSKEY +dnssec +multiline
```

The response contains two records in the `ANSWERS` section:

```txt
;; ANSWER SECTION:
.			86400 IN DNSKEY	257 3 8 (
				AwEAAZzIkGf9sTXfFFeHTSNjbw3gr4ESGA5CzPtLKTSW
				8rbEpJw2G+goVFRrIS9ieHUna59TEfBkM/8WQ/MVkQQD
				pTTP2Rqg/E0aHEBQ2xbQVIveYXcU9absPn+CPjM3+gq0
				9bv9CDzxsa0yl9B7xbeAM9V8zXqtXfFaQ3plSUs9Wtqo
				nu/mJwEOu8YMiu9K0eZ+Gju1amobaOBXkOwCro7o8wae
				MIC0vFjC/ghfEmFAK1V3TFZw/jQXYWG4I6BdULiiMeLL
				R6ESPCXMRjBcMiCIPy5WOzQ4iAjpSkLEHqrtc9EwnUCT
				C0tmihZPZh3dyy7TgB3YTaHw8KEQhnDmdfjPZpc=
				) ; KSK; alg = RSASHA256 ; key id = 57797
.			86400 IN RRSIG DNSKEY 8 0 86400 (
				20251020134506 20241021134506 57797 .
				Q4CeL96V2NDBJI6jF3wjjLUYrW/jGjOgTuT3D8mRFwPy
				0b6suHmIy+1XPSGgYMAu1bpyVUxcpvXSE7DMIO/eYB/E
				nA5ArjcuOpKIzN+m75pLOZXb204dD5DptBhgjn04zTDB
				ML1rzK5acjp2Lcbo3X5lFABCXpy4diQDZhfCupNVA5JV
				mVD2nJ+eXHQXovB1cYyv5/w+1oK/ojZ1BZbMjUBIQjlH
				hisc8b5Y+V8fDehau3hIOuSrosJb15ST9J7YNndkt5kT
				1nSbAocX3AFWuZEVqwhbou45UAb2NfuvPlbZT5lHReWQ
				5E+1JULfak+HDz/blHyBPzALYrOEn0s7MQ== )
```

One is the `DNSKEY` (KSK) and the other the associated `RRSIG` for that `DNSKEY` record. Nearly all signed records
have an associated `RRSIG` record to describe their signature.

