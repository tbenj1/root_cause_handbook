[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 8000,

    [switch]$NoBrowser,

    [switch]$ForceRepair,

    [switch]$ValidateOnly,

    [switch]$StopServer,

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
Root Cause Handbook local launcher

Usage:
  pwsh -NoProfile -File ./run.ps1 [options]

Options:
  -Port PORT                 Use a different local website port. Default: 8000.
  -NoBrowser                 Do not open the browser automatically.
  -ForceRepair               Rebuild the local Python environment.
  -ValidateOnly              Validate the website without starting it.
  -StopServer                Stop the managed server on the selected port.
  -Help                      Show this help.

Examples:
  pwsh -NoProfile -File ./run.ps1
  pwsh -NoProfile -File ./run.ps1 -ValidateOnly -NoBrowser
  pwsh -NoProfile -File ./run.ps1 -ForceRepair
  pwsh -NoProfile -File ./run.ps1 -Port 8080 -StopServer -NoBrowser
'@ | Write-Host
    exit 0
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$SiteName = 'The Root Cause Handbook'
$SiteSubtitle = 'A Practical Troubleshooting Guide for IT Professionals'
$HealthMarker = 'root-cause-handbook-health-v1'
$RequiredPython = '3.14'
$UvVersion = '0.12.1'
$RepoRoot = [IO.Path]::GetFullPath($PSScriptRoot)

function Write-LauncherMessage {
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

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [Parameter(Mandatory)]
        [string]$FailureMessage,

        [switch]$Quiet
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    try {
        $output = & $FilePath @Arguments 2>&1
        $exitCode = $LASTEXITCODE

        if ($null -eq $exitCode) {
            $exitCode = 0
        }
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    $outputLines = @($output | ForEach-Object { "$_" })

    if (-not $Quiet) {
        foreach ($line in $outputLines) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                Write-Host $line
            }
        }
    }

    if ($exitCode -ne 0) {
        $details = ($outputLines | Select-Object -Last 20) -join "`n"
        throw "$FailureMessage Exit code: $exitCode.`n$details"
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $outputLines
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
                Write-LauncherMessage -Level Warning -Message "Download attempt $attempt failed. Retrying. $($_.Exception.Message)"
                Start-Sleep -Seconds ([Math]::Min(8, [Math]::Pow(2, $attempt)))
            }
        }
    }

    throw "The file could not be downloaded after $Attempts attempts. $($lastError.Exception.Message)"
}

function Get-PlatformArchitecture {
    $architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()

    switch ($architecture) {
        'X64'   { return 'x86_64' }
        'Arm64' { return 'aarch64' }
        default { throw "The $architecture processor architecture is not supported." }
    }
}

function Get-UvAssetName {
    $architecture = Get-PlatformArchitecture

    if ($IsWindows) {
        return "uv-$architecture-pc-windows-msvc.zip"
    }

    if ($IsMacOS) {
        return "uv-$architecture-apple-darwin.tar.gz"
    }

    throw 'This launcher currently supports Windows and macOS.'
}

function Test-UvExecutable {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    try {
        $result = Invoke-NativeCommand `
            -FilePath $Path `
            -Arguments @('--version') `
            -FailureMessage 'The local setup tool could not be checked.' `
            -Quiet

        $versionText = ($result.Output -join ' ').Trim()
        return ($versionText -match "^uv\s+$([regex]::Escape($UvVersion))(?:\s|$)")
    }
    catch {
        return $false
    }
}

function Install-Uv {
    param(
        [Parameter(Mandatory)]
        [string]$UvPath,

        [Parameter(Mandatory)]
        [string]$UvDirectory,

        [Parameter(Mandatory)]
        [string]$RuntimePath
    )

    if ((Test-UvExecutable -Path $UvPath) -and -not $ForceRepair) {
        Write-LauncherMessage -Level Skip -Message 'The local setup tool is ready.'
        return
    }

    New-Item -ItemType Directory -Path $UvDirectory -Force | Out-Null

    $assetName = Get-UvAssetName
    $assetUrl = "https://github.com/astral-sh/uv/releases/download/$UvVersion/$assetName"
    $operationId = [Guid]::NewGuid().ToString('N')
    $downloadPath = Join-Path $RuntimePath "uv-$operationId-$assetName"
    $extractPath = Join-Path $RuntimePath "uv-extract-$operationId"
    $stagedName = if ($IsWindows) { 'uv.new.exe' } elseif ($IsMacOS) { 'uv.new' } else { throw 'The operating system is not supported.' }
    $stagedPath = Join-Path $UvDirectory $stagedName
    $backupPath = Join-Path $UvDirectory "$($UvPath | Split-Path -Leaf).backup"

    try {
        Remove-Item -LiteralPath $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

        Write-LauncherMessage -Level Step -Message "Downloading the local setup tool for $([Runtime.InteropServices.RuntimeInformation]::OSDescription)."
        Invoke-DownloadFile -Uri $assetUrl -OutFile $downloadPath

        Write-LauncherMessage -Level Step -Message 'Extracting the setup tool.'

        if ($IsWindows) {
            Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractPath -Force
        }
        elseif ($IsMacOS) {
            Invoke-NativeCommand `
                -FilePath '/usr/bin/tar' `
                -Arguments @('-xzf', $downloadPath, '-C', $extractPath) `
                -FailureMessage 'The setup tool archive could not be extracted.' `
                -Quiet | Out-Null
        }
        else {
            throw 'The operating system is not supported.'
        }

        $binaryName = if ($IsWindows) { 'uv.exe' } elseif ($IsMacOS) { 'uv' } else { throw 'The operating system is not supported.' }
        $sourceBinary = Get-ChildItem -LiteralPath $extractPath -Recurse -File |
            Where-Object { $_.Name -eq $binaryName } |
            Select-Object -First 1

        if (-not $sourceBinary) {
            throw "The $binaryName executable was not found in the downloaded archive."
        }

        Remove-Item -LiteralPath $stagedPath -Force -ErrorAction SilentlyContinue
        Copy-Item -LiteralPath $sourceBinary.FullName -Destination $stagedPath -Force

        if ($IsMacOS) {
            Invoke-NativeCommand `
                -FilePath '/bin/chmod' `
                -Arguments @('+x', $stagedPath) `
                -FailureMessage 'The setup tool could not be marked as executable.' `
                -Quiet | Out-Null
        }

        $versionResult = Invoke-NativeCommand `
            -FilePath $stagedPath `
            -Arguments @('--version') `
            -FailureMessage 'The setup tool was downloaded but could not be started.' `
            -Quiet

        $versionText = $versionResult.Output -join ' '

        if ($versionText -notmatch "^uv\s+$([regex]::Escape($UvVersion))\b") {
            throw "The downloaded setup tool returned an unexpected version: $versionText"
        }

        Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue

        if (Test-Path -LiteralPath $UvPath -PathType Leaf) {
            Move-Item -LiteralPath $UvPath -Destination $backupPath -Force
        }

        try {
            Move-Item -LiteralPath $stagedPath -Destination $UvPath -Force
            Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
        }
        catch {
            if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
                Move-Item -LiteralPath $backupPath -Destination $UvPath -Force
            }

            throw
        }

        Write-LauncherMessage -Level Success -Message "Installed $versionText."
    }
    finally {
        Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stagedPath -Force -ErrorAction SilentlyContinue

        if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
            if (-not (Test-Path -LiteralPath $UvPath -PathType Leaf)) {
                Move-Item -LiteralPath $backupPath -Destination $UvPath -Force -ErrorAction SilentlyContinue
            }

            if (Test-Path -LiteralPath $UvPath -PathType Leaf) {
                Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
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

function Save-ServerState {
    param(
        [Parameter(Mandatory)]
        [System.Diagnostics.Process]$Process,

        [Parameter(Mandatory)]
        [string]$StateFile,

        [Parameter(Mandatory)]
        [string]$PythonPath
    )

    $Process.Refresh()
    $state = [ordered]@{
        SchemaVersion = 1
        Pid = $Process.Id
        StartTimeUtc = $Process.StartTime.ToUniversalTime().ToString('o')
        PythonPath = [IO.Path]::GetFullPath($PythonPath)
        RepoRoot = $RepoRoot
        Port = $Port
    }

    $temporaryState = "$StateFile.$PID.tmp"
    $state | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $temporaryState -Encoding UTF8
    Move-Item -LiteralPath $temporaryState -Destination $StateFile -Force
}

function Get-ServerProcess {
    param(
        [Parameter(Mandatory)]
        [string]$StateFile,

        [Parameter(Mandatory)]
        [string]$ExpectedPythonPath
    )

    if (-not (Test-Path -LiteralPath $StateFile -PathType Leaf)) {
        return $null
    }

    try {
        $state = Get-Content -LiteralPath $StateFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

        foreach ($propertyName in @('Pid', 'StartTimeUtc', 'PythonPath', 'RepoRoot', 'Port')) {
            if ($null -eq $state.$propertyName) {
                throw "The server state is missing $propertyName."
            }
        }

        if ([int]$state.Port -ne $Port) {
            throw 'The server state belongs to a different port.'
        }

        if ([IO.Path]::GetFullPath([string]$state.RepoRoot) -ne $RepoRoot) {
            throw 'The server state belongs to a different project path.'
        }

        if ([IO.Path]::GetFullPath([string]$state.PythonPath) -ne [IO.Path]::GetFullPath($ExpectedPythonPath)) {
            throw 'The server state belongs to a different Python environment.'
        }

        $serverProcess = Get-Process -Id ([int]$state.Pid) -ErrorAction Stop
        $serverProcess.Refresh()

        if ($serverProcess.HasExited -or $serverProcess.ProcessName -notmatch '^python') {
            throw 'The stored server process is no longer running.'
        }

        $storedStart = [DateTimeOffset]::Parse([string]$state.StartTimeUtc).UtcDateTime
        $actualStart = $serverProcess.StartTime.ToUniversalTime()

        if ([Math]::Abs(($actualStart - $storedStart).TotalSeconds) -gt 2) {
            throw 'The stored process ID has been reused by another process.'
        }

        return $serverProcess
    }
    catch {
        Remove-Item -LiteralPath $StateFile -Force -ErrorAction SilentlyContinue
        return $null
    }
}

function Stop-MkDocsServer {
    param(
        [AllowNull()]
        [System.Diagnostics.Process]$Process,

        [Parameter(Mandatory)]
        [string]$StateFile,

        [Parameter(Mandatory)]
        [string]$ExpectedPythonPath,

        [switch]$RequireMatch
    )

    $serverProcess = $Process

    if (-not $serverProcess) {
        $serverProcess = Get-ServerProcess -StateFile $StateFile -ExpectedPythonPath $ExpectedPythonPath
    }

    if ($serverProcess) {
        try {
            $serverProcess.Refresh()

            if (-not $serverProcess.HasExited -and $serverProcess.ProcessName -match '^python') {
                Write-LauncherMessage -Level Step -Message "Stopping the handbook server process $($serverProcess.Id)."
                Stop-Process -Id $serverProcess.Id -Force -ErrorAction Stop
                $serverProcess.WaitForExit(5000) | Out-Null
                Write-LauncherMessage -Level Success -Message 'The handbook server has stopped.'
            }
        }
        catch {
            if ($RequireMatch) {
                throw "The server could not be stopped cleanly. $($_.Exception.Message)"
            }

            Write-LauncherMessage -Level Warning -Message "The server could not be stopped cleanly: $($_.Exception.Message)"
        }
    }
    elseif ($RequireMatch) {
        throw 'The handbook responds on this port, but a matching server process could not be safely confirmed.'
    }

    Remove-Item -LiteralPath $StateFile -Force -ErrorAction SilentlyContinue
}

function Open-HandbookHomepage {
    param(
        [Parameter(Mandatory)]
        [string]$Homepage
    )

    if ($NoBrowser) {
        Write-LauncherMessage -Level Success -Message "The handbook is available at $Homepage"
        return
    }

    if ($IsWindows) {
        Start-Process $Homepage | Out-Null
    }
    elseif ($IsMacOS) {
        Invoke-NativeCommand `
            -FilePath '/usr/bin/open' `
            -Arguments @($Homepage) `
            -FailureMessage 'The browser could not be opened.' `
            -Quiet | Out-Null
    }

    Write-LauncherMessage -Level Success -Message "Opened $Homepage"
}

function Test-VirtualEnvironment {
    param(
        [Parameter(Mandatory)]
        [string]$PythonPath
    )

    if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) {
        return $false
    }

    try {
        $result = Invoke-NativeCommand `
            -FilePath $PythonPath `
            -Arguments @('--version') `
            -FailureMessage 'The existing Python environment could not be checked.' `
            -Quiet

        return (($result.Output -join ' ') -match "Python $([regex]::Escape($RequiredPython))\.")
    }
    catch {
        return $false
    }
}

function Initialize-VirtualEnvironment {
    param(
        [Parameter(Mandatory)]
        [string]$UvPath,

        [Parameter(Mandatory)]
        [string]$VenvPath,

        [Parameter(Mandatory)]
        [string]$VenvPython,

        [Parameter(Mandatory)]
        [string]$RequirementsLock
    )

    $environmentHealthy = Test-VirtualEnvironment -PythonPath $VenvPython

    if ($ForceRepair -or -not $environmentHealthy) {
        Remove-Item -LiteralPath $VenvPath -Recurse -Force -ErrorAction SilentlyContinue

        Write-LauncherMessage -Level Step -Message "Creating a local Python $RequiredPython environment."
        Invoke-NativeCommand `
            -FilePath $UvPath `
            -Arguments @(
                'venv',
                '--python', $RequiredPython,
                $VenvPath
            ) `
            -FailureMessage 'The local Python environment could not be created.' | Out-Null

        if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
            throw "The virtual environment was created, but its Python executable was not found at $VenvPython."
        }

        Write-LauncherMessage -Level Success -Message "Created the local Python $RequiredPython environment."
    }
    else {
        Write-LauncherMessage -Level Skip -Message "The local Python $RequiredPython environment is ready."
    }

    Write-LauncherMessage -Level Step -Message 'Checking the handbook packages.'
    Invoke-NativeCommand `
        -FilePath $UvPath `
        -Arguments @(
            'pip',
            'sync',
            '--python', $VenvPython,
            $RequirementsLock
        ) `
        -FailureMessage 'The handbook packages could not be installed.' | Out-Null

    Invoke-NativeCommand `
        -FilePath $VenvPython `
        -Arguments @('-c', 'import mkdocs, material; print(mkdocs.__version__)') `
        -FailureMessage 'The installed MkDocs runtime could not be verified.' `
        -Quiet | Out-Null

    Write-LauncherMessage -Level Success -Message 'The handbook packages are ready.'
}

function Test-MkDocsProject {
    param(
        [Parameter(Mandatory)]
        [string]$PythonPath,

        [Parameter(Mandatory)]
        [string]$ValidationSite
    )

    Remove-Item -LiteralPath $ValidationSite -Recurse -Force -ErrorAction SilentlyContinue

    try {
        Write-LauncherMessage -Level Step -Message 'Checking the website configuration and documentation.'
        Invoke-NativeCommand `
            -FilePath $PythonPath `
            -Arguments @(
                '-m', 'mkdocs',
                'build',
                '--strict',
                '--clean',
                '--config-file', 'mkdocs.yml',
                '--site-dir', $ValidationSite
            ) `
            -FailureMessage 'The website validation failed.' | Out-Null

        Write-LauncherMessage -Level Success -Message 'The website passed validation.'
    }
    finally {
        Remove-Item -LiteralPath $ValidationSite -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-ServerLogTail {
    param(
        [Parameter(Mandatory)]
        [string]$OutputLog,

        [Parameter(Mandatory)]
        [string]$ErrorLog
    )

    $lines = @()

    if (Test-Path -LiteralPath $ErrorLog) {
        $lines += Get-Content -LiteralPath $ErrorLog -Tail 20
    }

    if (Test-Path -LiteralPath $OutputLog) {
        $lines += Get-Content -LiteralPath $OutputLog -Tail 20
    }

    if ($lines.Count -eq 0) {
        return 'No MkDocs log output was produced.'
    }

    return ($lines -join "`n")
}

function Start-MkDocsServer {
    param(
        [Parameter(Mandatory)]
        [string]$PythonPath,

        [Parameter(Mandatory)]
        [string]$Homepage,

        [Parameter(Mandatory)]
        [string]$OutputLog,

        [Parameter(Mandatory)]
        [string]$ErrorLog,

        [Parameter(Mandatory)]
        [string]$StateFile
    )

    foreach ($path in @($OutputLog, $ErrorLog, $StateFile)) {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    }

    Write-LauncherMessage -Level Step -Message "Starting the handbook at $Homepage"

    $startParameters = @{
        FilePath = $PythonPath
        ArgumentList = @(
            '-m', 'mkdocs',
            'serve',
            '--config-file', 'mkdocs.yml',
            '--dev-addr', "127.0.0.1:$Port"
        )
        WorkingDirectory = $RepoRoot
        RedirectStandardOutput = $OutputLog
        RedirectStandardError = $ErrorLog
        PassThru = $true
    }

    if ($IsWindows) {
        $startParameters.NoNewWindow = $true
    }

    $process = Start-Process @startParameters
    Save-ServerState -Process $process -StateFile $StateFile -PythonPath $PythonPath

    for ($attempt = 1; $attempt -le 120; $attempt++) {
        Start-Sleep -Milliseconds 250
        $process.Refresh()

        if ($process.HasExited) {
            Remove-Item -LiteralPath $StateFile -Force -ErrorAction SilentlyContinue
            throw "MkDocs stopped before the webpage opened.`n$(Get-ServerLogTail -OutputLog $OutputLog -ErrorLog $ErrorLog)"
        }

        $status = Get-HandbookStatus -Homepage $Homepage

        if ($status -in @('Running', 'RunningLegacy')) {
            Write-LauncherMessage -Level Success -Message "The handbook is running at $Homepage"
            return $process
        }

        if ($status -eq 'DifferentSite') {
            Stop-MkDocsServer -Process $process -StateFile $StateFile -ExpectedPythonPath $PythonPath
            throw "Port $Port is being used by another website. Run the command again with a different port."
        }
    }

    Stop-MkDocsServer -Process $process -StateFile $StateFile -ExpectedPythonPath $PythonPath
    throw "The handbook did not become available within 30 seconds.`n$(Get-ServerLogTail -OutputLog $OutputLog -ErrorLog $ErrorLog)"
}

function Enter-SetupLock {
    param(
        [Parameter(Mandatory)]
        [string]$LockFile,

        [ValidateRange(1, 120)]
        [int]$TimeoutSeconds = 30
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)

    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            return [IO.File]::Open(
                $LockFile,
                [IO.FileMode]::OpenOrCreate,
                [IO.FileAccess]::ReadWrite,
                [IO.FileShare]::None
            )
        }
        catch [IO.IOException] {
            Start-Sleep -Milliseconds 250
        }
    }

    throw 'Another handbook setup or validation is already running. Wait for it to finish and try again.'
}


$RuntimePath = Join-Path $RepoRoot '.runtime'
$UvDirectory = Join-Path $RuntimePath 'tools/uv'
$UvBinaryName = if ($IsWindows) { 'uv.exe' } elseif ($IsMacOS) { 'uv' } else { throw 'The operating system is not supported.' }
$UvPath = Join-Path $UvDirectory $UvBinaryName
$VenvPath = Join-Path $RepoRoot '.venv'
$VenvPython = if ($IsWindows) {
    Join-Path $VenvPath 'Scripts/python.exe'
}
elseif ($IsMacOS) {
    Join-Path $VenvPath 'bin/python'
}
else {
    throw 'The operating system is not supported.'
}
$RequirementsLock = Join-Path $RepoRoot 'requirements.lock.txt'
$MkDocsConfig = Join-Path $RepoRoot 'mkdocs.yml'
$DocsPath = Join-Path $RepoRoot 'docs'
$HealthFile = Join-Path $DocsPath 'assets/health.txt'
$ValidationSite = Join-Path $RuntimePath 'validation-site'
$ServerOutputLog = Join-Path $RuntimePath 'mkdocs-output.log'
$ServerErrorLog = Join-Path $RuntimePath 'mkdocs-error.log'
$ServerStateFile = Join-Path $RuntimePath 'mkdocs-server.json'
$SetupLockFile = Join-Path $RuntimePath 'setup.lock'
$Homepage = "http://127.0.0.1:$Port/"
$serverProcess = $null
$setupLock = $null

try {
    Write-Host ''
    Write-Host $SiteName -ForegroundColor Cyan
    Write-Host $SiteSubtitle
    Write-Host ''

    foreach ($requiredPath in @($MkDocsConfig, $DocsPath, $RequirementsLock, $HealthFile)) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "A required project item is missing: $requiredPath"
        }
    }

    if ((Get-Content -LiteralPath $HealthFile -Raw).Trim() -ne $HealthMarker) {
        throw 'The handbook health marker is invalid.'
    }

    New-Item -ItemType Directory -Path $RuntimePath -Force | Out-Null

    if ($StopServer) {
        $status = Get-HandbookStatus -Homepage $Homepage
        $requireMatch = $status -in @('Running', 'RunningLegacy')
        Stop-MkDocsServer `
            -Process $null `
            -StateFile $ServerStateFile `
            -ExpectedPythonPath $VenvPython `
            -RequireMatch:$requireMatch
        exit 0
    }

    $initialStatus = Get-HandbookStatus -Homepage $Homepage

    if ($initialStatus -eq 'DifferentSite') {
        throw "Port $Port is already being used by another website. Use another port, such as -Port 8080."
    }

    if ($initialStatus -in @('Running', 'RunningLegacy') -and -not $ForceRepair) {
        if ($ValidateOnly) {
            Write-LauncherMessage -Level Success -Message 'The running handbook passed its health check.'
            exit 0
        }

        Write-LauncherMessage -Level Skip -Message 'The handbook is already running. No setup work is needed.'
        Open-HandbookHomepage -Homepage $Homepage
        exit 0
    }

    $setupLock = Enter-SetupLock -LockFile $SetupLockFile
    $lockedStatus = Get-HandbookStatus -Homepage $Homepage

    if ($lockedStatus -eq 'DifferentSite') {
        throw "Port $Port started being used by another website while setup was waiting. Use another port."
    }

    if ($lockedStatus -in @('Running', 'RunningLegacy')) {
        if ($ForceRepair) {
            Stop-MkDocsServer `
                -Process $null `
                -StateFile $ServerStateFile `
                -ExpectedPythonPath $VenvPython `
                -RequireMatch
        }
        elseif ($ValidateOnly) {
            Write-LauncherMessage -Level Success -Message 'The running handbook passed its health check.'
            exit 0
        }
        else {
            Write-LauncherMessage -Level Skip -Message 'Another setup finished while this one was waiting. The handbook is already running.'
            Open-HandbookHomepage -Homepage $Homepage
            exit 0
        }
    }

    Install-Uv -UvPath $UvPath -UvDirectory $UvDirectory -RuntimePath $RuntimePath
    Initialize-VirtualEnvironment `
        -UvPath $UvPath `
        -VenvPath $VenvPath `
        -VenvPython $VenvPython `
        -RequirementsLock $RequirementsLock

    Push-Location $RepoRoot

    try {
        Test-MkDocsProject -PythonPath $VenvPython -ValidationSite $ValidationSite
    }
    finally {
        Pop-Location
    }

    if ($ValidateOnly) {
        Write-LauncherMessage -Level Success -Message 'Validation completed successfully.'
        exit 0
    }

    $serverProcess = Start-MkDocsServer `
        -PythonPath $VenvPython `
        -Homepage $Homepage `
        -OutputLog $ServerOutputLog `
        -ErrorLog $ServerErrorLog `
        -StateFile $ServerStateFile

    $setupLock.Dispose()
    $setupLock = $null

    Open-HandbookHomepage -Homepage $Homepage

    Write-Host ''
    Write-Host 'Keep this window open while using the handbook.'
    Write-Host 'Press Ctrl+C or close the window to stop the local website.'
    Write-Host ''

    try {
        while ($true) {
            Start-Sleep -Seconds 1
            $serverProcess.Refresh()

            if ($serverProcess.HasExited) {
                $stopWasRequested = -not (Test-Path -LiteralPath $ServerStateFile -PathType Leaf)

                if (-not $stopWasRequested -and $serverProcess.ExitCode -ne 0) {
                    throw "MkDocs stopped unexpectedly with exit code $($serverProcess.ExitCode).`n$(Get-ServerLogTail -OutputLog $ServerOutputLog -ErrorLog $ServerErrorLog)"
                }

                break
            }
        }
    }
    finally {
        Stop-MkDocsServer `
            -Process $serverProcess `
            -StateFile $ServerStateFile `
            -ExpectedPythonPath $VenvPython
    }

    exit 0
}
catch {
    Write-Host ''
    Write-Host '[!] Root Cause Handbook failed.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''
    Write-Host "Runtime logs are stored in: $RuntimePath"
    exit 1
}
finally {
    if ($setupLock) {
        $setupLock.Dispose()
    }
}
