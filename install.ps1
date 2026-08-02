[CmdletBinding()]
param(
    [string]$InstallPath,

    [ValidateRange(1024, 65535)]
    [int]$Port = 8000,

    [switch]$NoBrowser,

    [switch]$Reinstall,

    [switch]$ValidateOnly,

    [string]$SourcePath,

    [switch]$Help
)

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'PowerShell 7 or newer is required.'
}

if (-not ($IsWindows -or $IsMacOS)) {
    throw 'This script only runs on Windows or macOS.'
}

if ($Help) {
    @'
Root Cause Handbook installer

Usage:
  pwsh -NoProfile -File ./install.ps1 [options]

Options:
  -InstallPath PATH          Use a custom handbook installation path.
  -Port PORT                 Use a different local website port. Default: 8000.
  -NoBrowser                 Do not open the browser automatically.
  -Reinstall                 Rebuild the managed installation and environment.
  -ValidateOnly              Validate the website without starting it.
  -SourcePath PATH           Use a local repository folder as the source.
  -Help                      Show this help.

Examples:
  pwsh -NoProfile -File ./install.ps1
  pwsh -NoProfile -File ./install.ps1 -ValidateOnly -NoBrowser
  pwsh -NoProfile -File ./install.ps1 -SourcePath ./ -InstallPath ./TestInstall -ValidateOnly -NoBrowser
'@ | Write-Host
    exit 0
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$RepositoryOwner = 'tbenj1'
$RepositoryName = 'root_cause_handbook'
$RepositoryBranch = 'main'
$SiteName = 'The Root Cause Handbook'
$HealthMarker = 'root-cause-handbook-health-v1'
$ManagedItems = @(
    'docs',
    'overrides',
    'tools',
    'bootstrap-windows.ps1',
    'bootstrap-macos.sh',
    'docs.cmd',
    'docs.command',
    'install.ps1',
    'mkdocs.yml',
    'README.md',
    'requirements.lock.txt',
    'run.ps1'
)
$RemovedManagedItems = @(
    '.github',
    '.gitignore',
    '.python-version',
    'requirements.in',
    'FUNCTIONAL_AUDIT.md',
    'docs/assets/images/README.txt'
)

function Write-InstallerMessage {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Step', 'Success', 'Skip', 'Warning')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    switch ($Level) {
        'Step'    { Write-Host "[>] $Message" }
        'Success' { Write-Host "[+] $Message" -ForegroundColor Green }
        'Skip'    { Write-Host "[-] $Message" -ForegroundColor DarkGray }
        'Warning' { Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    }
}

function Invoke-DownloadFile {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$OutFile,

        [ValidateRange(1, 10)]
        [int]$Attempts = 3
    )

    $lastError = $null

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -TimeoutSec 300

            if (-not (Test-Path -LiteralPath $OutFile -PathType Leaf)) {
                throw 'The download did not create a file.'
            }

            if ((Get-Item -LiteralPath $OutFile).Length -le 0) {
                throw 'The downloaded file is empty.'
            }

            return
        }
        catch {
            $lastError = $_

            if ($attempt -lt $Attempts) {
                Write-InstallerMessage -Level Warning -Message "Download attempt $attempt failed. Retrying. $($_.Exception.Message)"
                Start-Sleep -Seconds ([Math]::Min(8, [Math]::Pow(2, $attempt)))
            }
        }
    }

    throw "The file could not be downloaded after $Attempts attempts. $($lastError.Exception.Message)"
}

function Get-DefaultInstallPath {
    if ($IsWindows) {
        $localAppData = [Environment]::GetFolderPath('LocalApplicationData')

        if ([string]::IsNullOrWhiteSpace($localAppData)) {
            $localAppData = Join-Path $HOME 'AppData\Local'
        }

        return Join-Path $localAppData 'RootCauseHandbook'
    }

    if ($IsMacOS) {
        return Join-Path $HOME 'Library/Application Support/RootCauseHandbook'
    }

    throw 'This installer currently supports Windows and macOS.'
}

function Get-HealthUri {
    param(
        [Parameter(Mandatory)]
        [string]$Homepage
    )

    return ([Uri]::new([Uri]$Homepage, 'assets/health.txt')).AbsoluteUri
}

function Get-HandbookStatus {
    param(
        [Parameter(Mandatory)]
        [string]$Homepage
    )

    try {
        $healthResponse = Invoke-WebRequest -Uri (Get-HealthUri -Homepage $Homepage) -TimeoutSec 2 -NoProxy

        if (
            $healthResponse.StatusCode -eq 200 -and
            $healthResponse.Content.Trim() -eq $HealthMarker
        ) {
            return 'Running'
        }

        return 'DifferentSite'
    }
    catch {
        try {
            $homepageResponse = Invoke-WebRequest -Uri $Homepage -TimeoutSec 2 -NoProxy

            if (
                $homepageResponse.StatusCode -eq 200 -and
                $homepageResponse.Content -match [regex]::Escape($SiteName)
            ) {
                return 'RunningLegacy'
            }

            return 'DifferentSite'
        }
        catch {
            return 'Stopped'
        }
    }
}

function Test-RepositorySource {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    foreach ($requiredItem in ($ManagedItems + 'docs/assets/health.txt')) {
        $requiredPath = Join-Path $Path $requiredItem

        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "The repository source is missing $requiredItem."
        }
    }

    $healthFile = Join-Path $Path 'docs/assets/health.txt'

    if ((Get-Content -LiteralPath $healthFile -Raw).Trim() -ne $HealthMarker) {
        throw 'The downloaded repository has an invalid health marker.'
    }
}

function Stop-InstalledServer {
    param(
        [Parameter(Mandatory)]
        [string]$TargetPath,

        [Parameter(Mandatory)]
        [string]$PowerShellPath,

        [Parameter(Mandatory)]
        [string]$Homepage
    )

    $status = Get-HandbookStatus -Homepage $Homepage

    if ($status -eq 'DifferentSite') {
        throw "Port $Port is being used by another website. Use another port before updating the handbook."
    }

    if ($status -notin @('Running', 'RunningLegacy')) {
        return $false
    }

    $existingRunScript = Join-Path $TargetPath 'run.ps1'

    if (-not (Test-Path -LiteralPath $existingRunScript -PathType Leaf)) {
        throw 'The handbook is running, but its launcher could not be found. Stop the current process before updating.'
    }

    Write-InstallerMessage -Level Step -Message 'Stopping the current handbook server before updating it.'
    $stopOutput = & $PowerShellPath -NoLogo -NoProfile -File $existingRunScript -Port $Port -NoBrowser -StopServer 2>&1
    $stopExitCode = $LASTEXITCODE

    foreach ($line in @($stopOutput)) {
        if (-not [string]::IsNullOrWhiteSpace("$line")) {
            Write-Host $line
        }
    }

    if ($stopExitCode -ne 0) {
        throw 'The current handbook server could not be stopped safely.'
    }

    for ($attempt = 1; $attempt -le 20; $attempt++) {
        if ((Get-HandbookStatus -Homepage $Homepage) -eq 'Stopped') {
            return $true
        }

        Start-Sleep -Milliseconds 250
    }

    throw 'The current handbook server did not stop within five seconds.'
}

function Copy-ManagedContent {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    foreach ($itemName in $ManagedItems) {
        $destinationItem = Join-Path $Destination $itemName
        $sourceItem = Join-Path $Source $itemName

        if (Test-Path -LiteralPath $destinationItem) {
            Remove-Item -LiteralPath $destinationItem -Recurse -Force
        }

        Copy-Item -LiteralPath $sourceItem -Destination $destinationItem -Recurse -Force
    }

    foreach ($itemName in $RemovedManagedItems) {
        $destinationItem = Join-Path $Destination $itemName
        Remove-Item -LiteralPath $destinationItem -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Backup-ManagedContent {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Backup
    )

    New-Item -ItemType Directory -Path $Backup -Force | Out-Null

    foreach ($itemName in $ManagedItems) {
        $sourceItem = Join-Path $Source $itemName

        if (Test-Path -LiteralPath $sourceItem) {
            $backupItem = Join-Path $Backup $itemName
            Copy-Item -LiteralPath $sourceItem -Destination $backupItem -Recurse -Force
        }
    }
}

function Restore-ManagedContent {
    param(
        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [string]$Backup
    )

    Write-InstallerMessage -Level Warning -Message 'Restoring the previous handbook files.'

    foreach ($itemName in $ManagedItems) {
        $destinationItem = Join-Path $Destination $itemName

        if (Test-Path -LiteralPath $destinationItem) {
            Remove-Item -LiteralPath $destinationItem -Recurse -Force -ErrorAction SilentlyContinue
        }

        $backupItem = Join-Path $Backup $itemName

        if (Test-Path -LiteralPath $backupItem) {
            Copy-Item -LiteralPath $backupItem -Destination $destinationItem -Recurse -Force
        }
    }
}

function Test-TextFilesEqual {
    param(
        [Parameter(Mandatory)]
        [string]$FirstPath,

        [Parameter(Mandatory)]
        [string]$SecondPath
    )

    if (
        -not (Test-Path -LiteralPath $FirstPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $SecondPath -PathType Leaf)
    ) {
        return $false
    }

    $firstText = (Get-Content -LiteralPath $FirstPath -Raw).Replace("`r`n", "`n")
    $secondText = (Get-Content -LiteralPath $SecondPath -Raw).Replace("`r`n", "`n")
    return ($firstText -ceq $secondText)
}

function Move-LocalStateToBackup {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Backup
    )

    New-Item -ItemType Directory -Path $Backup -Force | Out-Null

    foreach ($itemName in @('.venv', '.runtime')) {
        $sourceItem = Join-Path $Source $itemName

        if (Test-Path -LiteralPath $sourceItem) {
            Move-Item -LiteralPath $sourceItem -Destination (Join-Path $Backup $itemName) -Force
        }
    }
}

function Restore-LocalState {
    param(
        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [string]$Backup
    )

    foreach ($itemName in @('.venv', '.runtime')) {
        $destinationItem = Join-Path $Destination $itemName
        $backupItem = Join-Path $Backup $itemName

        if (Test-Path -LiteralPath $destinationItem) {
            Remove-Item -LiteralPath $destinationItem -Recurse -Force -ErrorAction SilentlyContinue
        }

        if (Test-Path -LiteralPath $backupItem) {
            Move-Item -LiteralPath $backupItem -Destination $destinationItem -Force
        }
    }
}

function Enter-InstallLock {
    param(
        [Parameter(Mandatory)]
        [string]$LockFile
    )

    try {
        return [IO.File]::Open(
            $LockFile,
            [IO.FileMode]::OpenOrCreate,
            [IO.FileAccess]::ReadWrite,
            [IO.FileShare]::None
        )
    }
    catch [IO.IOException] {
        throw 'Another handbook install or update is already running.'
    }
}

function Start-RolledBackServer {
    param(
        [Parameter(Mandatory)]
        [string]$PowerShellPath,

        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    $runScript = Join-Path $TargetPath 'run.ps1'

    if (-not (Test-Path -LiteralPath $runScript -PathType Leaf)) {
        return
    }

    try {
        $arguments = @('-NoLogo', '-NoProfile')

        if ($IsWindows) {
            $arguments += @('-ExecutionPolicy', 'Bypass')
        }

        $arguments += @('-File', $runScript, '-Port', "$Port", '-NoBrowser')

        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $PowerShellPath
        $startInfo.WorkingDirectory = $TargetPath
        $startInfo.UseShellExecute = $false

        foreach ($argument in $arguments) {
            $startInfo.ArgumentList.Add([string]$argument)
        }

        [Diagnostics.Process]::Start($startInfo) | Out-Null
        Write-InstallerMessage -Level Warning -Message 'The previous handbook version was restored and restarted.'
    }
    catch {
        Write-InstallerMessage -Level Warning -Message "The previous files were restored, but the old server could not be restarted automatically: $($_.Exception.Message)"
    }
}


if ([string]::IsNullOrWhiteSpace($InstallPath)) {
    $InstallPath = Get-DefaultInstallPath
}

$InstallPath = [IO.Path]::GetFullPath($InstallPath)
$Homepage = "http://127.0.0.1:$Port/"
$ArchiveUrl = "https://github.com/$RepositoryOwner/$RepositoryName/archive/refs/heads/$RepositoryBranch.zip"
$RunScript = Join-Path $InstallPath 'run.ps1'
$pwshPath = (Get-Process -Id $PID -ErrorAction Stop).Path
$tempRoot = $null
$backupPath = $null
$installLock = $null
$deploymentStarted = $false
$deploymentValidated = $false
$serverWasRunning = $false
$localStateBackupPath = $null
$localStateStaged = $false
$installExistedBefore = Test-Path -LiteralPath $InstallPath
$shouldStageLocalState = $Reinstall.IsPresent
$hadExistingRunScript = Test-Path -LiteralPath $RunScript -PathType Leaf

try {
    Write-Host ''
    Write-Host 'Root Cause Handbook Setup' -ForegroundColor Cyan
    Write-Host ''

    $installParent = Split-Path -Parent $InstallPath

    if ([string]::IsNullOrWhiteSpace($installParent)) {
        throw 'The installation path must include a parent directory.'
    }

    New-Item -ItemType Directory -Path $installParent -Force | Out-Null
    $lockName = '.' + (Split-Path -Leaf $InstallPath) + '.install.lock'
    $lockFile = Join-Path $installParent $lockName
    $installLock = Enter-InstallLock -LockFile $lockFile

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("RootCauseHandbook-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    if (-not [string]::IsNullOrWhiteSpace($SourcePath)) {
        $sourceRoot = Get-Item -LiteralPath ([IO.Path]::GetFullPath($SourcePath)) -ErrorAction Stop

        if (-not $sourceRoot.PSIsContainer) {
            throw 'SourcePath must point to a repository folder.'
        }

        if ($sourceRoot.FullName -eq $InstallPath) {
            throw 'SourcePath and InstallPath cannot be the same folder.'
        }

        Write-InstallerMessage -Level Skip -Message "Using the local repository source at $($sourceRoot.FullName)."
    }
    else {
        $archivePath = Join-Path $tempRoot 'repository.zip'
        $extractPath = Join-Path $tempRoot 'repository'
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

        Write-InstallerMessage -Level Step -Message 'Downloading the latest handbook from GitHub.'
        Invoke-DownloadFile -Uri $ArchiveUrl -OutFile $archivePath

        Write-InstallerMessage -Level Step -Message 'Extracting the repository.'
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force

        $sourceRoot = Get-ChildItem -LiteralPath $extractPath -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'mkdocs.yml') -PathType Leaf } |
            Select-Object -First 1

        if (-not $sourceRoot) {
            throw 'The downloaded archive did not contain a valid repository folder.'
        }
    }

    Test-RepositorySource -Path $sourceRoot.FullName

    if ($installExistedBefore -and -not $shouldStageLocalState) {
        foreach ($environmentFile in @('requirements.lock.txt', 'run.ps1')) {
            $sourceEnvironmentFile = Join-Path $sourceRoot.FullName $environmentFile
            $installedEnvironmentFile = Join-Path $InstallPath $environmentFile

            if (-not (Test-TextFilesEqual -FirstPath $sourceEnvironmentFile -SecondPath $installedEnvironmentFile)) {
                $shouldStageLocalState = $true
                break
            }
        }
    }

    if (Test-Path -LiteralPath $InstallPath) {
        $serverWasRunning = Stop-InstalledServer -TargetPath $InstallPath -PowerShellPath $pwshPath -Homepage $Homepage
    }
    elseif ((Get-HandbookStatus -Homepage $Homepage) -eq 'DifferentSite') {
        throw "Port $Port is already being used by another website. Use a different port."
    }

    $backupPath = Join-Path $tempRoot 'managed-backup'
    Backup-ManagedContent -Source $InstallPath -Backup $backupPath

    if ($shouldStageLocalState) {
        $localStateBackupPath = Join-Path $tempRoot 'local-state-backup'
        $localStateStaged = $true
        Move-LocalStateToBackup -Source $InstallPath -Backup $localStateBackupPath
    }

    Write-InstallerMessage -Level Step -Message "Installing the handbook at $InstallPath."
    $deploymentStarted = $true
    Copy-ManagedContent -Source $sourceRoot.FullName -Destination $InstallPath

    if ($IsMacOS) {
        foreach ($macLauncherName in @('docs.command', 'bootstrap-macos.sh')) {
            $macLauncher = Join-Path $InstallPath $macLauncherName

            if (Test-Path -LiteralPath $macLauncher -PathType Leaf) {
                & /bin/chmod +x $macLauncher
            }
        }
    }

    if (-not (Test-Path -LiteralPath $RunScript -PathType Leaf)) {
        throw 'The repository was copied, but run.ps1 was not found.'
    }

    Write-InstallerMessage -Level Step -Message 'Validating the updated handbook before it is opened.'
    $validationArguments = @('-NoLogo', '-NoProfile')

    if ($IsWindows) {
        $validationArguments += @('-ExecutionPolicy', 'Bypass')
    }

    $validationArguments += @(
        '-File', $RunScript,
        '-Port', "$Port",
        '-NoBrowser',
        '-ValidateOnly'
    )

    & $pwshPath @validationArguments

    if ($LASTEXITCODE -ne 0) {
        throw 'The updated handbook did not pass validation.'
    }

    $deploymentValidated = $true
    Write-InstallerMessage -Level Success -Message 'The repository is up to date and passed validation.'

    $installLock.Dispose()
    $installLock = $null

    if ($ValidateOnly) {
        Write-InstallerMessage -Level Success -Message 'Validation completed successfully.'
        exit 0
    }

    $launcherArguments = @('-NoLogo', '-NoProfile')

    if ($IsWindows) {
        $launcherArguments += @('-ExecutionPolicy', 'Bypass')
    }

    $launcherArguments += @('-File', $RunScript, '-Port', "$Port")

    if ($NoBrowser) {
        $launcherArguments += '-NoBrowser'
    }

    Write-InstallerMessage -Level Step -Message 'Starting the handbook.'
    & $pwshPath @launcherArguments
    exit $LASTEXITCODE
}
catch {
    $originalError = $_

    if ($deploymentStarted -and -not $deploymentValidated -and $backupPath) {
        try {
            Restore-ManagedContent -Destination $InstallPath -Backup $backupPath
        }
        catch {
            Write-InstallerMessage -Level Warning -Message "Rollback could not be completed: $($_.Exception.Message)"
        }
    }

    if ($localStateStaged -and -not $deploymentValidated -and $localStateBackupPath) {
        try {
            Restore-LocalState -Destination $InstallPath -Backup $localStateBackupPath
        }
        catch {
            Write-InstallerMessage -Level Warning -Message "The previous local environment could not be restored: $($_.Exception.Message)"
        }
    }

    if (-not $installExistedBefore -and $deploymentStarted -and (Test-Path -LiteralPath $InstallPath)) {
        Remove-Item -LiteralPath $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($serverWasRunning -and $hadExistingRunScript) {
        Start-RolledBackServer -PowerShellPath $pwshPath -TargetPath $InstallPath
    }

    Write-Host ''
    Write-Host '[!] Root Cause Handbook setup failed.' -ForegroundColor Red
    Write-Host $originalError.Exception.Message -ForegroundColor Red
    Write-Host ''
    exit 1
}
finally {
    if ($installLock) {
        $installLock.Dispose()
    }

    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
