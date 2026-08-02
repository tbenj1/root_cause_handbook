# Researching Issues

Search for the exact problem, not a broad description.

Avoid searches such as:

> Outlook broken

Add the details that make the issue specific:

* Exact error message
* Error code
* Application name
* Application version
* Operating system
* Event ID and provider
* What the user is doing when the issue happens

## Better Search Examples

```text
Outlook error 0x8004010F Windows 11
```

```text
Event ID 1000 faulting application Teams.exe
```

```text
Windows 11 mapped drive missing after reboot
```

```text
Adobe Reader freezes when printing PDF
```

```text
Microsoft 365 Outlook disconnected only one user
```

Use quotation marks around an exact error message:

```text
"The trust relationship between this workstation and the primary domain failed"
```

This searches for the exact wording instead of separate words that may not be related.

## Add the Right Context

A useful search usually looks like this:

```text
"Exact error message" + product + version + operating system
```

Examples:

```text
"Access is denied" shared folder Windows 11 domain user
```

```text
"Your credentials did not work" Remote Desktop Windows 11
```

```text
Event ID 7000 Service Control Manager Windows Server
```

Do not add every detail from the ticket. Add the details that change which results are relevant.

## Narrow Down the Results

### Search a Specific Website

```text
site:learn.microsoft.com error 0x80070005
```

```text
site:support.microsoft.com Outlook disconnected
```

```text
site:community.spiceworks.com printer offline Windows 11
```

### Remove a Word

```text
Outlook search not working -Mac
```

This removes results focused on macOS.

## Check the Source Before Using the Fix

Start with sources in this order:

1. Vendor documentation
2. Microsoft Learn or Microsoft Support
3. Official application knowledge bases
4. Hardware manufacturer documentation
5. Internal documentation
6. Well-known technical communities
7. Forums and discussion boards

Forum posts can be useful, but they are not automatically correct or approved for your environment.

Before applying a fix, check:

* Does it match the same error and behavior?
* Does it apply to the same product and version?
* Does it apply to the same operating system?
* Is the source reliable?
* Do you understand what the change does?
* Is the change safe and reversible?
* Could it affect other users, devices, or services?
* Does it require approval or elevated access?
* Does it change the registry, security settings, permissions, or data?

!!! danger "A search result is not approval"

    Do not copy and run an unknown script because it appeared in a search result. Read the command, confirm the source, understand the impact, and make sure there is a way back before changing anything.

## Document Useful Research

When a source helped with the issue, document:

* The page or article used
* The exact error or condition it matched
* The change that was considered
* Why the change applied to this issue
* Any warning, requirement, or rollback step
* The result after testing
