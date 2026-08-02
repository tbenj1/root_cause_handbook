# PowerShell Cheat Sheet

Use this page when you need a quick command, need to collect better evidence, or want to turn a repeatable check into a script. The examples use full cmdlet names so the command is clear when it is copied into a ticket, script, or knowledge-base article. Most examples run in PowerShell 7 on Windows and macOS. Windows-only commands are clearly labeled.

!!! important "Start with the safest command that answers the question"

    Start with read-only commands. Before changing or deleting anything, make sure the target is correct, know what the command will do, and use `-WhatIf` or `-Confirm` when the command supports it.

## Command Structure

PowerShell commands use a **Verb-Noun** naming pattern:

```powershell
Get-Service
Get-Process
Set-Location
Remove-Item
```

A command can include named parameters and parameter values:

```powershell
Do-Something -Parameter1 Value1 -Parameter2
```

In this example, `-Parameter1` needs a value. `-Parameter2` is a switch and does not need one.

## Finding Commands and Help

| Command | What it does |
| --- | --- |
| `Get-Command` | List available PowerShell commands. |
| `Get-Command *-Service` | List commands whose noun ends in `Service`. |
| `Get-Help Get-Command` | Show help for `Get-Command`. Replace `Get-Command` with another command name as needed. |
| `Get-Help Get-Command -Examples` | Show examples for a command. |
| `Get-Help * -Parameter ComputerName` | Search help for commands that document a `ComputerName` parameter. |

```powershell
Get-Help Get-Service -Examples
```

!!! tip "Find the command before running it"

    If you are not sure which command to use, search with `Get-Command` and read the help before running it on a production system.

## Files and Folders

### Navigation and Inspection

| Full command | Common aliases | What it does |
| --- | --- | --- |
| `Get-ChildItem` | `dir`, `ls`, `gci` | List files and folders in the current or specified location. |
| `Get-Location` | `pwd`, `gl` | Display the current working location. |
| `Set-Location` | `cd`, `chdir`, `sl` | Change the current working location. |
| `Get-Content` | `cat`, `gc`, `type` | Read the content of a file or other supported item. |
| `Clear-Host` | `cls`, `clear` | Clear the console display. |

```powershell
Get-Location
Get-ChildItem
Set-Location C:\Temp
Get-Content .\example.txt
```

### Creating and Managing Items

| Full command | Common aliases | What it does |
| --- | --- | --- |
| `New-Item` | `ni` | Create a file, folder, registry item, or another provider-supported item. |
| `Copy-Item` | `copy`, `cp`, `cpi` | Copy an item to another location. |
| `Move-Item` | `move`, `mv`, `mi` | Move an item to another location. |
| `Rename-Item` | `ren`, `rni` | Rename an item. |
| `Remove-Item` | `del`, `erase`, `rd`, `ri`, `rm`, `rmdir` | Delete an item. |
| `Out-File` | `>`, `>>` | Write pipeline output to a file. |

```powershell
New-Item -Path .\test.txt -ItemType File
Copy-Item -Path .\test.txt -Destination .\test-copy.txt
Move-Item -Path .\test-copy.txt -Destination C:\Temp\test-copy.txt
Rename-Item -Path .\test.txt -NewName test-renamed.txt
```

!!! warning "Aliases are convenient, but full names are clearer"

    Aliases such as `rm`, `del`, or `cat` are useful at the console. In scripts and documentation, use the full cmdlet name so it is clear what the command does.

### Writing Output to Files

Overwrite a file:

```powershell
Get-Service | Out-File -FilePath .\services.txt
```

Append to an existing file:

```powershell
Get-Service | Out-File -FilePath .\services.txt -Append
```

You can also use redirection:

```powershell
Get-Service > .\services.txt
Get-Process >> .\services.txt
```

Use `Out-File` when you need options such as `-FilePath`, `-Append`, or a specific encoding.

## Risk-Reduction Parameters

PowerShell includes common parameters that can help prevent accidental changes.

| Parameter | Purpose | Example |
| --- | --- | --- |
| `-WhatIf` | Show what the command would attempt without performing the change. | `Remove-Item .\test.txt -WhatIf` |
| `-Confirm` | Ask for confirmation before the command performs the action. | `New-Item .\test.txt -Confirm` |

```powershell
Remove-Item -Path .\old-log.txt -WhatIf
```

```powershell
Remove-Item -Path .\old-log.txt -Confirm
```

!!! important "Preview destructive operations"

    Use `-WhatIf` before a large removal, copy, move, service, firewall, or configuration change when it is supported. Check the final path and the number of objects before deleting anything recursively.

## Pipelines

The pipe character `|` sends the objects produced by one command to the next command.

```powershell
Command1 | Command2 | Command3
```

A practical service pipeline:

```powershell
Get-Service |
    Where-Object -Property Status -EQ Running |
    Select-Object Name, DisplayName, StartType |
    Sort-Object -Property StartType, Name
```

This command:

1. Gets services.
2. Keeps only running services.
3. Selects useful properties.
4. Sorts the results.

### Additional Pipeline Examples

Rename a file from pipeline input:

```powershell
"plan_A.txt" | Rename-Item -NewName "plan_B.md"
```

List file base names in alphabetical order:

```powershell
Get-ChildItem |
    Select-Object -Property BaseName |
    Sort-Object -Property BaseName
```

List batch files in the current directory:

```powershell
Get-ChildItem | Where-Object Name -Like "*.bat"
```

List everything except batch files:

```powershell
Get-ChildItem | Where-Object Name -NotLike "*.bat"
```

## PowerShell Objects

PowerShell sends **objects**, not just text, through the pipeline. You can read an object property or use one of its methods with a period.

Read a property:

```powershell
(Get-Service -Name Fax).Status
```

Inspect the object type:

```powershell
(Get-Service -Name Fax).GetType()
```

Explore available properties and methods:

```powershell
Get-Service -Name Fax | Get-Member
```

!!! note "Properties versus methods"

    A **property** describes the object, such as `Status` or `Name`. A **method** does something with the object or returns more information and usually ends with parentheses, such as `GetType()`.

## Variables

Variables begin with `$`.

```powershell
$var = "string"
```

### Common Variable Operations

| Command or syntax | Purpose |
| --- | --- |
| `New-Variable -Name var1` | Create a variable without assigning a value. |
| `Get-Variable my*` | List variables whose names begin with `my`. |
| `Remove-Variable -Name bad_variable` | Remove a variable. |
| `$a, $b = 0` | Assign `0` to both variables. |
| `$a, $b, $c = 'a', 'b', 'c'` | Assign multiple values by position. |
| `$a, $b = $b, $a` | Swap two variable values. |
| `[int]$var = 5` | Declare an integer variable. |

### Common Automatic Variables

| Variable | Meaning |
| --- | --- |
| `$HOME` | The current user’s home directory. |
| `$null` | An empty or null value. |
| `$true` | Boolean true. |
| `$false` | Boolean false. |
| `$PID` | Process ID of the current PowerShell session. |
| `$_` | The current pipeline object inside commands such as `Where-Object` and `ForEach-Object`. |

```powershell
Get-ChildItem | ForEach-Object {
    Write-Output $_.Name
}
```

## Output Commands

| Command | What it does |
| --- | --- |
| `Write-Output` | Send an object to the success output stream and the next pipeline command. |
| `Out-File` | Write formatted output to a file. |
| `Format-Table` | Format objects as a table for display. |
| `ConvertTo-Html` | Convert .NET objects into HTML markup. |

```powershell
Write-Output "Testing complete"
```

When `Write-Output` is the last command in the pipeline, the result appears in the console.

## Operators

### Arithmetic Operators

Assume `$a = 10` and `$b = 20`.

| Operator | Meaning | Example | Result |
| --- | --- | --- | --- |
| `+` | Addition | `$a + $b` | `30` |
| `-` | Subtraction | `$a - $b` | `-10` |
| `*` | Multiplication | `$a * $b` | `200` |
| `/` | Division | `$b / $a` | `2` |
| `%` | Remainder | `$b % $a` | `0` |

### Comparison Operators

| Operator | Meaning | Example |
| --- | --- | --- |
| `-eq` | Equal | `$a -eq $b` |
| `-ne` | Not equal | `$a -ne $b` |
| `-gt` | Greater than | `$b -gt $a` |
| `-ge` | Greater than or equal to | `$b -ge $a` |
| `-lt` | Less than | `$b -lt $a` |
| `-le` | Less than or equal to | `$b -le $a` |

```powershell
if ($service.Status -ne 'Running') {
    Write-Output "The service is not running."
}
```

### Assignment Operators

| Operator | Meaning | Equivalent expression |
| --- | --- | --- |
| `=` | Assign a value. | `$c = $a + $b` |
| `+=` | Add and assign. | `$c += $a` is `$c = $c + $a` |
| `-=` | Subtract and assign. | `$c -= $a` is `$c = $c - $a` |

### Logical Operators

| Operator | Meaning | Example |
| --- | --- | --- |
| `-and` | True when both expressions are true. | `($a -gt 0) -and ($b -gt 0)` |
| `-or` | True when either expression is true. | `($a -gt 0) -or ($b -gt 0)` |
| `-not` or `!` | Negate a Boolean expression. | `-not ($b -eq 20)` |
| `-xor` | True when only one expression is true. | `($a -gt 0) -xor ($b -gt 0)` |

### Matching and Collection Operators

| Operator | Purpose | Example |
| --- | --- | --- |
| `-Like` / `-NotLike` | Match or reject a wildcard pattern. | `$name -Like "*.log"` |
| `-Match` / `-NotMatch` | Match or reject a regular expression. | `$text -Match '^Windows$'` |
| `-CMatch` / `-CNotMatch` | Case-sensitive regular-expression matching. | `$text -CMatch '^Windows$'` |
| `-Contains` / `-NotContains` | Test whether a collection contains a value. | `@('A','B') -Contains 'B'` |
| `-In` / `-NotIn` | Test whether a value exists in a collection. | `'blue' -In @('red','blue')` |
| `-Replace` | Replace text that matches a regular expression. | `$text -Replace 'old','new'` |

```powershell
@("Apple", "Banana", "Orange") -Contains "Banana"
```

```powershell
"blue" -In @("red", "green", "blue")
```

```powershell
$toy = "I like this toy"
$toy -Replace "toy|this", "item"
```

## Regular Expressions

A regular expression is a pattern used to match text. PowerShell uses regex with operators such as `-Match`, `-NotMatch`, and `-Replace`.

### Common Regex Tokens

| Token | Meaning |
| --- | --- |
| `[abc]` | One character from the listed set. |
| `[^abc]` | One character not in the listed set. |
| `[A-Z]` | One uppercase letter. |
| `[a-z]` | One lowercase letter. |
| `[0-9]` or `\d` | One decimal digit. |
| `\D` | One non-digit character. |
| `\w` | A word character: letter, number, or underscore. |
| `\W` | A non-word character. |
| `\s` | A whitespace character. |
| `\S` | A non-whitespace character. |
| `^` | Beginning of a string. |
| `$` | End of a string. |
| `.` | Any character except a newline. |
| `*` | Zero or more repetitions. |
| `+` | One or more repetitions. |
| `?` | Zero or one repetition. |
| `{n}` | Exactly `n` repetitions. |
| `{n,}` | At least `n` repetitions. |
| `{n,m}` | Between `n` and `m` repetitions. |
| `\` | Escape a regex-reserved character. |
| `\t` | Tab. |
| `\n` | Newline. |
| `\r` | Carriage return. |

### Regex Examples

```powershell
'ah' -Match '[aeiou][^aeiou]'
```

```powershell
'server0F' -Match '[a-z]+-?\d\D'
```

```powershell
'1.618' -Match '\d\.\d{3}'
```

Case-insensitive matching is the default:

```powershell
'windows' -Match '^Windows$'
```

Use `-CMatch` for case-sensitive matching:

```powershell
'Windows' -CMatch '^Windows$'
```

!!! tip "Escape literal punctuation"

    Regex characters such as `.`, `[`, `]`, `(`, `)`, `?`, `*`, `+`, `^`, and `$` have special meanings. Add `\` before the character when you need to match the character itself.

## Grouping, Arrays, and Type Conversion

| Syntax | Purpose | Example |
| --- | --- | --- |
| `()` | Group expressions and control evaluation order. | `(1 + 1) * 2` |
| `$()` | Insert the result of a statement into a string or expression. | `"Today is $(Get-Date)"` |
| `@()` | Force results into an array. | `@(Get-ChildItem)` |
| `[]` | Convert or declare a value as a specific type. | `[DateTime]'2/20/1988'` |

```powershell
$files = @(Get-ChildItem | Select-Object -ExpandProperty Name)
```

## Hash Tables

A hash table stores key-value pairs.

Create an ordinary hash table:

```powershell
$asset = @{
    Number = 1
    Shape  = "Square"
    Color  = "Blue"
}
```

Create an ordered hash table:

```powershell
$asset = [ordered]@{
    Number = 1
    Shape  = "Square"
    Color  = "Blue"
}
```

Read and update values:

```powershell
$asset.Color
$asset["Shape"]
$asset.Number = 100
```

Add and remove entries:

```powershell
$asset["Name"] = "Alice"
$asset.Add("Time", "Now")
$asset.Remove("Time")
```

## Comments, Escaping, and Line Continuation

| Syntax | Purpose |
| --- | --- |
| `# comment` | Single-line comment. |
| `<# comment #>` | Multiline comment. |
| `` `" `` | Escape a quotation mark in a double-quoted string. |
| `` `t `` | Tab character. |
| `` `n `` | Newline character. |
| Backtick at end of line | Continue a command on the next line. |

```powershell
# Review the file before removal.
Remove-Item -Path .\test.txt -WhatIf
```

```powershell
<#
This block explains a longer section of the script.
It can span multiple lines.
#>
```

PowerShell normally allows a line break after a pipe, comma, opening brace, or opening parenthesis. Use those breaks instead of a backtick when possible because trailing spaces can break backtick continuation.

## Flow Control

### `if`, `elseif`, and `else`

```powershell
if ($a -gt 2) {
    Write-Output "The value is greater than 2."
}
elseif ($a -eq 2) {
    Write-Output "The value is equal to 2."
}
else {
    Write-Output "The value is less than 2 or was not initialized."
}
```

### `for`

```powershell
for ($i = 1; $i -le 10; $i++) {
    Write-Output $i
}
```

### `foreach`

```powershell
foreach ($item in $collection) {
    Write-Output $item
}
```

### `ForEach-Object`

`ForEach-Object` runs against each object that comes through the pipeline. Its common alias is `%`, but the full name is easier to understand in scripts and notes.

```powershell
Get-ChildItem | ForEach-Object {
    Write-Output ("{0}`t{1}" -f $_.Length, $_.Name)
}
```

### `while`

```powershell
while ($a -ne 3) {
    $a++
    Write-Output $a
}
```

## Redirection and Output Streams

PowerShell can redirect specific output streams.

| Prefix | Stream | Example |
| --- | --- | --- |
| `*` | All streams | `Do-Something *> .\all-output.txt` |
| `1` | Success output | `Do-Something 1>> .\success.txt` |
| `2` | Error output | `Do-Something 2> .\errors.txt` |
| `3` | Warning output | `Do-Something 3> .\warnings.txt` |
| `4` | Verbose output | `Do-Something 4>> .\verbose.txt` |
| `5` | Debug output | `Do-Something 5> .\debug.txt` |
| `6` | Information output | `Do-Something 6> $null` |

Send errors to the success stream and then write the combined output to a file:

```powershell
dir 'C:\', 'C:\PathThatDoesNotExist' 2>&1 > .\dir.log
```

## System and Network Information

Use these commands to collect system and network information. Some are Windows commands or require Windows modules.

| Command | What it does |
| --- | --- |
| `whoami /priv` | Display privileges for the current Windows user. |
| `net accounts` | Display local password and account policy information. |
| `ipconfig /all` | Display Windows network adapter, IP, gateway, DHCP, and DNS information. |
| `Get-LocalUser | Select-Object *` | Display local users and their properties. |
| `Get-NetRoute` | Display entries from the Windows IP routing table. |
| `Get-HotFix` | Display installed Windows hotfix information. |
| `Get-Command` | Display commands available in the current PowerShell session. |

```powershell
ipconfig /all
```

```powershell
Get-NetRoute
```

```powershell
Get-HotFix
```

!!! note "Windows-only commands"

    `Get-LocalUser`, `Get-NetRoute`, `Get-HotFix`, `Enable-NetFirewallRule`, `net accounts`, `whoami /priv`, and `ipconfig /all` require Windows or Windows modules. They are not available in the same form on macOS.

## Processes and Services

### Services

```powershell
Get-Service
```

List service-related commands:

```powershell
Get-Command *-Service
```

Filter running services:

```powershell
Get-Service | Where-Object Status -EQ Running
```

### Processes

```powershell
Get-Process
```

Display the top processes by current CPU sample:

```powershell
Get-Counter '\Process(*)\% Processor Time' |
    Select-Object -ExpandProperty CounterSamples |
    Sort-Object -Property CookedValue -Descending |
    Select-Object -First 15 InstanceName, CookedValue
```

Repeat a process check every ten seconds:

```powershell
while ($true) {
    Clear-Host
    Get-Process |
        Sort-Object -Property CPU -Descending |
        Select-Object -First 15 Name, Id, CPU
    Start-Sleep -Seconds 10
}
```

!!! warning "A process snapshot needs context"

    One high value does not automatically show the cause. Compare several samples with the time of the issue and what the application was expected to be doing.

## Jobs and Sessions

| Command | What it does |
| --- | --- |
| `Start-Job` | Start a local background job. |
| `Receive-Job` | Retrieve output from a job. |
| `New-PSSession` | Create a persistent local or remote PowerShell session. |
| `Get-PSSession` | List PowerShell sessions. |
| `Start-Sleep -Seconds 10` | Pause the current script for ten seconds. |

```powershell
$job = Start-Job -ScriptBlock {
    Get-Service
}

Receive-Job -Job $job -Wait
```

PowerShell 6 and later can also use a trailing background operator:

```powershell
Get-Process -Name pwsh &
```

The call operator `&` has a separate use: it runs a command stored in a string, variable, or script block.

```powershell
$command = 'Get-Service'
& $command
```

## Network Drives and Remoting

### Create a Persistent Network Drive

```powershell
$driveParameters = @{
    Name       = 'L'
    PSProvider = 'FileSystem'
    Root       = '\\server\share'
    Persist    = $true
}

New-PSDrive @driveParameters
```

Make sure the drive letter is available and the UNC path is correct.

### Enable PowerShell Remoting

```powershell
Enable-PSRemoting
```

!!! warning "Remoting changes the endpoint configuration"

    Enable remoting only when it is approved for the environment. Check the firewall, authentication, access-control, and endpoint-management requirements before enabling it broadly.

### Run a Command on Remote Computers

```powershell
Invoke-Command -ComputerName pc01, pc02, pc03 -ScriptBlock {
    cmd.exe /c 'C:\Path\To\Setup.exe /config C:\Path\To\config.xml'
}
```

Use remote execution only with an approved installer, confirmed arguments, the correct credentials, and a tested rollback or recovery plan.

## Web Requests and REST APIs

| Command | What it does |
| --- | --- |
| `Invoke-WebRequest` | Retrieve web content or download a file. Common alias: `iwr`. |
| `Invoke-RestMethod` | Send an HTTP or HTTPS request to a RESTful web service and process structured responses. |

Download a file to disk:

```powershell
Invoke-WebRequest `
    -Uri 'https://example.invalid/package.zip' `
    -OutFile 'C:\Temp\package.zip'
```

!!! danger "Do not download and immediately execute unverified code"

    Do not disable Microsoft Defender or AMSI, hide a security bypass, or download a script directly into memory and run it. Download approved files to disk, review them, confirm the source, and run them only after the change is authorized.

## Execution Policy

Review the current policy by scope before changing it:

```powershell
Get-ExecutionPolicy -List
```

When an approved process requires a temporary change for the current PowerShell session only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

`Bypass` removes execution-policy prompts and blocking behavior for the selected scope. The `Process` scope ends when that PowerShell session closes. Execution policy is not a normal troubleshooting fix and should not be treated as a security control.

!!! important "Do not use Bypass as a default"

    Use the approved execution-policy scope and signing process. If a temporary change is required, document why it was needed, where it applied, who approved it, and how the original setting will be restored.

## Local User Creation

Prompt for a secure password and create a local user:

```powershell
$Password = Read-Host -AsSecureString

$userParameters = @{
    Name        = 'User03'
    Password    = $Password
    FullName    = 'Third User'
    Description = 'Description of this account.'
}

New-LocalUser @userParameters
```

!!! warning "Account creation requires authorization"

    Before creating a local account, check the naming standard, access level, password requirements, owner, expiration requirements, and where the account must be documented.

## Firewall Rules

Enable an existing Windows firewall rule:

```powershell
Enable-NetFirewallRule -DisplayName 'Approved Rule Name'
```

Use `Get-NetFirewallRule` to find the exact rule before enabling it. Do not open broad firewall access without checking the source, destination, profile, protocol, port, and business reason.

## File Copy Example

Copy a folder while keeping its original folder structure:

```powershell
$source = 'C:\Data'
$destination = '\\server\backup'

Get-ChildItem -LiteralPath $source -Recurse -File |
    ForEach-Object {
        $relativePath = [IO.Path]::GetRelativePath($source, $_.FullName)
        $targetPath = Join-Path $destination $relativePath
        $targetFolder = Split-Path -Parent $targetPath

        New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $targetPath -Force
    }
```

Add a date filter when only files modified today should be copied:

```powershell
Get-ChildItem -LiteralPath $source -Recurse -File |
    Where-Object LastWriteTime -GT (Get-Date).Date |
    ForEach-Object {
        $relativePath = [IO.Path]::GetRelativePath($source, $_.FullName)
        $targetPath = Join-Path $destination $relativePath
        $targetFolder = Split-Path -Parent $targetPath

        New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $targetPath -Force
    }
```

!!! warning "A file copy is not a complete backup plan"

    Test the source and destination with a small folder first. Confirm how duplicate names, permissions, locked files, deleted source files, retention, and restore testing should be handled. Use the organization’s approved backup platform when the data needs a managed backup.

## Troubleshooting Recipes

### Confirm a Service State

```powershell
Get-Service -Name 'Spooler' |
    Select-Object Name, Status, StartType
```

### Find a Process

```powershell
Get-Process -Name 'pwsh' -ErrorAction SilentlyContinue
```

### Check Installed Windows Hotfixes

```powershell
Get-HotFix | Sort-Object -Property InstalledOn -Descending
```

### Save Command Output for a Ticket

```powershell
Get-Service |
    Sort-Object -Property Status, Name |
    Out-File -FilePath 'C:\Temp\service-state.txt'
```

### Create an HTML Report

```powershell
Get-Service |
    Select-Object Name, DisplayName, Status, StartType |
    ConvertTo-Html -Title 'Service Report' |
    Out-File -FilePath 'C:\Temp\service-report.html'
```

### Confirm a Command Exists

```powershell
Get-Command -Name 'Get-NetRoute' -ErrorAction SilentlyContinue
```

### Pause Between Checks

```powershell
Start-Sleep -Seconds 10
```

## Safe-Use Checklist

Before running a command that changes a system, check the following:

- [ ] Confirm the correct environment, user, and device.
- [ ] Confirm the exact path, object, service, process, account, or rule.
- [ ] Review the command help and parameter behavior.
- [ ] Prefer the full cmdlet name over an alias.
- [ ] Use `-WhatIf` or `-Confirm` when available.
- [ ] Test the command on one controlled target first.
- [ ] Record the original state.
- [ ] Make one meaningful change at a time.
- [ ] Capture the command output and exit result.
- [ ] Repeat the original user test.
- [ ] Document the result and how to roll it back when needed.
