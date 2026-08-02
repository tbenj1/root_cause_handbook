# Resolving Issues

## Start With the Least Disruptive Step

Only make changes that are safe, approved, and connected to the issue you are troubleshooting.

Common starting points include:

* Restarting the affected application
* Signing out and signing back in
* Restarting the computer when it makes sense for the issue
* Confirming the device has an internet connection
* Confirming the correct network or VPN is connected
* Checking available disk space
* Confirming the date and time are correct
* Testing another browser
* Clearing the browser cache when it applies
* Testing a private or incognito browser session
* Confirming cables and power connections
* Checking the selected printer, audio device, or display
* Confirming the correct username or account is being used
* Checking whether the account is locked or the password has expired
* Confirming the required service is running
* Checking whether Windows or the application is waiting for a restart
* Repeating the original test after each meaningful change

!!! important "Change one meaningful thing at a time"

    Do not make several unrelated changes at once. If several things are changed together, it becomes harder to know what fixed the issue and harder to undo the change if something goes wrong.

## Check the Result After Each Change

After a meaningful change, document:

* What was changed
* Why it was changed
* What the expected result was
* What happened after the change
* Whether the issue improved, stayed the same, or became worse
* Whether the change needs to be rolled back

## Confirm the Issue Is Actually Fixed

A service starting, a command finishing, or an error disappearing is not enough by itself.

Repeat the task the user originally could not complete and make sure:

* The expected result now occurs
* The issue does not immediately return
* The fix did not create another problem
* The user can complete the task from their normal account, device, and location
* Any temporary workaround is clearly documented as temporary

## Document the Resolution

Every resolved ticket should explain:

* What was reported
* Who and what were affected
* When and where it happened
* How far the issue reached
* The exact symptoms or error message
* What was checked
* What troubleshooting was completed
* What evidence was collected
* What caused the issue, when known
* What fixed the issue
* How the fix was tested
* Whether the user confirmed the result
* Whether documentation was created or updated

Avoid notes such as:

* “Fixed.”
* “Resolved.”
* “Restarted computer.”
* “User is all set.”
* “Changed settings.”

These notes do not explain what happened or help anyone who looks at the ticket later.

### Example Resolution Note

> The user reported that Outlook opened but stayed disconnected and would not send or receive messages. The issue affected only this user and only happened on the assigned workstation. Webmail worked normally.
>
> Confirmed internet access and verified that Microsoft 365 was working for other users. Restarted Outlook with no change. Credential Manager contained an old Microsoft 365 credential from before the user’s recent password change. Removed the outdated credential and reopened Outlook. The user signed in with the current password, Outlook showed “Connected,” and a test email was sent and received successfully.
>
> The user confirmed that email was working normally again. No other users were affected.
