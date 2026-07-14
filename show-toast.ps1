# Displays a native Windows toast via WinRT (Windows.UI.Notifications). Runs under Windows
# PowerShell 5.1 — the WinRT projection is unavailable in pwsh 7, so notify.ps1 (pwsh 7) builds
# everything and shells out to this script for the actual Show. Receives plain string args:
#   -Title / -Message  : toast text
#   -Launch            : `claude-focus:<hwnd>[?tab&title]` URI; empty => non-clickable toast
#   -AppId             : registered AppUserModelId (controls the toast's name/icon)
#   -Logo              : path to the circular app-logo-override image
#   -Sound             : ms-winsoundevent:* URI to play; empty => silent toast
param(
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$Message,
    [Parameter()][AllowEmptyString()][string]$Launch = '',
    [Parameter(Mandatory)][string]$AppId,
    [Parameter(Mandatory)][string]$Logo,
    [Parameter()][AllowEmptyString()][string]$Sound = 'ms-winsoundevent:Notification.Default'
)

$ErrorActionPreference = 'Stop'

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

# Escape every interpolated value — text and attributes alike — so `& < > "` in the title,
# message, or launch URI can't break the toast XML (BurntToast did this for us).
$titleXml = [System.Security.SecurityElement]::Escape($Title)
$messageXml = [System.Security.SecurityElement]::Escape($Message)
$logoXml = [System.Security.SecurityElement]::Escape($Logo)

# Only make the toast clickable when notify.ps1 found a window to focus.
if ([string]::IsNullOrEmpty($Launch)) {
    $toastAttrs = ''
}
else {
    $launchXml = [System.Security.SecurityElement]::Escape($Launch)
    $toastAttrs = " launch=`"$launchXml`" activationType=`"protocol`""
}

# Empty sound => silent toast; otherwise play the given ms-winsoundevent:* URI.
if ([string]::IsNullOrEmpty($Sound)) {
    $audioXml = '<audio silent="true"/>'
}
else {
    $soundXml = [System.Security.SecurityElement]::Escape($Sound)
    $audioXml = "<audio src=`"$soundXml`"/>"
}

$xml = @"
<toast$toastAttrs>
  <visual>
    <binding template="ToastGeneric">
      <text>$titleXml</text>
      <text>$messageXml</text>
      <image placement="appLogoOverride" hint-crop="circle" src="$logoXml"/>
    </binding>
  </visual>
  $audioXml
</toast>
"@

$doc = New-Object Windows.Data.Xml.Dom.XmlDocument
$doc.LoadXml($xml)
$toast = New-Object Windows.UI.Notifications.ToastNotification($doc)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($toast)
