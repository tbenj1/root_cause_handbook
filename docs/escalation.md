# Escalation

!!! important "Escalation is a handoff, not a reset"

    Escalate when the issue needs access, experience, authority, or risk approval that you do not have. The person taking over should be able to continue from your notes instead of repeating the entire investigation.

Escalate when:

* The issue is outside your approved access or responsibility
* A server, firewall, network device, or business-critical system needs a change you are not authorized to make
* The issue may involve a security incident
* Data may be lost or corrupted
* Multiple organizations, locations, or major business functions are affected
* A vendor outage or service-wide issue is suspected
* The next troubleshooting step is risky, destructive, or difficult to reverse
* The documented troubleshooting steps have been completed without fixing the issue
* The issue requires a specialist in an application, network, server, cloud, database, or security platform
* The business impact requires immediate involvement from another team or owner

!!! warning "Do not send an empty escalation"

    A note that only says *User cannot access application. Please investigate.* does not give the next person enough information to start.

Include:

* User and organization
* Affected device, account, application, or service
* User location
* When the issue started
* Number of affected users or devices
* Business impact
* Exact symptoms
* Exact error messages
* Screenshots
* Relevant logs or Event Viewer entries
* Troubleshooting already completed
* Result of each troubleshooting step
* Related IT Glue or internal documentation
* Recent changes
* Current status
* The specific help, access, or action needed

## Example Escalation Note

> The user cannot connect to the organization VPN from the company laptop while working from home. The issue started at approximately 8:00 AM today. The user is the only person currently reported as affected.
>
> Confirmed the user has internet access and can browse websites. Restarted the laptop and home router. Verified that the correct VPN profile is selected. The VPN client shows error 809 during every connection attempt.
>
> Tested from the user’s mobile hotspot and received the same error, which makes the home network less likely to be the cause. Confirmed the user’s account is active and not locked. Reviewed IT Glue and did not find any environment-specific instructions for this error.
>
> Event Viewer shows a RasClient error at the same time as each failed attempt. The screenshot and event details are attached. Escalating for review of the VPN account, gateway logs, and server-side configuration.

## Before You Escalate

Make sure:

* The notes are current
* The time zone is included when timing matters
* Commands, event IDs, paths, and error messages are exact
* Screenshots and exports are attached
* The next person knows what has already been ruled out
* The request clearly explains what is needed from them
