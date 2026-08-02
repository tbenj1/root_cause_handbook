# Microsoft Update Catalog and Driver Identification

Use this process when Windows shows an unknown device, a missing driver, a device status error, or a driver that has to be found manually.

!!! important "Use the Catalog only when you can confirm the match"

    Start with the computer or hardware manufacturer whenever possible. Use the Microsoft Update Catalog when you can match the exact device and driver and the change is approved.

## Use This Driver Source Order

Unless your organization has a different standard, check in this order:

1. Computer or hardware manufacturer support site
2. Windows Update, including approved optional driver updates
3. Microsoft Update Catalog
4. A package supplied by the vendor through an approved support case

Do not download drivers from generic driver-download websites.

## Document the Current Driver Information

Before changing anything, document:

* Computer manufacturer and model
* Windows edition, version, build, and architecture
* Device Manager display name
* Device status and status code
* Current driver provider
* Driver date and version
* Hardware IDs
* Whether the device worked before
* When the issue started and what changed around that time

Make sure there is a reasonable way to roll back or restore the original state.

## Find the Hardware ID in Device Manager

1. Open **Device Manager**.
2. Find the affected or unknown device.
3. Right-click it and select **Properties**.
4. On the **General** tab, document the device status message and code.
5. Open the **Driver** tab and document the provider, date, and version.
6. Open the **Details** tab.
7. Under **Property**, select **Hardware Ids**.
8. Copy the first and most specific ID.
9. Save the remaining IDs in case the first one does not return a result.

Example PCI hardware ID:

```text
PCI\VEN_8086&DEV_51F0&SUBSYS_00748086&REV_01
```

Hardware IDs tell Windows which INF packages can apply to the device. The list usually starts with the most specific match and becomes more general.

!!! warning "Start with the most specific ID"

    A general compatible ID can match an entire device class. Search the most specific hardware ID first so you are less likely to select the wrong package.

## Search the Microsoft Update Catalog

The Catalog can search by driver model, manufacturer, class, or hardware ID.

1. Open the [Microsoft Update Catalog](https://www.catalog.update.microsoft.com/).
2. Paste the most specific hardware ID into the search box.
3. Search the full ID first.
4. If there is no result, remove only the revision section and search again.
5. Add the manufacturer, device class, or Windows version when there are too many results.

Example search order:

```text
PCI\VEN_8086&DEV_51F0&SUBSYS_00748086&REV_01
```

```text
PCI\VEN_8086&DEV_51F0&SUBSYS_00748086
```

Do not immediately reduce the search to only `VEN` and `DEV`. That can return drivers for different subsystem versions of the same general device.

## Confirm the Driver Matches

Open the update details and check:

* Driver manufacturer
* Driver model
* Driver class
* Supported products
* Architecture
* Driver version
* Driver date
* Package size

Do not choose a driver only because it has the newest date. It still has to match the hardware and the operating system. Windows first checks how well the identification strings in the driver package match the device. Date and version matter after compatible packages are found.

### Driver Selection Checklist

- [ ] Hardware ID or exact model matches
- [ ] Device class matches
- [ ] Windows client or server family matches
- [ ] Architecture matches
- [ ] Driver provider is expected
- [ ] Driver date and version make sense for the issue
- [ ] Package is approved for the environment
- [ ] A rollback method is available

## Download and Extract the Driver

Catalog drivers are often downloaded as `.cab` files.

Create a folder for the extracted files:

```cmd
mkdir C:\Temp\DriverExtracted
```

Extract the cabinet:

```cmd
expand "C:\Temp\driver.cab" -F:* "C:\Temp\DriverExtracted"
```

Look for one or more `.inf` files in the extracted folder. Keep the `.cat`, `.sys`, `.dll`, and other package files with the INF.

## Install the Driver

### Device Manager

1. Right-click the device.
2. Select **Update driver**.
3. Select **Browse my computer for drivers**.
4. Select the extracted folder.
5. Leave **Include subfolders** selected.
6. Continue only when Windows finds a matching driver.

### PnPUtil

Open an elevated terminal and run:

```cmd
pnputil /add-driver "C:\Temp\DriverExtracted\*.inf" /subdirs /install
```

PnPUtil adds matching packages to the Windows driver store and tries to install the driver on devices that match.

!!! warning "Do not force an unrelated INF"

    Stop when Windows says there is no matching device. Go back and check the hardware ID, operating system, architecture, and package details instead of forcing a driver made for different hardware.

## Test the Device

1. Refresh or reopen Device Manager.
2. Make sure the warning icon and status code are gone.
3. Confirm the expected driver provider, date, and version.
4. Test what the device is supposed to do.
5. Check Event Viewer for new driver or device errors.
6. Restart only when it is required and approved.

A successful installation message does not prove the device is working. Test the actual audio, network, display, USB, camera, storage, or other function.

## Roll Back the Driver

If the new driver causes an issue:

1. Open the device **Properties**.
2. Open the **Driver** tab.
3. Select **Roll Back Driver** when it is available.
4. Restart when required.
5. Test the original function again.

When rollback is not available, use the approved manufacturer package or restore method instead of trying unrelated driver versions.

## What to Document

Document:

* Device and hardware ID
* Original provider, date, and version
* Catalog result that was selected
* New provider, date, and version
* Downloaded package name
* Installation method
* Whether a restart was required
* How the device was tested
* Rollback method

## References

* [Hardware IDs for Windows devices](https://learn.microsoft.com/windows-hardware/drivers/install/hardware-ids)
* [Microsoft Update Catalog FAQ](https://www.catalog.update.microsoft.com/Faq.aspx)
* [Download drivers and updates from the Microsoft Update Catalog](https://learn.microsoft.com/troubleshoot/windows-client/installing-updates-features-roles/download-updates-drivers-hotfixes-windows-update-catalog)
* [How Windows selects a driver package](https://learn.microsoft.com/windows-hardware/drivers/install/how-windows-selects-a-driver-for-a-device)
* [PnPUtil command examples](https://learn.microsoft.com/windows-hardware/drivers/devtest/pnputil-examples)
