# Visual QA capture on Windows: opens out/harness_preview.rbxlx in a NEW Studio window, presses Play,
# records the scripted camera tour, stops, and closes only that window.
param([string]$Dir = "$env:USERPROFILE\harness", [int]$Rec = 70)
$ErrorActionPreference = "Continue"
$place = "$Dir\harness_preview.rbxlx"
$exe = (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Recurse -Filter RobloxStudioBeta.exe | Sort LastWriteTime -Desc | Select -First 1).FullName
$ff = (Get-Command ffmpeg).Source
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W { [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); }
"@
$before = @(Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | % Id)
$t0 = Get-Date
Start-Process $exe -ArgumentList "`"$place`"" | Out-Null
$p = $null
for ($i = 0; $i -lt 90; $i++) {
  $p = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | ? { $_.MainWindowTitle -match 'harness_preview' } | Select -First 1
  if ($p) { break }; Start-Sleep 2
}
if (-not $p) { "no studio window"; exit 1 }
"window: $($p.Id) $($p.MainWindowTitle)"
if ($before -contains $p.Id) { "preview opened inside an existing Studio process - aborting to avoid touching it"; exit 1 }
Start-Sleep 15
[W]::ShowWindow($p.MainWindowHandle, 3) | Out-Null
[W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
Start-Sleep 2
$ws = New-Object -ComObject WScript.Shell
$ws.AppActivate($p.Id) | Out-Null; Start-Sleep 1
& $ff -y -loglevel error -f gdigrab -i desktop -frames:v 1 "$Dir\edit.png"
$ws.AppActivate($p.Id) | Out-Null; Start-Sleep 1
$ws.SendKeys("{ESC}"); Start-Sleep 1; $ws.AppActivate($p.Id) | Out-Null; $ws.SendKeys("{F5}")
$recStart = (Get-Date).ToUniversalTime().ToString("o")
"recstart $recStart"
& $ff -y -loglevel error -f gdigrab -framerate 10 -i desktop -t $Rec -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p "$Dir\vqa.mp4"
$ws.AppActivate($p.Id) | Out-Null; Start-Sleep 1
$ws.SendKeys("+{F5}"); Start-Sleep 4
Get-ChildItem "$env:LOCALAPPDATA\Roblox\logs" -Filter *.log | ? { $_.LastWriteTime -gt $t0 } | % {
  Select-String -Path $_.FullName -Pattern 'HarnessShot|Error|error|Stack' | % { $_.Line } } | Set-Content "$Dir\vqa_log.txt" -Encoding utf8
# close only the window we opened, discarding changes
if ($before -contains $p.Id) { "preview shares a process with an existing window; leaving it open"; exit 0 }
Stop-Process -Id $p.Id -Force
"closed $($p.Id); others still open: $((Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | % Id) -join ',') (before: $($before -join ','))"
