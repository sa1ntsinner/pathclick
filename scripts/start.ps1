# Starts pathclick.ahk in the background unless this copy is already running.
# Called by the plugin's SessionStart hook; safe to run by hand.
$script = (Resolve-Path (Join-Path $PSScriptRoot 'pathclick.ahk')).Path

$running = @(Get-CimInstance Win32_Process -Filter "Name like 'AutoHotkey%'" |
    Where-Object { $_.CommandLine -match 'pathclick\.ahk' })
if ($running | Where-Object { $_.CommandLine.Replace('/', '\') -like "*$script*" }) { exit 0 }

# A copy from an older plugin version would handle every click twice.
$running | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

$exe = @(
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
    "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
    (Get-Command AutoHotkey64.exe -ErrorAction SilentlyContinue).Source
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $exe) {
    'pathclick: AutoHotkey v2 is not installed, so file paths in the terminal are not clickable. Install it with: winget install AutoHotkey.AutoHotkey'
    exit 0
}
Start-Process -FilePath $exe -ArgumentList "`"$script`""
