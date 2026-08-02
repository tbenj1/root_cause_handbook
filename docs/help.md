# Setup and Help

Use this page when you need to install, update, validate, start, stop, or repair the local handbook.

## What the Setup Does

The setup checks PowerShell first. If PowerShell 7 is missing or out of date, it installs or updates it and then continues into the rest of the setup.

After that, it:

1. Downloads the latest handbook files from GitHub.
2. Checks the project before replacing the installed copy.
3. Installs the handbook in the current user’s application-data folder.
4. Downloads the local setup tools and Python version needed by the project.
5. Creates or repairs the local environment.
6. Runs a strict website build.
7. Starts the local website.
8. Checks the health endpoint.
9. Opens the handbook in the default browser.

Git and a separate Python installation are not required.

## Install or Update on Windows

Open **Windows PowerShell** and run:

```powershell
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';$u='https://raw.githubusercontent.com/tbenj1/root_cause_handbook/main/bootstrap-windows.ps1';$f=Join-Path $env:TEMP ('RootCauseHandbook-bootstrap-'+[guid]::NewGuid().ToString('N')+'.ps1');try{Write-Host '[>] Downloading the Root Cause Handbook bootstrap.';for($i=1;$i -le 3;$i++){try{Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing -TimeoutSec 60;break}catch{if($i -eq 3){throw};Start-Sleep -Seconds (2*$i)}};$t=Get-Content -LiteralPath $f -Raw;if($t -notmatch 'Root Cause Handbook Bootstrap'){throw 'The bootstrap download was not valid.'};Write-Host '[>] Starting the Root Cause Handbook setup.';& $f}finally{Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue}
```

The command downloads the bootstrap to a temporary file instead of running the downloaded text through `Invoke-Expression`. This keeps setup errors visible in the PowerShell window.

The first run can take several minutes. The browser does not open until PowerShell, Python, the website packages, and the handbook itself have all passed their checks.

The default install path is:

```text
%LOCALAPPDATA%\RootCauseHandbook
```

Windows setup output is saved to:

```text
%TEMP%\RootCauseHandbook-bootstrap.log
```

## Install or Update on macOS

Open **Terminal** and run:

```bash
/bin/bash -c 'set -e; t="$(mktemp)"; trap "rm -f \"$t\"" EXIT; curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 "https://raw.githubusercontent.com/tbenj1/root_cause_handbook/main/bootstrap-macos.sh" -o "$t"; grep -q "Root Cause Handbook Bootstrap" "$t"; /bin/bash "$t"'
```

The default install path is:

```text
~/Library/Application Support/RootCauseHandbook
```

macOS may ask for an administrator password when PowerShell has to be installed or updated.

## Start the Local Copy

After the project is already downloaded:

* Windows: run `docs.cmd`
* macOS: run `docs.command`

Keep the PowerShell or Terminal window open while using the handbook. Closing the window or pressing ++ctrl+c++ stops the local website.

## Validate the Website

### Windows

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap-windows.ps1 -LocalRun -ValidateOnly -NoBrowser
```

### macOS

```bash
./bootstrap-macos.sh --local-run --validate-only --no-browser
```

Validation checks the project, repairs the environment when needed, and runs a strict MkDocs build without opening the browser.

## Repair the Local Environment

Use this when the environment is damaged, dependencies are missing, or the site no longer starts correctly.

### Windows

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap-windows.ps1 -LocalRun -ForceRepair
```

### macOS

```bash
./bootstrap-macos.sh --local-run --force-repair
```

## Stop the Local Server

### Windows

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap-windows.ps1 -LocalRun -StopServer
```

### macOS

```bash
./bootstrap-macos.sh --local-run --stop-server
```

## Use a Different Port

The default port is `8000`.

```powershell
pwsh -NoProfile -File ./run.ps1 -Port 8080
```

Then open:

```text
http://127.0.0.1:8080
```

## Common Options

| What you need to do | Windows option | macOS option |
| --- | --- | --- |
| Use a different install folder | `-InstallPath PATH` | `--install-path PATH` |
| Use a different website port | `-Port 8080` | `--port 8080` |
| Do not open the browser | `-NoBrowser` | `--no-browser` |
| Validate without starting the site | `-ValidateOnly` | `--validate-only` |
| Rebuild the managed installation | `-Reinstall` | `--reinstall` |
| Rebuild the local Python environment | `-ForceRepair` with `-LocalRun` | `--force-repair` with `--local-run` |
| Stop the managed server | `-StopServer` with `-LocalRun` | `--stop-server` with `--local-run` |
| Skip the online PowerShell update check | `-SkipPowerShellUpdate` | `--skip-powershell-update` |

Use the update-skip option only when PowerShell has already been checked or the device is temporarily offline and a supported PowerShell 7 installation is already available.

## Show Command Help

### Windows local launcher

```cmd
docs.cmd -Help
```

### macOS local launcher

```bash
./docs.command --help
```

### Windows bootstrap

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap-windows.ps1 -Help
```

### macOS bootstrap

```bash
./bootstrap-macos.sh --help
```

### Installer

```powershell
pwsh -NoProfile -File ./install.ps1 -Help
```

### `run.ps1` launcher

```powershell
pwsh -NoProfile -File ./run.ps1 -Help
```

## Common Issues

### The port is already in use

Use another port:

```powershell
pwsh -NoProfile -File ./run.ps1 -Port 8080
```

The launcher will not stop or overwrite a different website that is already using the selected port.

### The browser did not open

First, open the local address manually:

```text
http://127.0.0.1:8000
```

If the page opens, the server is working and only the automatic browser launch failed.

On Windows, check the setup log:

```text
%TEMP%\RootCauseHandbook-bootstrap.log
```

You can also start the installed copy directly:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\RootCauseHandbook\run.ps1"
```

If port `8000` is already being used, run the launcher with another port such as `-Port 8080`.

### Validation failed

Check the runtime logs in:

```text
.runtime
```

Run a repair and validate again. If the update failed after an older copy was already installed, the installer attempts to restore the previous working version.

### PowerShell could not be updated

Make sure the device can reach GitHub and Microsoft’s PowerShell download locations. On macOS, a PowerShell installation or update may require administrator approval. On Windows, the setup uses WinGet first and then falls back to a current-user portable install.

## More Detailed Setup Information

The repository `README.md` contains the complete setup, options, installation paths, recovery behavior, and automated test details.
