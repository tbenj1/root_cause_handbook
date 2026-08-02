# Using IT Glue and Internal Documentation

Before spending a large amount of time researching an issue, check whether the environment or the same issue has already been documented.

This page uses IT Glue as the example. Use the same process when your organization uses another documentation platform.

## Check the Organization Documentation

Review the affected organization for:

* Flexible assets
* Configuration records
* Password records, when authorized
* Network documentation
* Server documentation
* Application documentation
* Vendor information
* Known issues
* Standard operating procedures
* Previous project documentation
* Related devices and contacts
* ISP and circuit information
* Office-specific instructions
* Application-specific instructions

Examples of useful environment-specific information include:

* The organization uses a specific VPN configuration.
* A line-of-business application connects to a specific server.
* Printers are deployed in a nonstandard way.
* One office has a documented backup internet connection.
* A device should not be patched or restarted during business hours.
* A server requires services to start in a certain order.

## Search Previous Tickets and Articles

Search for:

* Exact error message
* Error code
* Application name
* Device name
* Server name
* User name
* Event ID
* Vendor name
* General symptom

Try more than one version of the search.

For example:

```text
Outlook disconnected
```

```text
Microsoft 365 connection issue
```

```text
0x8004011D
```

```text
Cannot connect to Exchange
```

Check whether the previous issue:

* Happened in the same environment
* Affected the same device, account, or application
* Had the same error message and behavior
* Was caused by the same configuration
* Was fixed with a documented and approved process

!!! warning "Do not repeat an old fix without checking the current issue"

    A previous ticket may look similar without having the same cause. Make sure the symptoms and conditions match before repeating the same steps.

## Check the Source of Truth

When two records do not match, use the approved source of truth for that information. Examples may include:

* Halo or the service-management platform for the customer name and ticket history
* IT Glue for environment documentation and credentials
* The RMM for current device information
* The identity platform for current account status
* The vendor portal for the current service configuration

Document the mismatch and update the outdated record when you are authorized to do so.

## Update the Documentation When Needed

Update the documentation when:

* The current instructions are wrong or incomplete
* A required setting or dependency was missing
* The issue is likely to happen again
* A workaround is now part of the environment
* A server, path, vendor contact, or process changed
* The same issue has appeared in more than one ticket

Do not bury an environment-specific fix only in a ticket. Put it where the next person will look for it.
