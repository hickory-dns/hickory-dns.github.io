# dns

`dns` is a command line interface for performing low level DNS operations directly against a specific nameserver. It can be used for performing queries, notifications, and dynamic updates of records (create, append, delete, etc). It returns results in a similar manner to `dig`, using the RFC defined presentation format for the output. This is not intended to be compatible with `dig`, but is intended to be a simpler tool for performing any DNS operation needed.

The `dns` tool exposes the library functionality of Hickory DNS. It is meant generally to help with debugging zone or nameserver configurations. All of the commands supported are available with `dns -h`, here is a list:

```text
Commands:
  query          Query a name server for the record of the given type
  notify         Notify a nameserver that a record has been updated
  create         Create a new record in the target zone
  append         Append record data to a record set
  delete-record  Delete a single record from a zone, the data must match the record
  help           Print this message or the help of the given subcommand(s)
```

Since the CLI is a direct implementation of Hickory DNS, it has support for all of the protocols that Hickory does, specifically: udp, tcp, tls, https, quic, h3. For the TLS based protocols, tls, https, quic, and h3, the `tls-dns-name` option is required for the TLS protocol. This is generally available in public documentation for various DNS services.

## querying

Here is a query example to Google's nameservers for the `google.com` `SOA` record:

```shell
> dns -n 8.8.8.8:53 query google.com SOA
; using udp:8.8.8.8:53
; sending query: google.com IN SOA
; received response
; header 21285:RESPONSE:RD,RA:NoError:QUERY:1/0/1
; edns version: 0 dnssec_ok: false max_payload: 512 opts: 0
; query
;; google.com. IN SOA
; answers 1
google.com. 60 IN SOA ns1.google.com. dns-admin.google.com. 667287868 900 900 1800 60
; nameservers 0
; additionals 1
```

The output is hopefully self-explanatory, but here is a line by line explanation:

- `; using udp:8.8.8.8:53` - tells us which DNS server is being queried
- `; sending query: google.com IN SOA` - shows us the query that was sent.
- `; received response` - tells us that we got a DNS response packet (as opposed to something else that would be unexpected)
- `; header 21285:RESPONSE:RD,RA:NoError:QUERY:1/0/1` - this is the DNS header in the response, respectively, the message id, message type, request flags, response code, operation code, and number of records in each section (answers/nameservers/additionals)
- `; edns version: 0 dnssec_ok: false max_payload: 512 opts: 0` - optionally, if the server supports extended DNS, these are the edns parameters
- `; query` - header for the query section
- `;; google.com. IN SOA` - exact query that was sent
- `; answers 1` - count of answers recieved
- `google.com. 60 IN SOA ns1.google.com. dns-admin.google.com. 667287868 900 900 1800 60` - the SOA record for `google.com.`
- `; nameservers 0` - count of the nameservers (or authorities) in the response
- `; additionals 1` - the additional section count (this is 1 for the EDNS record which has no presentation format but was expanded above)

As a counter example of an unsuccessful query for a `TXT` record named `doesnotexist.google.com`:

```shell
> dns -n 8.8.8.8:53 query doesnotexist.google.com TXT
; using udp:8.8.8.8:53
; sending query: doesnotexist.google.com IN TXT
; received response
; header 53338:RESPONSE:RD,RA:NXDomain:QUERY:0/1/1
; edns version: 0 dnssec_ok: false max_payload: 512 opts: 0
; query
;; doesnotexist.google.com. IN TXT
; answers 0
; nameservers 1
google.com. 60 IN SOA ns1.google.com. dns-admin.google.com. 667090956 900 900 1800 60
; additionals 1
```

Notice the `NXDomain` in the header saying tha the record does not exist, nor does any of another type. Additionally there is a single nameserver in the response that tells us the SOA.

## Conclusion

`dns` is a low level command for interacting with name servers. Consider the `resolve` command for a simple to use stub resolver.