# The Root Cause Handbook

A practical troubleshooting guide for IT professionals.

The handbook runs as a local MkDocs website. The setup checks PowerShell first, downloads the latest project from GitHub, prepares the local environment, validates the website, starts it, and opens it in the default browser.

## One-Command Setup

### Windows

Open **Windows PowerShell** and run:

```powershell
$u='https://raw.githubusercontent.com/tbenj1/root_cause_handbook/main/bootstrap-windows.ps1'; for($i=1;$i -le 3;$i++){try{$s=Invoke-RestMethod -Uri $u -UseBasicParsing -TimeoutSec 60;break}catch{if($i -eq 3){throw};Start-Sleep -Seconds (2*$i)}}; if($s -notmatch 'Root Cause Handbook Bootstrap'){throw 'The bootstrap download was not valid.'}; Invoke-Expression $s
```

The Windows bootstrap:

1. Checks the newest stable PowerShell release.
2. Finds the newest working PowerShell 7 installation already on the computer.
3. Uses WinGet to install or update PowerShell when WinGet is available.
4. Falls back to an official current-user PowerShell ZIP installation if WinGet cannot complete the update.
5. Verifies that the selected `pwsh.exe` starts and reports a supported version.
6. Continues directly into the handbook setup.

The fallback install normally does not require administrator access.

### macOS

Open **Terminal** and run:

```bash
/bin/bash -c 'set -e; t="$(mktemp)"; trap "rm -f \"$t\"" EXIT; curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 "https://raw.githubusercontent.com/tbenj1/root_cause_handbook/main/bootstrap-macos.sh" -o "$t"; grep -q "Root Cause Handbook Bootstrap" "$t"; /bin/bash "$t"'
```

The macOS bootstrap:

1. Checks the newest stable PowerShell release.
2. Finds the newest working PowerShell 7 installation already on the computer.
3. Detects Intel and Apple Silicon, including Terminal sessions running through Rosetta.
4. Updates a Homebrew-managed PowerShell installation through Homebrew.
5. Otherwise downloads Microsoft’s current macOS package and checks the installer signature.
6. Verifies the installed `pwsh` version.
7. Continues directly into the handbook setup.

macOS may ask for an administrator password when PowerShell has to be installed or updated. It does not ask for a password when the installed version is already current.

## What Happens After the PowerShell Check

After the operating-system check, the setup follows the same steps on Windows and macOS:

1. Downloads the latest handbook files from GitHub.
2. Checks the downloaded project before replacing the installed copy.
3. Stops the existing handbook server only after the new source is ready.
4. Backs up the current managed project files.
5. Updates the handbook in the current user’s application-data folder.
6. Downloads and verifies a project-local copy of `uv`.
7. Uses `uv` to provide Python 3.14 without requiring a separate Python installation.
8. Creates or repairs the local virtual environment.
9. Installs the locked MkDocs packages.
10. Runs a strict website build.
11. Starts the local website and checks its health endpoint.
12. Opens the handbook in the default browser.

Git and a separate Python installation are not required.

Run the same operating-system command again to check PowerShell, pull the latest handbook files, validate the project, and start the site.

## Default Install Locations

**Windows**

```text
%LOCALAPPDATA%\RootCauseHandbook
```

**macOS**

```text
~/Library/Application Support/RootCauseHandbook
```

## Local Launchers

After the repository is already on the computer:

* Windows: run `docs.cmd`
* macOS: run `docs.command`

Both launchers check PowerShell first and then run the local `run.ps1` file.

Keep the PowerShell or Terminal window open while using the handbook. Closing the window or pressing `Ctrl+C` stops the local website.

## Help

### Local launcher help

**Windows**

```cmd
docs.cmd -Help
```

**macOS**

```bash
./docs.command --help
```

### Windows bootstrap help

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap-windows.ps1 -Help
```

### macOS bootstrap help

```bash
./bootstrap-macos.sh --help
```

### Installer help

```powershell
pwsh -NoProfile -File ./install.ps1 -Help
```

### `run.ps1` help

```powershell
pwsh -NoProfile -File ./run.ps1 -Help
```

The website also includes a **Help and Setup** page.

## Common Commands

### Validate without opening the website

**Windows**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap-windows.ps1 -LocalRun -ValidateOnly -NoBrowser
```

**macOS**

```bash
./bootstrap-macos.sh --local-run --validate-only --no-browser
```

### Rebuild the local Python environment

**Windows**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap-windows.ps1 -LocalRun -ForceRepair
```

**macOS**

```bash
./bootstrap-macos.sh --local-run --force-repair
```

### Stop the local server

**Windows**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap-windows.ps1 -LocalRun -StopServer
```

**macOS**

```bash
./bootstrap-macos.sh --local-run --stop-server
```

### Use a different port

```powershell
pwsh -NoProfile -File ./run.ps1 -Port 8080
```

### Skip the PowerShell update check

Use this only for testing or when the installed PowerShell version has already been checked through another process.

**Windows**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap-windows.ps1 -LocalRun -SkipPowerShellUpdate
```

**macOS**

```bash
./bootstrap-macos.sh --local-run --skip-powershell-update
```

## Stability and Recovery

The setup includes the following controls:

* Network downloads retry after temporary failures.
* Setup and installation locks prevent two update processes from changing the same files at the same time.
* New project files are staged and checked before the update is treated as successful.
* The previous managed files are restored if the new version fails validation.
* A server that was running before a failed update is restarted after rollback.
* Server state includes the process ID, start time, Python path, project path, and port.
* The website must return the expected health marker before setup reports success.
* A port being used by another website is not stopped or overwritten.
* Runtime folders, virtual environments, and generated websites are not packaged in the repository.

The first setup requires internet access to download PowerShell when needed, the repository, `uv`, Python, and the locked Python packages. Later runs may still need internet access when an update or missing dependency has to be downloaded.

## Automated Checks

The GitHub Actions workflow runs on Windows and macOS. It:

1. Runs the static repository audit.
2. Parses every PowerShell file with the PowerShell language parser.
3. Checks the macOS launcher scripts for valid shell syntax.
4. Performs a clean local installation.
5. Builds and starts the website.
6. Checks the health endpoint.
7. Tests a failed update and rollback.
8. Stops the server and confirms the owning process exits cleanly.

Run the static project audit locally with:

```text
python tools/project_audit.py
```

## Project Files

| File | Purpose |
| --- | --- |
| `bootstrap-windows.ps1` | Checks or installs PowerShell on Windows and continues into setup |
| `bootstrap-macos.sh` | Checks or installs PowerShell on macOS and continues into setup |
| `install.ps1` | Downloads, updates, validates, and rolls back the handbook installation |
| `run.ps1` | Prepares the local environment, validates the site, and manages the local server |
| `docs.cmd` | Local Windows launcher |
| `docs.command` | Local macOS launcher |
| `mkdocs.yml` | Website configuration and navigation |
| `docs/` | Handbook pages and website assets |
| `tools/project_audit.py` | Static project validation |
