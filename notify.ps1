# Shows a native Windows toast (WinRT ToastNotificationManager) carrying the Claude logo.
# No installable dependencies: the WinRT Show happens in Windows PowerShell 5.1 (via
# show-toast.ps1) because the WinRT projection is unavailable in pwsh 7, where this runs.
# Clicking the toast brings the hosting terminal window to the foreground via a
# `claude-focus:` URL protocol that this script self-registers (HKCU, no admin needed),
# so the skill is portable: just copy the folder, no separate setup step.
param(
    [Parameter(Mandatory, Position = 0)][string]$Title,
    [Parameter(Mandatory, Position = 1)][string]$Message,
    [Parameter(Position = 2)][AllowEmptyString()][string]$Sound = 'ms-winsoundevent:Notification.Default'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'wt-helpers.ps1')

$appId = 'Claude.Code.Notify'

# Ensure the `claude-focus:` protocol points at this folder's focus-window.ps1.
# Idempotent and cheap: only writes the registry when missing or stale.
function Confirm-FocusProtocol {
    $pwsh = (Get-Process -Id $PID).Path
    if (-not $pwsh) { $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source }
    if (-not $pwsh) { return $false }

    $focusScript = Join-Path $PSScriptRoot 'focus-window.ps1'
    $command = "`"$pwsh`" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$focusScript`" `"%1`""

    $root = 'HKCU:\Software\Classes\claude-focus'
    $cmdKey = Join-Path $root 'shell\open\command'

    $current = (Get-ItemProperty -Path $cmdKey -Name '(Default)' -ErrorAction SilentlyContinue).'(Default)'
    if ($current -ne $command) {
        New-Item -Path $root -Force | Out-Null
        Set-ItemProperty -Path $root -Name '(Default)' -Value 'URL:Claude Focus Protocol'
        Set-ItemProperty -Path $root -Name 'URL Protocol' -Value ''
        New-Item -Path $cmdKey -Force | Out-Null
        Set-ItemProperty -Path $cmdKey -Name '(Default)' -Value $command
    }
    return $true
}

# Register the AppUserModelId that the toast is published under, so it shows as "Claude Code"
# with the Claude logo (instead of a generic PowerShell entry) in the toast header and Action
# Center. Idempotent and HKCU-only (no admin), mirroring Confirm-FocusProtocol.
function Confirm-ToastAppId {
    $root = "HKCU:\Software\Classes\AppUserModelId\$appId"
    $iconUri = Join-Path $PSScriptRoot 'claude-logo.png'

    $currentName = (Get-ItemProperty -Path $root -Name 'DisplayName' -ErrorAction SilentlyContinue).'DisplayName'
    $currentIcon = (Get-ItemProperty -Path $root -Name 'IconUri' -ErrorAction SilentlyContinue).'IconUri'
    if ($currentName -ne 'Claude Code' -or $currentIcon -ne $iconUri) {
        New-Item -Path $root -Force | Out-Null
        Set-ItemProperty -Path $root -Name 'DisplayName' -Value 'Claude Code'
        Set-ItemProperty -Path $root -Name 'IconUri' -Value $iconUri
    }
}

# Title and Windows Terminal window of the tab hosting this session. When fired from a Claude Code
# tool, this script runs in a separate console (`claude → cmd.exe|bash → pwsh`), so read both from
# the `claude` ancestor's console instead (it is the tab's console); see read-session-console.ps1.
# Falls back to our own console title (and no window) when run by hand from a terminal.
function Get-SessionConsole([int]$claudePid) {
    if ($claudePid -gt 0) {
        try {
            $readScript = Join-Path $PSScriptRoot 'read-session-console.ps1'
            $output = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $readScript -TargetPid $claudePid
            $windowPart, $titlePart = ([string]$output).Trim() -split ' ', 2
            if ($titlePart) {
                return [pscustomobject]@{
                    Title  = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($titlePart))
                    Window = [IntPtr][int64]$windowPart
                }
            }
        } catch { }
    }
    return [pscustomobject]@{ Title = [Console]::Title; Window = [IntPtr]::Zero }
}

# Walk up the process tree from this script to the first ancestor that owns a real window (the
# terminal hosting Claude Code); its handle is the fallback focus target. On the way, remember the
# `claude` process: its console is the tab's console.
$hwnd = [IntPtr]::Zero
$claudePid = 0
$proc = Get-Process -Id $PID
while ($proc) {
    if ($proc.ProcessName -eq 'claude') { $claudePid = $proc.Id }
    if ($proc.MainWindowHandle -ne 0) { $hwnd = $proc.MainWindowHandle; break }
    try {
        $parentId = (Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)" -ErrorAction Stop).ParentProcessId
        $proc = Get-Process -Id $parentId -ErrorAction Stop
    } catch { $proc = $null }
}

# One Windows Terminal process hosts all its windows, so MainWindowHandle is just the one highest in
# the z-order (a minimized window drops to the back). The session console's owner is the exact one.
$session = Get-SessionConsole $claudePid
if ($session.Window -ne [IntPtr]::Zero) { $hwnd = $session.Window }

$logo = Join-Path $PSScriptRoot 'claude-logo.png'

$canFocus = $false
if ($hwnd -ne [IntPtr]::Zero) { $canFocus = Confirm-FocusProtocol }

$launch = ''
if ($canFocus) {
    $launch = "claude-focus:$([int64]$hwnd)"

    # If this is a Windows Terminal tab, record which tab fired the toast so the click
    # can re-select it (the window handle alone only brings the whole window forward).
    $myTitle = ConvertTo-NormTitle $session.Title
    if ($myTitle) {
        try {
            $tabs = Get-WtTabElements ([int]([int64]$hwnd))
            for ($i = 0; $i -lt $tabs.Count; $i++) {
                if ((ConvertTo-NormTitle $tabs[$i].Current.Name) -eq $myTitle) {
                    $launch += "?tab=$i&title=$([uri]::EscapeDataString($myTitle))"
                    break
                }
            }
        } catch { }
    }
}

# Publish under the "Claude Code" AppUserModelId so the toast is branded with our name and logo.
Confirm-ToastAppId

# WinRT toast APIs aren't projected into pwsh 7, so hand the display off to Windows PowerShell
# 5.1 (always present on Win10/11). show-toast.ps1 escapes the strings and shows the toast.
$ps51 = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$showScript = Join-Path $PSScriptRoot 'show-toast.ps1'
& $ps51 -NoProfile -STA -ExecutionPolicy Bypass -File $showScript `
    -Title $Title -Message $Message -Launch $launch -AppId $appId -Logo $logo -Sound $Sound
