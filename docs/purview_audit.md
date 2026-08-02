# Microsoft Purview Audit

Use Microsoft Purview Audit to answer who did what, when it happened, and which Microsoft 365 object was affected. Depending on the workload, the record may also include the source IP address, client, parameters, and affected items.

!!! important "Use audit data only for an approved reason"

    Audit searches can expose user, mailbox, file, administrative, and security activity. Run a search only for an approved support, security, compliance, or legal reason. Keep the search and exported data limited to what the investigation needs.

## What Purview Audit Can Help With

Use it to investigate:

* Suspicious or compromised account activity
* Mailbox forwarding changes
* Inbox rule creation or changes
* Deleted or purged email
* File access, download, deletion, rename, or sharing
* SharePoint and OneDrive activity
* Teams and other Microsoft 365 activity
* Administrative and configuration changes
* Actions completed by delegates or service accounts

Audit records show that an action was recorded. They do not automatically prove intent, approval, or root cause.

## Required Access

Make sure the account running the search has the **Audit Logs** or **View-Only Audit Logs** role in Microsoft Purview. PowerShell searches also need the related Exchange Online permissions.

What you can find depends on licensing, retention, workload settings, when auditing was enabled, and how old the event is.

If you do not have the required role, stop and request access. Do not use another administrator’s session.

## Define the Search First

Write down:

* The question you are trying to answer
* User, mailbox, file, site, team, or service involved
* Start and end date
* Time zone used in the report
* Known IP address, operation, or object name
* Activity that may be expected or approved
* Who authorized the search

Start with a narrow search. Tenant-wide searches take longer and return much more unrelated activity.

## Run the Audit Search

1. Sign in to the **Microsoft Purview portal**.
2. Select **Audit**. If it is not shown, select **View all solutions**, then choose **Audit** under **Core**.
3. On the **Search** page, set the start and end date and time.
4. Give the search a name that explains what it is for.
5. Add only the filters that help:
   * Keyword
   * Activities using friendly names
   * Activities using exact operation names
   * Users
   * Record types
   * File, folder, or site
   * Workloads
6. Select **Search**.
7. Wait for the search job to finish.
8. Open the completed search and review the results.

The search job continues if the browser is closed. Completed search jobs are kept for 30 days. A portal search can cover up to 180 days, but the records available still depend on licensing, retention, and when auditing was enabled.

Audit events are not always available immediately. Some events appear quickly and others can take longer, so do not treat an empty recent search as proof that nothing happened.

!!! warning "Audit results use UTC"

    Convert the user’s local time to UTC before searching. When timing matters, document both the local time and UTC so the event can be matched correctly.

## Read the Results

The results normally include fields such as:

| Field | What to check |
| --- | --- |
| Date (UTC) | When the activity happened |
| IP address | Source address recorded for the activity |
| User | Account that completed the action |
| Record type | Microsoft service or audit category |
| Activity | Friendly operation name |
| Item | File, mailbox, site, or other target |
| Details | Additional information about the action |

Open the specific record and review the detailed properties. Useful fields may include:

* `UserId`
* `Operation`
* `ObjectId`
* `ClientIP`
* `UserAgent`
* `Workload`
* `ResultStatus`
* `Parameters`
* `AffectedItems`
* Site, file, mailbox, folder, or message identifiers

Not every service records every field.

## Review the Audit in This Order

### 1. Build the timeline

Sort by date and look for:

* The first relevant or suspicious action
* Actions immediately before and after it
* Repeated actions
* A change followed by the reported issue
* A later action that reversed or fixed the change

### 2. Check the account that performed the action

Compare the account with:

* The expected owner
* Known administrators
* Delegates
* Automation accounts or service principals
* The user’s normal job role

A known account can still be compromised. An unfamiliar account may be a legitimate service or delegated administrator.

### 3. Check the source

Review the IP address and client details when they are available. Compare them with:

* Known company public IP addresses
* VPN or security gateway addresses
* Microsoft service addresses
* Expected location and device use
* Microsoft Entra sign-in logs when authentication is part of the issue

Use Entra sign-in logs for sign-in risk, authentication details, and Conditional Access results. Purview Audit and Entra logs answer different parts of the investigation.

### 4. Check the object and action

Make sure the operation affected the mailbox, file, rule, forwarding address, site, or account you are investigating. Read the detailed parameters instead of relying only on the friendly activity name.

### 5. Compare the action with approved work

Check tickets, change records, user requests, and internal documentation. The audit log can show that a change happened. The ticket or change record shows whether it was expected and approved.

## Common Investigations

### Find who configured mailbox forwarding

1. Search the date range that covers the change.
2. Leave **Activities** blank so Exchange administrative operations are included.
3. Filter the completed results for `Set-Mailbox`.
4. Open the related records.
5. Check:
   * `ObjectId` for the affected mailbox
   * `Parameters` for `ForwardingSmtpAddress`
   * `DeliverToMailboxAndForward`
   * `UserId` for the account that made the change

Document the forwarding address exactly. Do not remove it until the change is confirmed as wrong or unauthorized and the response is approved.

### Find an inbox rule that was created or changed

Search Exchange mailbox activity for:

* `New-InboxRule`
* Inbox rule changes made through Outlook

Check the rule name, conditions, actions, target folders, forwarding or redirect settings, and the account shown in the event.

### Investigate deleted email

Search Exchange mailbox activity for:

* Messages deleted from Deleted Items using `SoftDelete`
* Messages purged from the mailbox using `HardDelete`

Check `AffectedItems` for the subject, previous location, and other message details. The person who deleted the message may not be the mailbox owner, especially with shared mailboxes or delegation.

### Investigate suspicious account activity

1. Search the affected user over the known time range.
2. Review mailbox, file, and other activity along with recorded IP addresses.
3. Look for forwarding, inbox rules, downloads, sharing, deletion, or administrative changes.
4. Compare the findings with Entra sign-in logs, security alerts, and the incident timeline.
5. Export the useful evidence before the fix changes the current configuration.

A successful external authentication event does not prove that data was accessed. Look for the actions that happened after the sign-in.

### Search activity in a shared mailbox

The **Users** filter searches for activity performed by the selected user. It does not always return every action completed inside a specific shared mailbox.

When the search needs to be limited to a shared mailbox, use `Search-UnifiedAuditLog` with the mailbox Exchange GUID or escalate to someone with the required experience and access.

## Export the Results

1. Open the completed search job.
2. Filter the results when needed.
3. Select **Export**.
4. Download the CSV.
5. Save it with the approved ticket or investigation record.

Audit Standard portal exports support up to 50,000 rows per search. Audit Premium supports a larger export. Narrow the search instead of depending on the maximum export size.

## Expand `AuditData` in Excel

The exported CSV contains an `AuditData` column with JSON data.

1. Open a blank Excel workbook.
2. Select **Data > From Text/CSV**.
3. Select the exported CSV.
4. Select **Transform Data**.
5. In Power Query, right-click `AuditData`.
6. Select **Transform > JSON**.
7. Select the expand icon on the column.
8. Select **Load more** when needed.
9. Choose the fields needed for the investigation.
10. Select **Close & Load**.

Useful fields often include operation, user, client IP, object ID, workload, result status, parameters, affected items, file name, site URL, and mailbox identifiers.

!!! tip "Narrow down the results before expanding the JSON"

    Power Query builds its first field list from a sample of the data. Filter the audit results or operation column first when the export contains many different record types.

## PowerShell Example

Run audit cmdlets through Exchange Online PowerShell with the required permissions.

```powershell
$start = (Get-Date).AddDays(-1).ToUniversalTime()
$end = (Get-Date).ToUniversalTime()

$results = Search-UnifiedAuditLog `
    -StartDate $start `
    -EndDate $end `
    -UserIds 'user@example.com' `
    -SessionCommand ReturnLargeSet

$results |
    Select-Object CreationDate, UserIds, Operations, AuditData |
    Export-Csv -Path 'C:\Temp\PurviewAudit.csv' -NoTypeInformation
```

The cmdlet returns a limited set of results by default. Large or repeatable searches need consistent parameters, session handling, and result counts. Use the portal for normal investigations and get additional help for large or complex collections.

## What to Document

Document:

* Search authorization and reason
* Search name
* Date range and time zone
* Users, activities, record types, workloads, and objects included
* Search completion time
* Relevant operations and times
* Account, source IP, target object, and parameters
* Exported file name and storage location
* Related ticket, sign-in event, alert, or change record
* Conclusion and next action

## References

* [Search the audit log](https://learn.microsoft.com/purview/audit-search)
* [Investigate common support issues with the audit log](https://learn.microsoft.com/purview/audit-troubleshooting-scenarios)
* [Export, configure, and view audit records](https://learn.microsoft.com/purview/audit-log-export-records)
* [Detailed properties in the audit log](https://learn.microsoft.com/purview/audit-log-detailed-properties)
* [Search-UnifiedAuditLog](https://learn.microsoft.com/powershell/module/exchangepowershell/search-unifiedauditlog)
