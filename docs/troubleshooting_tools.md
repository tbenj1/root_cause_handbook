# Troubleshooting Tools

Use a tool to answer a specific question. Do not collect information just because the tool is available.

!!! important "Know what you are trying to figure out"

    Pick the smallest test that can prove or rule something out. Document the result and use it to decide what to check next.

## Tool Selection Guide

| What are you trying to figure out? | Start with | Check next |
| --- | --- | --- |
| Did Windows or an application record a failure? | [Event Viewer](event_viewer.md) | Reliability Monitor or PowerShell |
| Is a process, service, disk, or memory issue affecting the device? | Task Manager and Services | PowerShell or RMM data |
| Which driver belongs to an unknown or failing device? | Device Manager | [Microsoft Update Catalog and Driver Identification](microsoft_update_catalog_drivers.md) |
| Are public DNS and email records correct? | `nslookup` or `Resolve-DnsName` | [MXToolbox](mxtoolbox.md) |
| Who changed, accessed, deleted, forwarded, or shared something in Microsoft 365? | [Microsoft Purview Audit](purview_audit.md) | Exported audit results, Entra logs, or escalation |
| Can a repeatable Windows query collect better evidence? | [PowerShell Cheat Sheet](powershell_cheat_sheet.md) | A documented script or automation |
| Has the issue happened before? | [Using IT Glue and Internal Documentation](using_it_glue.md) | [Researching Issues](researching_issues.md) |

## Main Tool Guides

<div class="grid cards" markdown>

-   :material-powershell:{ .lg .middle } **PowerShell**

    ---

    Check services, processes, files, networking, installed software, event logs, and system information with repeatable commands.

    [Open the PowerShell cheat sheet](powershell_cheat_sheet.md)

-   :material-alert-box-outline:{ .lg .middle } **Event Viewer**

    ---

    Match application, service, driver, update, sign-in, and hardware events with the time the issue happened.

    [Use Event Viewer](event_viewer.md)

-   :material-expansion-card-variant:{ .lg .middle } **Device Manager and Update Catalog**

    ---

    Find the exact hardware ID, locate the right driver, confirm the match, install it, and keep a way to roll back.

    [Find the correct driver](microsoft_update_catalog_drivers.md)

-   :material-email-search-outline:{ .lg .middle } **MXToolbox**

    ---

    Check public DNS, MX, SPF, DKIM, DMARC, SMTP, reverse DNS, and blacklist results from outside the environment.

    [Use MXToolbox](mxtoolbox.md)

-   :material-shield-search:{ .lg .middle } **Microsoft Purview Audit**

    ---

    Search Microsoft 365 activity for mailbox changes, deleted items, inbox rules, forwarding, file activity, sharing, and administrative actions.

    [Run and review an audit](purview_audit.md)

</div>

## Task Manager

Use Task Manager to check for:

* High CPU, memory, disk, or network usage
* Applications that are not responding
* Unexpected startup applications
* Missing or stopped processes
* The user account running a process

Make sure the resource usage matches the complaint. Document the process name and what you saw before ending a process.

A computer described as “slow” may show high resource use, but that does not automatically show the cause. Check what the process is doing and whether the condition is temporary, expected, or repeatable.

## Services

Use the Services console to check whether a required Windows or application service is:

* Running
* Stopped
* Starting
* Disabled
* Failing repeatedly

Document the service name, display name, current status, startup type, and any error received when starting or restarting it.

!!! warning "Service changes can affect other applications"

    Do not change a service startup type unless you know what it should be and the change is approved. Check dependencies and document the original setting first.

## Device Manager

Use Device Manager to find:

* Unknown devices
* Missing or failed drivers
* Disabled hardware
* Device status codes
* Current driver provider, date, and version
* Hardware IDs and compatible IDs

A warning icon means the device needs to be checked. It does not automatically mean the hardware has failed. Read the device status and collect the hardware information before changing the driver.

[Follow the full driver process](microsoft_update_catalog_drivers.md).

## Command-Line Tools

### Network configuration

```cmd
ipconfig /all
```

Check the IP address, subnet mask, default gateway, DNS servers, DHCP state, and adapter description.

### Basic connectivity

```cmd
ping servername
```

```cmd
ping 8.8.8.8
```

Some systems block ICMP on purpose. A failed ping does not prove that the destination or service is down.

### DNS testing

```cmd
nslookup hostname
```

Check the name being queried, which DNS server answered, and which address was returned.

### Network path

```cmd
tracert hostname
```

Use this to review the path to a destination. Missing hops can be caused by filtering and do not always show a failure.

### Logged-in user

```cmd
whoami
```

Use this to confirm which account is being used for the test.

### System information

```cmd
systeminfo
```

Use this to collect the Windows version, build, system model, boot time, and basic hardware details.

### Group Policy information

```cmd
gpresult /r
```

Use this when the issue may be related to Group Policy and you are authorized to review it.

## Reliability Monitor

Reliability Monitor gives you a timeline of:

* Application failures
* Windows failures
* Hardware errors
* Software installations
* Windows updates
* Unexpected shutdowns

Open it by searching Windows for **View reliability history**.

Use Reliability Monitor when the user knows roughly when the issue started but does not know what changed. Look for installations, updates, and failures close to the first time the issue happened.

## RMM and Remote Management Tools

Use the available RMM or remote management platform to check:

* Device online status and last check-in
* Operating system and uptime
* Pending restart state
* Disk space, CPU, and memory use
* Installed applications
* Windows services
* Patch status
* Recent alerts
* Security tool status
* Device history
* Automation results

Compare the RMM information with the user’s report and the current device state. Cached information may be old when the device has not checked in recently.

## What to Document

For every tool used, document:

* Why you used it
* The device, user, account, domain, or service tested
* Date, time, and time zone
* Exact filter, command, or search used
* The useful result
* What the result proved or ruled out
* Any exported files or screenshots
* What you checked next
