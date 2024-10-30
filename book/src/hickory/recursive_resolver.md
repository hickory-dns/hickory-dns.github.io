# Recursive Resolver

Hickory supports the role of a [Recursive Resolver](https://en.wikipedia.org/wiki/Name_server#Recursive_Resolver).
A recursive resolver is a DNS server that accepts recursive queries and is able to resolve these queries by
fetching additional records from other known authoritative name servers or from its cache. A recursive resolver
can validate the recursive query to answer the question if the chain of trust is valid.

## Configuration

To run Hickory as a recursive resolver with DNSSEC validation the following steps are necessary:

* create a root hints file named `root.hints`
* create a trust anchor file named `trusted-key.key`
* configure Hickory via `config.toml`


### Root Hints

The root hints file is used to define a set of authoritative name servers Hickory can query to fetch records for which
it has no authority over. For example the Internet Assigned Numbers Authority (IANA)
provides a set of files for their root name servers (see [here](https://www.iana.org/domains/root/files)). IANA is the authority
for the root zone `"."`, they are responsible for assigning operators for top level domains (e.g. `com`, `de`).

For our example we will use the `root.hints` file provided by IANA and copy that to a local file.


### Trust Anchor

In order to validate the chain of records successfully Hickory needs the trust anchor for the root zone `"."`.
The keys can be fetched via `dig`.

```shell
dig DNSKEY . +answer
```

The command returns two `DNSKEY` records (abbreviated) in the `ANSWERS` section of the response:

```txt
. 19347	IN  DNSKEY  256 3 8 AwEAAc0SunbHdS0KFEyZbYII/+tzsrNzIwurKxmJA+0fhAYlTPA/5LrM ...
. 19347	IN  DNSKEY  257 3 8 AwEAAaz/tAm8yTn4Mfeh5eyI96WSVexTBAvkMgJzkKTOiW1vkIbzxeF3 ...
```

Create a new file named `trusted-key.key`, copy the content of the `ANSWERS` section into it. These keys are involved
in the validation of the root zone.


### `config.toml`

The last step is to configure Hickory as a recursive resolver.

```toml
# config.toml
[[zones]]
zone = "."
zone_type = "Hint"
stores = { type = "recursor", roots = "/absolute/path/root.hints", dnssec_policy.ValidateWithStaticKey.path = "/absolute/path/trusted-key.key" }
```

The configuration consists of the following fields:

* `zone` - The zone to configure.
* `zone_type` - The `Hint` value indicates a zone with recursive resolver abilities.
* `stores` - A block that defines a store type.
  * `type` - Indicates a `recursor` configuration
  * `roots` - The file path to the root hints file.
  * `dnssec_policy` - Configues the DNSSEC validation policy.
    * `ValidateWithStaticKey.path` - The file path to the trusted key used for DNSSEC validation.


> **Note:** Both path fields, `root` and `ValidateWithStaticKey.path`, need to be absolute paths.


## Run Hickory

To start Hickory run:

```shell
hickory-dns --port 2345 --debug --config=./config.toml
```

This runs the DNS server on port `2345` with the resolver configuration. This time the DNS server
can forward requests to the root name servers specified in the `root.hints` file.


## DNSSEC Validation

Hickory started as recursive resolver and will execute DNSSEC validation for a query.

### Using `dig`

In order to answer a recursive query the client needs to send
the [`RD`](https://datatracker.ietf.org/doc/html/rfc1035#section-4) (Recursion Desired) flag.
Using `dig` we can see that for an existing domain no records will be returned if the flag is disabled.

```shell
dig @127.0.0.1 -p 2345 example.com. +norecurse
```

This is because the recursive resolver cannot answer this query on its own.
By setting the `RD` flag in `dig` (default) the query will return the `A` record for domain `example.com`.
The command

```shell
dig @127.0.0.1 -p 2345 example.com. +recurse
```

returns

```txt
; <<>> DiG 9.20.2 <<>> @127.0.0.1 -p 2345 example.com. +recurse
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 30300
;; flags: qr rd ra ad; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags: do; udp: 1232
; OPT=5: 08 0d 0e 0f ("....")
; OPT=6: 08 0d 0e 0f ("....")
;; QUESTION SECTION:
;example.com.			IN	A

;; ANSWER SECTION:
example.com.		3600	IN	A	93.184.215.14

;; Query time: 851 msec
;; SERVER: 127.0.0.1#2345(127.0.0.1) (UDP)
;; WHEN: Tue Oct 22 11:09:47 CEST 2024
;; MSG SIZE  rcvd: 83
```

Specifiying the `+dnssec` option in the `dig` command will additionally return the `RRSIG` record.
Check the `hickory-dns` log to learn how the recursive query is processed, the DNSSEC validation, and what
other name servers were involved.

The recursive resolver performs DNSSEC validation for each client query to validate the chain of trust.
This validates all records that are involved in the query resolution, and returns the appropriate response.
The DNS server automatically sets the [`ad` flag](https://www.rfc-editor.org/rfc/rfc6840.html#section-5.7)
(Authentic Data) in its response to indicate successful validation.

To return all records even when DNSSEC validation fails set the checking disabled
flag [`CD`](https://www.rfc-editor.org/rfc/rfc4035#section-3.2.2) using `dig`'s `+cdflag` option.
For example the following query uses `dig` to fetch the `A` record for a domain that fails DNSSEC validation:

```shell
dig @127.0.0.1 -p 2345 www.dnssec-failed.org. +dnssec +cdflag
```

Without the `+cdflag` the query would not return any records. The `flags` field in the answer will not contain the
authenticated data (AD) bit to indicate there was a problem with the DNSSEC validation.


### Using `delv`

Another tool to query DNS servers is `delv`. It can be used to return more information on the
DNSSEC validation process. Let's try the same query as above using `delv`:

```shell
delv @127.0.0.1 -p 2345 example.com. A
```

returns

```txt
; fully validated
example.com.		3447	IN	A	93.184.215.14
example.com.		3447	IN	RRSIG	A 13 2 3600 20241102170341 20241012065317 19367 example.com. XMyTWC8y9WecF5ST67DyRUK3Ptvfpy/+Oetha9r6ZU0RJ4aclvY32uKC ojUsjCUHaejma032va/7Z4Yd3Krq8Q==
```

The important line here is `; fully validated`, the remainig output is similar to `dig`, the returned records are the same.
Let's query a record for a domain that does not exist.

```shell
delv @127.0.0.1 -p 2345 doesnotexist.com. A
```

returns

```txt
;; no valid RRSIG resolving 'doesnotexist.com/DS/IN': 127.0.0.1#2345
;; broken trust chain resolving 'doesnotexist.com/A/IN': 127.0.0.1#2345
;; resolution failed: broken trust chain
```

This is a good start, but it doesn't really provide the full picture of what's happening under the hood. To figure
out more about the validation process either check the output of `hickory-dns` or alternatively display the
intermediate steps using `delv` as well.

To display a brief list of validation steps use the `+rtrace` option:

```shell
delv @127.0.0.1 -p 2345 example.com. A +rtrace
```

that ouputs

```txt
;; fetch: example.com/A
;; fetch: example.com/DNSKEY
;; fetch: example.com/DS
;; fetch: com/DNSKEY
;; fetch: com/DS
;; fetch: ./DNSKEY
; fully validated
example.com.		2641	IN	A	93.184.215.14
example.com.		2641	IN	RRSIG	A 13 2 3600 20241102170341 20241012065317 19367 example.com. ...
```

The query returns information on intermediate steps, with the chain of trust fully validated.
To get the full picture including all intermediate DNS queries and responses use the `+mtrace` option

```shell
delv @127.0.0.1 -p 2345 example.com. A +mtrace
```
