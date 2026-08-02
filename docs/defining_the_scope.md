# Defining the Scope

Use comparison testing to figure out where the issue follows and where it does not.

## Compare Users

* Does another user have the same issue on the affected computer?
* Can the affected user complete the same task on another computer?
* Does the issue follow the account or stay with the device?

## Compare Devices

* Does the issue happen on another computer?
* Does it happen on a mobile device?
* Is it limited to one workstation?
* Does another device of the same model have the same issue?

## Compare Networks and Locations

* Does the issue happen on both Wi-Fi and Ethernet?
* Does it happen from another office?
* Does it happen with the VPN connected and disconnected?
* Does it happen from a mobile hotspot?
* Does the issue only happen on one subnet, network, or public IP?

## Compare Applications and Profiles

* Does the browser version work while the desktop application fails?
* Does the issue happen in another browser?
* Does it happen in a private or incognito window?
* Does it happen under another Windows profile?
* Does it happen with add-ins or extensions disabled?

## Use the Result

These tests should help narrow the issue down to one or more of the following:

* User account
* Device
* Network
* Application
* Service
* Permissions
* Profile or cached data
* Site or location

!!! tip "Each test should answer a question"

    Do not run comparison tests just to collect more information. Know what each test is checking, document the result, and use that result to decide what to check next.
