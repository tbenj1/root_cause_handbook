# Event Viewer

Event Viewer records activity from Windows, applications, services, drivers, and security components. Use it to find events that match the same time and component as the issue.

!!! important "An error is not automatically the cause"

    Windows can contain old, repeated, and unrelated errors. An event is useful when the time, provider, affected component, and behavior match the issue you are working on.

## Collect This First

Before opening Event Viewer, document:

* The exact time the issue happened
* The time zone of the device or user
* The affected application, service, account, or hardware
* What the user was doing
* The exact error message or visible behavior
* Whether the issue can be reproduced

When possible, reproduce the issue once and document the time to the nearest minute. This gives you a clear place to start looking.

## Open Event Viewer

Use either method:

1. Press ++win+r++.
2. Enter `eventvwr.msc`.
3. Select **OK**.

You can also search Windows for **Event Viewer**.

## Check the Right Log

### Windows Logs > Application

Start here for:

* Application crashes or hangs
* Faulting applications or modules
* Microsoft Office and line-of-business application errors
* Application warnings
* Windows Error Reporting events

### Windows Logs > System

Start here for:

* Service startup failures
* Driver and hardware events
* Unexpected shutdowns
* Disk, storage, or file-system issues
* Network adapter events
* Windows Update and operating-system components

### Windows Logs > Security

Use this log only when it applies to the investigation and you are authorized to review it.

It may contain:

* Successful or failed sign-ins
* Account lockouts
* Privilege use
* Object access
* Policy changes

Security events depend on the organization’s audit policy. A missing event does not always prove that the action did not happen.

### Applications and Services Logs

Check here when the affected Microsoft or third-party component has its own log. Common examples include:

* Microsoft > Windows > GroupPolicy > Operational
* Microsoft > Windows > WindowsUpdateClient > Operational
* Microsoft > Windows > TaskScheduler > Operational
* Microsoft > Windows > PowerShell > Operational

These logs often contain more detail than the general Application or System logs.

## Filter the Log

1. Select the log you want to check.
2. In the **Actions** pane, select **Filter Current Log**.
3. Choose a time range close to when the issue happened.
4. Select event levels only when they help:
   * Critical
   * Error
   * Warning
   * Information
5. Add the provider or event ID when you already know it.
6. Select **OK**.

Start with a small time window. Make it wider only when the event you expect is not there.

!!! tip "Save a view when you will use the same filter again"

    Use **Create Custom View** when the same investigation will continue across multiple devices or time periods. Event Viewer can also show the XML query that can be used with `Get-WinEvent`.

## Read the Event

Check both the **General** and **Details** tabs.

| Field | What to check |
| --- | --- |
| Logged | When Windows recorded the event |
| Source or Provider | Which component created it |
| Event ID | The event type for that provider |
| Level | The severity assigned by the provider |
| User | The account involved, when recorded |
| Computer | The device that created the event |
| General message | The main event details |
| Details > XML | Structured values, parameters, and IDs that can connect related events |

Do not search for an event ID without the source or provider. Event IDs are not unique across all of Windows.

## Match the Event to the Issue

An event is stronger evidence when:

* The timestamp matches the failure
* The provider matches the affected component
* The same event appears when the issue is reproduced
* The event contains the same application, service, user, path, device, or error code
* A success or recovery event appears after the issue clears

Look at the events around it and build a timeline. The last error the user sees may have been caused by an earlier failure.

### Example Timeline

1. A service fails to start.
2. An application that depends on the service records a connection error.
3. The user receives an application error.
4. The service later starts successfully.
5. The application works on the next test.

The first related failure is usually more useful than the last visible error.

## Common Starting Points

These are only starting points. Always read the provider and message before deciding what the event means.

| Provider or event | Why you may check it |
| --- | --- |
| Application Error, often event 1000 | Application crash and faulting module |
| Windows Error Reporting, often event 1001 | Crash or hang report details |
| Service Control Manager, commonly 7000-series events | Service startup, timeout, or dependency issues |
| Kernel-Power event 41 | Windows detected an unexpected restart or loss of power; it does not show the original cause by itself |
| BugCheck event 1001 | Stop code and crash-dump details after a blue screen |
| Disk, Ntfs, StorPort, or storage-controller providers | Storage, file-system, controller, or path issues |

## Use PowerShell for Faster Searches

List recent System errors:

```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    Level   = 2
} -MaxEvents 50
```

Search a specific time range:

```powershell
$start = (Get-Date).AddMinutes(-30)
$end = Get-Date

Get-WinEvent -FilterHashtable @{
    LogName   = 'Application'
    StartTime = $start
    EndTime   = $end
}
```

Search by provider and event ID:

```powershell
Get-WinEvent -FilterHashtable @{
    LogName      = 'System'
    ProviderName = 'Service Control Manager'
    Id           = 7000, 7001, 7009, 7011, 7031
} | Select-Object TimeCreated, Id, LevelDisplayName, Message
```

Search an exported `.evtx` file:

```powershell
Get-WinEvent -Path 'C:\Temp\System.evtx' -Oldest
```

`FilterHashtable` filters the events while they are being collected. This is usually faster than loading the full log and filtering it afterward.

## Save Useful Evidence

### Copy a small number of events

1. Open the event.
2. Select **Copy**.
3. Choose **Copy Details as Text**.
4. Paste the details into the ticket or working notes.

### Export events

1. Apply the useful filter.
2. Select **Save Filtered Log File As**.
3. Save the file as `.evtx`.
4. Use a clear file name that includes the device, log, and date.

Example:

```text
PC-104_System_2026-08-01.evtx
```

An `.evtx` file keeps the full event data and is more useful than screenshots alone when the issue is being handed off or reviewed later.

## What to Document

Document:

* Device name
* Log and provider
* Event ID and level
* Event time and time zone
* Relevant message or error code
* How the time matches the reported issue
* Whether the event repeated when the issue was reproduced
* Exported file name or screenshot location
* What the event proved or ruled out

## References

* [Get-WinEvent documentation](https://learn.microsoft.com/powershell/module/microsoft.powershell.diagnostics/get-winevent)
* [Creating Get-WinEvent queries with FilterHashtable](https://learn.microsoft.com/powershell/scripting/samples/creating-get-winevent-queries-with-filterhashtable)
