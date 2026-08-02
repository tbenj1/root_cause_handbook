# Documentation

Good documentation should let the next person understand what happened without having to rebuild the entire ticket from the beginning.

## Decide Where the Information Belongs

Once the issue is understood, decide whether the final notes are specific to one environment, useful to everyone, or both.

### Organization or Environment-Specific

The information is environment-specific when it depends on a setup that is unique to that organization.

Examples include:

* An organization-specific application setting
* A particular server name or network path
* A unique VPN configuration
* An organization-specific firewall rule
* A line-of-business application
* A specific printer setup
* An organization-specific security restriction
* A vendor account or support process
* A special restart or maintenance requirement

Put this information in the correct area of the organization’s IT Glue documentation or other approved documentation platform.

!!! warning "Keep protected information in the correct secure location"

    Do not place passwords, secret keys, tokens, or other protected information in general notes. Store them only in the approved secure location.

### Reusable Across Multiple Environments

The information is reusable when the same problem and fix could apply in more than one organization.

Examples include:

* A common Windows error
* A Microsoft 365 application issue
* A standard browser cache problem
* A common print spooler issue
* A repeatable Windows Update problem
* A common application repair process
* A standard way to collect logs
* A vendor-wide outage or known issue

Put reusable information in the shared knowledge base so it can be found again.

Keep organization-specific details out of the general article unless they are clearly marked as an example.

### Information That Belongs in Both Places

Some issues need both a general article and environment-specific notes.

For example:

* A general Outlook issue may have a standard troubleshooting article.
* One organization may use an add-in that changes the steps needed to fix it.

In this situation:

1. Create or update the general article.
2. Add the organization-specific details to the organization documentation.
3. Link the two records when possible.

## Update the Knowledge Base When It Will Be Useful Again

Create or update documentation when:

* The issue is likely to happen again
* The troubleshooting steps were not obvious
* The fix required several steps
* The issue involved an environment-specific configuration
* Existing documentation was wrong or incomplete
* The same issue has appeared in multiple tickets
* The fix would save someone time later
* The issue had to be escalated because important information was not documented

A useful article should include:

* Clear title
* Purpose or problem being addressed
* Symptoms
* Affected environment or products
* Error messages
* Required access or prerequisites
* Cause, when known
* Troubleshooting steps
* Resolution
* Verification steps
* Risks or warnings
* Rollback steps when needed
* When to escalate
* Related documentation
* Date reviewed or updated

### Example Article Title

Good:

> Outlook Remains Disconnected After Microsoft 365 Password Change

Not useful:

> Outlook Issue

## Final Review Before Publishing

Before saving or publishing the documentation, check:

* The title clearly explains what the article is about
* The steps are in the correct order
* The commands and paths are exact
* Any risk or approval requirement is clearly marked
* The verification step tests the original issue
* Environment-specific information is stored in the correct place
* Protected information is not exposed
* The article is written so another IT professional can follow it
