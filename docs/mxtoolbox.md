# MXToolbox

Use MXToolbox when you need to see what public DNS and mail systems see from outside the environment.

!!! important "MXToolbox shows what is published, not what it should be"

    Before changing a DNS or mail record, compare the result with the DNS provider, Microsoft 365 tenant, mail-security platform, and internal documentation. A public lookup shows what is live. It does not tell you whether the configuration was intended.

## When to Use It

Use MXToolbox for:

* Inbound or outbound mail delivery issues
* Incorrect or recently changed MX records
* SPF, DKIM, or DMARC issues
* Public DNS changes and propagation
* SMTP connectivity
* Reverse DNS
* Sending IP reputation or blacklist results
* Certificate or public endpoint checks

It is usually not the right starting point for a local Outlook profile, client add-in, local network adapter, or mailbox permission unless the evidence points to public mail flow or DNS.

## Collect This First

Document:

* Affected sender and recipient
* Sending and receiving domains
* Exact non-delivery report or SMTP response
* Message date, time, and time zone
* Message ID or headers when available
* Public IP address involved
* Recent DNS, connector, gateway, or mail-security changes

## SuperTool Queries

The SuperTool accepts a domain, hostname, or IP address. Add a prefix when you want a specific test.

| Query | What it checks |
| --- | --- |
| `mx:example.com` | Published mail exchangers and priority |
| `dns:example.com` | DNS server and record health |
| `a:mail.example.com` | IPv4 address for a hostname |
| `aaaa:mail.example.com` | IPv6 address for a hostname |
| `cname:autodiscover.example.com` | CNAME target |
| `txt:example.com` | Published TXT records |
| `spf:example.com` | SPF syntax and allowed senders |
| `dmarc:example.com` | DMARC record and policy |
| `dkim:` | DKIM record using the domain and selector requested by the tool |
| `ptr:203.0.113.25` | Reverse DNS for an IP address |
| `smtp:mail.example.com` | Public SMTP response on port 25 |
| `blacklist:203.0.113.25` | Reputation list results for an IP or host |

## Common Checks

### Inbound email is not arriving

1. Run `mx:` against the recipient domain.
2. Make sure the published MX hosts match the documented mail path.
3. Check the priorities and look for old or unexpected gateways.
4. Run `smtp:` against the expected inbound host.
5. Compare the result with the non-delivery report.
6. Check for recent DNS or connector changes.

An MX record can be valid and still point to the wrong service.

### Outbound email is rejected or sent to spam

1. Find the sending public IP from the message headers, outbound gateway, or rejection.
2. Run `ptr:` against the sending IP.
3. Run `blacklist:` against the sending IP.
4. Run `spf:` against the sender domain.
5. Check DKIM using the selector from the message header or mail platform.
6. Run `dmarc:` against the sender domain.
7. Review the SMTP response and message headers before recommending a DNS change.

A blacklist result is only one piece of information. Confirm whether the receiving system actually used that list or gave a rejection reason tied to reputation.

### A DNS change is not showing up

1. Run the lookup for the exact record type.
2. Compare the result with the authoritative DNS provider.
3. Check the TTL.
4. Make sure the hostname and record type are correct.
5. Compare the result with `nslookup` or `Resolve-DnsName` using more than one resolver.

The MX lookup can query the authoritative name server, so an authoritative change may appear there before older recursive DNS caches expire.

### SPF is failing

Check:

* Whether the expected sending service is included
* Whether more than one SPF record exists
* Whether the sending IP is allowed by the SPF path
* Whether an `include` target is missing or failing
* Whether there are syntax or DNS lookup limit errors
* Whether the envelope-from domain is different from the visible From domain

Do not add an IP address or service to SPF until you have confirmed that it is a legitimate sender for the domain.

### DKIM is failing

Get the selector and signing domain from the `DKIM-Signature` header. Then check:

* The selector record exists
* The signing domain is correct
* The public key is published
* The message was signed by the expected service
* The selector matches the mail platform configuration

### DMARC is failing

Check:

* The published policy: `p=none`, `quarantine`, or `reject`
* SPF alignment
* DKIM alignment
* Reporting addresses
* Subdomain policy when it applies
* Whether the visible From domain lines up with the authenticated domain

DMARC can pass when either aligned SPF or aligned DKIM passes. A valid DMARC record does not prove that every sending service is configured correctly.

## Break the Result Into Three Parts

### Configuration

What is publicly published?

* MX targets
* A, AAAA, CNAME, TXT, SPF, DKIM, and DMARC records
* Reverse DNS

### Reachability

Can an outside system reach the service?

* SMTP response
* TCP connection
* HTTPS response
* DNS response

### Reputation

How is the sending host currently viewed?

* Blacklist results
* Reverse DNS quality
* Hostname consistency

Do not treat these as the same thing. DNS can be correct while the service is unreachable. The service can be reachable while the sending IP has a reputation issue.

## What to Document

Document:

* Query used
* Date, time, and time zone
* Domain, hostname, or IP tested
* Expected result
* Actual result
* Useful warning or failure
* Screenshot or saved output
* Comparison with the authoritative configuration
* What should be checked next

## References

* [MXToolbox SuperTool](https://mxtoolbox.com/SuperTool.aspx)
* [MX lookup](https://mxtoolbox.com/)
