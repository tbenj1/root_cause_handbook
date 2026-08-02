[CmdletBinding()]
param(
    [string]$InstallPath,

    [ValidateRange(1024, 65535)]
    [int]$Port = 8000,

    [switch]$NoBrowser,

    [switch]$Reinstall,

    [switch]$ValidateOnly,

    [switch]$ForceRepair,

    [switch]$StopServer,

    [switch]$LocalRun,

    [switch]$SkipPowerShellUpdate,

    [switch]$Help
)

if ($env:OS -ne 'Windows_NT') {
    throw 'This bootstrap only runs on Windows.'
}

if ($Help) {
    @'
Root Cause Handbook Windows bootstrap

Usage:
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap-windows.ps1 [options]

Options:
  -InstallPath PATH          Use a custom handbook installation path.
  -Port PORT                 Use a different local website port. Default: 8000.
  -NoBrowser                 Do not open the browser automatically.
  -Reinstall                 Rebuild the managed installation and environment.
  -ValidateOnly              Validate the website without starting it.
  -ForceRepair               Rebuild the local environment with -LocalRun.
  -StopServer                Stop the local server with -LocalRun.
  -LocalRun                  Run the local run.ps1 file beside this script.
  -SkipPowerShellUpdate      Skip the online PowerShell release check.
  -Help                      Show this help.

Examples:
  .\bootstrap-windows.ps1
  .\bootstrap-windows.ps1 -LocalRun -ValidateOnly -NoBrowser
  .\bootstrap-windows.ps1 -LocalRun -ForceRepair
  .\bootstrap-windows.ps1 -LocalRun -StopServer
'@ | Write-Host
    exit 0
}
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepositoryOwner = 'tbenj1'
$RepositoryName = 'root_cause_handbook'
$RepositoryBranch = 'main'
$PowerShellApiUrl = 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest'
$localAppData = [Environment]::GetFolderPath('LocalApplicationData')

if ([string]::IsNullOrWhiteSpace($localAppData)) {
    $localAppData = Join-Path $HOME 'AppData\Local'
}

$PortablePowerShellBase = Join-Path $localAppData 'Programs\PowerShell'

function Write-BootstrapMessage {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Step', 'Success', 'Skip', 'Warning')]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    switch ($Level) {
        'Step'    { Write-Host "[>] $Message" }
        'Success' { Write-Host "[+] $Message" -ForegroundColor Green }
        'Skip'    { Write-Host "[-] $Message" -ForegroundColor DarkGray }
        'Warning' { Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage,

        [switch]$AllowFailure
    )

    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    if ($null -eq $exitCode) {
        $exitCode = 0
    }

    foreach ($line in @($output)) {
        if (-not [string]::IsNullOrWhiteSpace("$line")) {
            Write-Host "$line"
        }
    }

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "$FailureMessage Exit code: $exitCode."
    }

    return $exitCode
}

function Invoke-DownloadFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$OutFile,

        [ValidateRange(1, 10)]
        [int]$Attempts = 3
    )

    $lastError = $null

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -TimeoutSec 300

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
                Write-BootstrapMessage -Level Warning -Message "Download attempt $attempt failed. Retrying. $($_.Exception.Message)"
                Start-Sleep -Seconds ([Math]::Min(8, [Math]::Pow(2, $attempt)))
            }
        }
    }

    throw "The file could not be downloaded after $Attempts attempts. $($lastError.Exception.Message)"
}

function Invoke-GitHubApiRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [ValidateRange(1, 10)]
        [int]$Attempts = 3
    )

    $headers = @{
        Accept = 'application/vnd.github+json'
        'User-Agent' = 'RootCauseHandbookBootstrap'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    $lastError = $null

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            return Invoke-RestMethod -Uri $Uri -Headers $headers -Method Get -TimeoutSec 60
        }
        catch {
            $lastError = $_

            if ($attempt -lt $Attempts) {
                Write-BootstrapMessage -Level Warning -Message "PowerShell release check attempt $attempt failed. Retrying. $($_.Exception.Message)"
                Start-Sleep -Seconds ([Math]::Min(8, [Math]::Pow(2, $attempt)))
            }
        }
    }

    throw "The latest release could not be checked after $Attempts attempts. $($lastError.Exception.Message)"
}

function Get-WindowsArchitecture {
    $architecture = $env:PROCESSOR_ARCHITEW6432

    if ([string]::IsNullOrWhiteSpace($architecture)) {
        $architecture = $env:PROCESSOR_ARCHITECTURE
    }

    if ([string]::IsNullOrWhiteSpace($architecture)) {
        throw 'The Windows processor architecture could not be detected.'
    }

    switch ($architecture.ToUpperInvariant()) {
        'AMD64' { return 'x64' }
        'ARM64' { return 'arm64' }
        default { throw "The $architecture Windows architecture is not supported." }
    }
}

function Get-LatestPowerShellRelease {
    Write-BootstrapMessage -Level Step -Message 'Checking the latest stable PowerShell release.'
    $release = Invoke-GitHubApiRequest -Uri $PowerShellApiUrl

    if (-not $release.tag_name) {
        throw 'GitHub did not return a PowerShell release version.'
    }

    $versionText = "$($release.tag_name)".TrimStart('v')
    $version = [version]$versionText
    $architecture = Get-WindowsArchitecture
    $assetPattern = '^PowerShell-' + [regex]::Escape($versionText) + '-win-' + $architecture + '\.zip$'
    $asset = @($release.assets) |
        Where-Object { $_.name -match $assetPattern } |
        Select-Object -First 1

    if (-not $asset -or -not $asset.browser_download_url) {
        throw "The PowerShell $versionText Windows $architecture ZIP package was not found in the latest release."
    }

    return [pscustomobject]@{
        Version = $version
        VersionText = $versionText
        DownloadUrl = "$($asset.browser_download_url)"
        AssetName = "$($asset.name)"
    }
}

function Get-PowerShellVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PowerShellPath
    )

    try {
        $versionOutput = & $PowerShellPath -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null |
            Select-Object -First 1
        $versionText = "$versionOutput".Trim()

        if ([string]::IsNullOrWhiteSpace($versionText) -or $versionText.Contains('-')) {
            return $null
        }

        return [version]$versionText
    }
    catch {
        return $null
    }
}

function Get-PowerShellPath {
    $candidates = @()

    if (Test-Path -LiteralPath $PortablePowerShellBase -PathType Container) {
        $candidates += Get-ChildItem -LiteralPath $PortablePowerShellBase -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'pwsh.exe' }
    }

    $programFiles = [Environment]::GetFolderPath('ProgramFiles')

    if (-not [string]::IsNullOrWhiteSpace($programFiles)) {
        $candidates += Join-Path $programFiles 'PowerShell\7\pwsh.exe'
    }

    $candidates += Join-Path $localAppData 'Microsoft\WindowsApps\pwsh.exe'
    $command = Get-Command pwsh.exe -ErrorAction SilentlyContinue

    if ($command -and $command.Source) {
        $candidates += $command.Source
    }

    $bestPath = $null
    $bestVersion = $null

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $candidateVersion = Get-PowerShellVersion -PowerShellPath $candidate

            if ($candidateVersion -and ($null -eq $bestVersion -or $candidateVersion -gt $bestVersion)) {
                $bestPath = [IO.Path]::GetFullPath($candidate)
                $bestVersion = $candidateVersion
            }
        }
    }

    return $bestPath
}

function Refresh-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
}

function Set-PortablePowerShellOnUserPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory
    )

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $pathEntries = @()

    if (-not [string]::IsNullOrWhiteSpace($userPath)) {
        $pathEntries = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $portableBaseNormalized = $PortablePowerShellBase.TrimEnd('\') + '\'
    $filteredEntries = @()

    foreach ($entry in $pathEntries) {
        $normalizedEntry = $entry.Trim().TrimEnd('\')

        if (-not ($normalizedEntry + '\').StartsWith($portableBaseNormalized, [StringComparison]::OrdinalIgnoreCase)) {
            $filteredEntries += $entry
        }
    }

    $newUserPath = (($filteredEntries + $Directory) -join ';')
    [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
    Refresh-ProcessPath
}

function Install-PortablePowerShell {
    param(
        [Parameter(Mandatory = $true)]
        $Release
    )

    $targetRoot = Join-Path $PortablePowerShellBase $Release.VersionText
    $existingTarget = Join-Path $targetRoot 'pwsh.exe'

    if (Test-Path -LiteralPath $existingTarget -PathType Leaf) {
        $existingTargetVersion = Get-PowerShellVersion -PowerShellPath $existingTarget

        if ($existingTargetVersion -and $existingTargetVersion -ge $Release.Version) {
            Set-PortablePowerShellOnUserPath -Directory $targetRoot
            return $existingTarget
        }
    }

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('RootCauseHandbook-PowerShell-' + [Guid]::NewGuid().ToString('N'))
    $archivePath = Join-Path $tempRoot $Release.AssetName
    $extractPath = Join-Path $tempRoot 'extracted'
    $stagedTarget = Join-Path $PortablePowerShellBase ('.staging-' + [Guid]::NewGuid().ToString('N'))

    try {
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        New-Item -ItemType Directory -Path $PortablePowerShellBase -Force | Out-Null

        Write-BootstrapMessage -Level Step -Message "Downloading PowerShell $($Release.VersionText) for Windows."
        Invoke-DownloadFile -Uri $Release.DownloadUrl -OutFile $archivePath

        Write-BootstrapMessage -Level Step -Message 'Preparing the current-user PowerShell installation.'
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force

        Get-ChildItem -LiteralPath $extractPath -Recurse -File -ErrorAction SilentlyContinue |
            Unblock-File -ErrorAction SilentlyContinue

        $extractedPowerShell = Join-Path $extractPath 'pwsh.exe'

        if (-not (Test-Path -LiteralPath $extractedPowerShell -PathType Leaf)) {
            throw 'PowerShell was extracted, but pwsh.exe was not found.'
        }

        $extractedVersion = Get-PowerShellVersion -PowerShellPath $extractedPowerShell

        if (-not $extractedVersion -or $extractedVersion -lt $Release.Version) {
            throw 'The extracted PowerShell package could not be verified.'
        }

        Remove-Item -LiteralPath $stagedTarget -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $stagedTarget -Force | Out-Null

        Get-ChildItem -LiteralPath $extractPath -Force |
            Copy-Item -Destination $stagedTarget -Recurse -Force

        Get-ChildItem -LiteralPath $stagedTarget -Recurse -File -ErrorAction SilentlyContinue |
            Unblock-File -ErrorAction SilentlyContinue

        $stagedPowerShell = Join-Path $stagedTarget 'pwsh.exe'
        $stagedVersion = Get-PowerShellVersion -PowerShellPath $stagedPowerShell

        if (-not $stagedVersion -or $stagedVersion -lt $Release.Version) {
            throw 'The staged PowerShell installation could not be started.'
        }

        Remove-Item -LiteralPath $targetRoot -Recurse -Force -ErrorAction SilentlyContinue
        Move-Item -LiteralPath $stagedTarget -Destination $targetRoot -Force
        Set-PortablePowerShellOnUserPath -Directory $targetRoot

        return (Join-Path $targetRoot 'pwsh.exe')
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stagedTarget -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-WinGetPowerShellInstall {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('install', 'upgrade')]
        [string]$Verb
    )

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue

    if (-not $winget) {
        return $false
    }

    $arguments = @(
        $Verb,
        '--id', 'Microsoft.PowerShell',
        '--exact',
        '--source', 'winget',
        '--silent',
        '--accept-source-agreements',
        '--accept-package-agreements',
        '--disable-interactivity'
    )

    Write-BootstrapMessage -Level Step -Message "Using WinGet to $Verb PowerShell."
    $exitCode = Invoke-NativeCommand `
        -FilePath $winget.Source `
        -Arguments $arguments `
        -FailureMessage 'WinGet could not install or update PowerShell.' `
        -AllowFailure

    if ($exitCode -ne 0) {
        return $false
    }

    Start-Sleep -Seconds 2
    Refresh-ProcessPath
    return $true
}

function Install-OrUpdatePowerShell {
    $existingPath = Get-PowerShellPath
    $existingVersion = $null

    if ($existingPath) {
        $existingVersion = Get-PowerShellVersion -PowerShellPath $existingPath
    }

    if ($SkipPowerShellUpdate) {
        if (-not $existingPath -or -not $existingVersion -or $existingVersion.Major -lt 7) {
            throw 'PowerShell 7 was not found and the PowerShell update check was skipped.'
        }

        Write-BootstrapMessage -Level Skip -Message 'The PowerShell update check was skipped.'
        return $existingPath
    }

    try {
        $release = Get-LatestPowerShellRelease
    }
    catch {
        if ($existingVersion -and $existingVersion.Major -ge 7) {
            Write-BootstrapMessage -Level Warning -Message "The latest PowerShell release could not be checked. Continuing with PowerShell $existingVersion. $($_.Exception.Message)"
            return $existingPath
        }

        Write-BootstrapMessage -Level Warning -Message 'The release API could not be reached. Trying WinGet as a fallback.'

        if (Invoke-WinGetPowerShellInstall -Verb install) {
            $wingetPath = Get-PowerShellPath

            if ($wingetPath) {
                $wingetVersion = Get-PowerShellVersion -PowerShellPath $wingetPath

                if ($wingetVersion -and $wingetVersion.Major -ge 7) {
                    Write-BootstrapMessage -Level Success -Message "PowerShell $wingetVersion is ready."
                    return $wingetPath
                }
            }
        }

        throw "PowerShell is not installed and the latest release could not be checked. $($_.Exception.Message)"
    }

    if ($existingVersion -and $existingVersion -ge $release.Version) {
        Write-BootstrapMessage -Level Skip -Message "PowerShell $existingVersion is already current."
        return $existingPath
    }

    if ($existingVersion) {
        Write-BootstrapMessage -Level Step -Message "PowerShell $existingVersion is installed. Updating to $($release.VersionText)."
    }
    else {
        Write-BootstrapMessage -Level Step -Message "PowerShell is not installed. Installing $($release.VersionText)."
    }

    $wingetVerb = 'install'

    if ($existingVersion) {
        $wingetVerb = 'upgrade'
    }

    if (Invoke-WinGetPowerShellInstall -Verb $wingetVerb) {
        $wingetPowerShellPath = Get-PowerShellPath

        if ($wingetPowerShellPath) {
            $wingetVersion = Get-PowerShellVersion -PowerShellPath $wingetPowerShellPath

            if ($wingetVersion -and $wingetVersion -ge $release.Version) {
                Write-BootstrapMessage -Level Success -Message "PowerShell $wingetVersion is ready."
                return $wingetPowerShellPath
            }
        }
    }

    Write-BootstrapMessage -Level Warning -Message 'WinGet did not provide the required PowerShell version. Using a current-user installation instead.'
    $portablePath = Install-PortablePowerShell -Release $release
    $portableVersion = Get-PowerShellVersion -PowerShellPath $portablePath

    if (-not $portableVersion -or $portableVersion -lt $release.Version) {
        throw 'The downloaded PowerShell installation could not be verified.'
    }

    Write-BootstrapMessage -Level Success -Message "PowerShell $portableVersion is ready."
    return $portablePath
}

function Get-NextStepArguments {
    $arguments = @()

    if ($LocalRun) {
        $arguments += '-Port'
        $arguments += "$Port"

        if ($NoBrowser) { $arguments += '-NoBrowser' }
        if ($ForceRepair) { $arguments += '-ForceRepair' }
        if ($ValidateOnly) { $arguments += '-ValidateOnly' }
        if ($StopServer) { $arguments += '-StopServer' }
    }
    else {
        if (-not [string]::IsNullOrWhiteSpace($InstallPath)) {
            $arguments += '-InstallPath'
            $arguments += $InstallPath
        }

        $arguments += '-Port'
        $arguments += "$Port"

        if ($NoBrowser) { $arguments += '-NoBrowser' }
        if ($Reinstall) { $arguments += '-Reinstall' }
        if ($ValidateOnly) { $arguments += '-ValidateOnly' }
    }

    return $arguments
}

$tempInstallScript = $null

try {
    Write-Host ''
    Write-Host 'Root Cause Handbook Bootstrap' -ForegroundColor Cyan
    Write-Host ''

    $powerShellPath = Install-OrUpdatePowerShell

    if ($LocalRun) {
        $nextScript = Join-Path $PSScriptRoot 'run.ps1'

        if (-not (Test-Path -LiteralPath $nextScript -PathType Leaf)) {
            throw "run.ps1 was not found at $nextScript."
        }
    }
    else {
        $tempInstallScript = Join-Path ([IO.Path]::GetTempPath()) ('RootCauseHandbook-install-' + [Guid]::NewGuid().ToString('N') + '.ps1')
        $installScriptUrl = "https://raw.githubusercontent.com/$RepositoryOwner/$RepositoryName/$RepositoryBranch/install.ps1"

        Write-BootstrapMessage -Level Step -Message 'Downloading the Root Cause Handbook installer.'
        Invoke-DownloadFile -Uri $installScriptUrl -OutFile $tempInstallScript

        $installerText = Get-Content -LiteralPath $tempInstallScript -Raw

        if ($installerText -notmatch 'Root Cause Handbook Setup' -or $installerText -notmatch '\[CmdletBinding\(\)\]') {
            throw 'The downloaded installer did not contain the expected Root Cause Handbook script.'
        }

        $nextScript = $tempInstallScript
    }

    $nextArguments = Get-NextStepArguments
    $powerShellArguments = @(
        '-NoLogo',
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $nextScript
    ) + $nextArguments

    Write-BootstrapMessage -Level Step -Message 'Continuing with the Root Cause Handbook setup.'
    & $powerShellPath @powerShellArguments
    exit $LASTEXITCODE
}
catch {
    Write-Host ''
    Write-Host '[!] Root Cause Handbook bootstrap failed.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''
    exit 1
}
finally {
    if ($tempInstallScript) {
        Remove-Item -LiteralPath $tempInstallScript -Force -ErrorAction SilentlyContinue
    }
}
