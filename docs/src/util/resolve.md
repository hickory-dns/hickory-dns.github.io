# resolve

`resolve` is a command line utility that exposes the functionality of the Hickory DNS stub-resolver library, `hickory-resolver`. The  `resolve` command is similar in function to `host`. It can be useful for getting the IP addresses of particular domain names, or seeing the `CNAME` chain of a record. It will return the results in the record's presentation format. Like the `hickory-resolver` library, `CNAME` chains and other lookups that require a small amount of recursion can be performed.

A stub-resolver does not perform recursive resolutions. It expects the upstream resolver used to perform all necessary recursive looks to traverse the DNS zone registry for necessary information. In other words, the stub-resolver will only every contact the configured nameserver for results.

The `resolve` command currently only supports the udp and tcp protocols, though the Hickory Resolver supports others. Please file a feature request for additional protocol support if desired (such as tls, https, h3, or quic).

## Example, get AAAA record

This will get the final AAAA record and all `CNAME` intermediates for `www.un.org`, which can sometimes be an easy way of discovering hosting providers:

```shell
Querying for www.un.org AAAA from udp:8.8.8.8:53, tcp:8.8.8.8:53, udp:8.8.4.4:53, tcp:8.8.4.4:53, udp:[2001:4860:4860::8888]:53, tcp:[2001:4860:4860::8888]:53, udp:[2001:4860:4860::8844]:53, tcp:[2001:4860:4860::8844]:53
Success for query www.un.org IN AAAA
        www.un.org. 1646 IN CNAME d1z8tokz9k79tw.cloudfront.net.
        d1z8tokz9k79tw.cloudfront.net. 60 IN AAAA 2600:9000:25ef:2a00:14:176d:6100:93a1
        d1z8tokz9k79tw.cloudfront.net. 60 IN AAAA 2600:9000:25ef:b200:14:176d:6100:93a1
        d1z8tokz9k79tw.cloudfront.net. 60 IN AAAA 2600:9000:25ef:f000:14:176d:6100:93a1
        d1z8tokz9k79tw.cloudfront.net. 60 IN AAAA 2600:9000:25ef:fc00:14:176d:6100:93a1
        d1z8tokz9k79tw.cloudfront.net. 60 IN AAAA 2600:9000:25ef:2000:14:176d:6100:93a1
        d1z8tokz9k79tw.cloudfront.net. 60 IN AAAA 2600:9000:25ef:b400:14:176d:6100:93a1
        d1z8tokz9k79tw.cloudfront.net. 60 IN AAAA 2600:9000:25ef:ac00:14:176d:6100:93a1
        d1z8tokz9k79tw.cloudfront.net. 60 IN AAAA 2600:9000:25ef:2800:14:176d:6100:93a1
```

Line by line explanation of output:

- `Querying for www.un.org AAAA from ...` - tells us the exact query being sent to the upstream resolvers, and is followed by the list of resolvers to try
- `Success for query www.un.org IN AAAA` - tells us the query the server responded with (this should match the original), and that it was successful
- Then the records returned from the query are returned, this starts with any intermediates in order, and then the final record requested

## Conclusion

The `resolve` command is good for understanding how the Hickory Resolver performs lookups. It can be useful as a CLI to easily verify how the `hickory-resolver` library will work when that is embedded in a program and hard to change behavior of.
