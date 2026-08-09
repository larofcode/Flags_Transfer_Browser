$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'Chromium Flags Transfer'

function Pause-And-Exit([int]$Code = 0) {
    Write-Host ''
    Read-Host 'Press Enter to close'
    exit $Code
}

$payloadPath = Join-Path $PSScriptRoot 'chrome-flags.json'
if (-not (Test-Path -LiteralPath $payloadPath)) {
    Write-Host 'ERROR: chrome-flags.json was not found.' -ForegroundColor Red
    Pause-And-Exit 1
}

$options = @(
    [pscustomobject]@{ Name = 'Google Chrome'; Process = 'chrome'; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State" },
    [pscustomobject]@{ Name = 'Microsoft Edge'; Process = 'msedge'; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State" },
    [pscustomobject]@{ Name = 'Brave'; Process = 'brave'; Path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State" },
    [pscustomobject]@{ Name = 'Yandex Browser'; Process = 'browser'; Path = "$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data\Local State" },
    [pscustomobject]@{ Name = 'Vivaldi'; Process = 'vivaldi'; Path = "$env:LOCALAPPDATA\Vivaldi\User Data\Local State" },
    [pscustomobject]@{ Name = 'Opera'; Process = 'opera'; Path = "$env:APPDATA\Opera Software\Opera Stable\Local State" },
    [pscustomobject]@{ Name = 'Opera GX'; Process = 'opera'; Path = "$env:APPDATA\Opera Software\Opera GX Stable\Local State" }
)

Write-Host 'Chromium Flags Transfer' -ForegroundColor Cyan
Write-Host 'This tool replaces only browser.enabled_labs_experiments.'
Write-Host ''
for ($i = 0; $i -lt $options.Count; $i++) {
    Write-Host ("{0}. {1}" -f ($i + 1), $options[$i].Name)
}
Write-Host '8. Custom Local State path'
Write-Host ''

$choiceText = Read-Host 'Choose target browser (1-8)'
$choice = 0
if (-not [int]::TryParse($choiceText, [ref]$choice) -or $choice -lt 1 -or $choice -gt 8) {
    Write-Host 'ERROR: invalid choice.' -ForegroundColor Red
    Pause-And-Exit 1
}

if ($choice -eq 8) {
    $targetPath = Read-Host 'Enter the full path to Local State'
    $processName = $null
    $targetName = 'Custom Chromium browser'
} else {
    $selected = $options[$choice - 1]
    $targetPath = $selected.Path
    $processName = $selected.Process
    $targetName = $selected.Name
}

if ($processName -and (Get-Process -Name $processName -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: $targetName is still running. Close all its windows and try again." -ForegroundColor Red
    Pause-And-Exit 1
}

if (-not (Test-Path -LiteralPath $targetPath)) {
    Write-Host 'ERROR: Local State was not found at:' -ForegroundColor Red
    Write-Host $targetPath
    Pause-And-Exit 1
}

$payload = Get-Content -LiteralPath $payloadPath -Raw -Encoding UTF8 | ConvertFrom-Json
$flags = @($payload.enabled_labs_experiments)
if ($flags.Count -eq 0) {
    Write-Host 'ERROR: the export contains no flags.' -ForegroundColor Red
    Pause-And-Exit 1
}

Write-Host ''
Write-Host "Target: $targetName"
Write-Host "Flags to import: $($flags.Count)"
Write-Host "File: $targetPath"
$confirmation = Read-Host 'Type YES to continue'
if ($confirmation -ne 'YES') {
    Write-Host 'Cancelled. No files were changed.' -ForegroundColor Yellow
    Pause-And-Exit 0
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = "$targetPath.flags-backup-$timestamp"
Copy-Item -LiteralPath $targetPath -Destination $backupPath -Force

try {
    $state = Get-Content -LiteralPath $targetPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $state.browser) {
        $state | Add-Member -MemberType NoteProperty -Name browser -Value ([pscustomobject]@{})
    }
    if ($null -eq $state.browser.enabled_labs_experiments) {
        $state.browser | Add-Member -MemberType NoteProperty -Name enabled_labs_experiments -Value $flags
    } else {
        $state.browser.enabled_labs_experiments = $flags
    }

    $updatedJson = $state | ConvertTo-Json -Depth 100 -Compress
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($targetPath, $updatedJson, $utf8NoBom)

    Write-Host ''
    Write-Host "SUCCESS: imported $($flags.Count) flag values." -ForegroundColor Green
    Write-Host "Backup: $backupPath"
} catch {
    Copy-Item -LiteralPath $backupPath -Destination $targetPath -Force
    Write-Host ''
    Write-Host 'ERROR: import failed. The original file was restored.' -ForegroundColor Red
    Write-Host $_.Exception.Message
    Pause-And-Exit 1
}

Pause-And-Exit 0
