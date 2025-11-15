# tools/pack.ps1
<#
Generic WoW addon packer/deployer for repos where repo root == addon folder.
Run from anywhere; source folder is resolved from this script's path.
Modes: zip | deploy | both
Examples:
  pwsh -File tools/pack.ps1 -Mode zip    -Version 0.1.0 -Open
  pwsh -File tools/pack.ps1 -Mode deploy -Game retail -Open
  pwsh -File tools/pack.ps1 -Mode both   -Version 0.1.1 -Game retail -Open -Pause
#>
[CmdletBinding()]
param(
  [string]$Version,
  [ValidateSet('zip','deploy','both')][string]$Mode = 'zip',
  [ValidateSet('retail','classic')][string]$Game = 'retail',
  [string]$WowRoot,
  [switch]$NoBump,
  [switch]$Open,     # open output location in Explorer
  [switch]$Pause     # wait for keypress before exiting (useful when double-clicked)
)

$ErrorActionPreference = 'Stop'
function Info($m){ Write-Host "[INFO ] $m" -f Cyan }
function Ok($m){   Write-Host "[ OK  ] $m" -f Green }
function Warn($m){ Write-Host "[WARN ] $m" -f Yellow }

# --- Resolve addon root from script path (robust across CWD/Task/.bat) ---
$ScriptDir = Split-Path -Parent $PSCommandPath
$AddonDir  = Split-Path -Parent $ScriptDir       # ..\  -> addon root
if (-not (Test-Path $AddonDir)) { throw "Cannot resolve addon root from script path: $PSCommandPath" }
$AddonName = Split-Path $AddonDir -Leaf

# --- TOC detection ---
$toc = Get-ChildItem $AddonDir -Filter *.toc -File | Select-Object -First 1
if (-not $toc) { throw "No .toc found in $AddonDir" }
$toc = $toc.FullName
Info "Addon: $AddonName"
Info "Source: $AddonDir"
Info "TOC   : $toc"

# --- Version handling (insert or update ## Version:) ---
if (-not $Version -and -not $NoBump -and $Mode -ne 'deploy') {
  $Version = Read-Host "Enter version (e.g. 0.1.0)"
}
if (-not $NoBump -and $Mode -ne 'deploy') {
  $raw = Get-Content $toc -Raw
  if ([regex]::IsMatch($raw,'(?im)^\s*##\s*Version\s*:')) {
    $raw = [regex]::Replace($raw,'(?im)^\s*##\s*Version\s*:.*$',"## Version: $Version",1)
  } else {
    if ([regex]::IsMatch($raw,'(?im)^\s*##\s*Title\s*:')) {
      $raw = [regex]::Replace($raw,'(?im)^\s*##\s*Title\s*:.*$',{ param($m) $m.Value + "`r`n## Version: " + $Version },1)
    } else {
      $raw = "## Version: $Version`r`n" + $raw
    }
  }
  Set-Content -Path $toc -Value $raw -NoNewline
  Ok "TOC Version -> $Version"
} else {
  $Version = [regex]::Match((Get-Content $toc -Raw),'(?im)^\s*##\s*Version\s*:\s*(.+?)\s*$').Groups[1].Value
  if (-not $Version) { Info "No version bump (deploy-only)"; $Version = "(no-bump)" }
  else { Info "Using TOC Version: $Version" }
}

function Make-Zip([string]$addon,[string]$ver,[string]$name){
  $out = Join-Path $addon 'dist'
  if (!(Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }
  $zip = Join-Path $out ("{0}-{1}.zip" -f $name, $ver)
  if (Test-Path $zip) { Remove-Item $zip -Force }

  # Stage into folder named <AddonName> so the zip has a single top-level directory
  $stage = Join-Path $env:TEMP ("addon-stage-" + [guid]::NewGuid())
  New-Item -ItemType Directory -Path $stage | Out-Null
  $container = Join-Path $stage $name
  New-Item -ItemType Directory -Path $container | Out-Null

  $exclude = @('.git','.github','.vscode','dist','tools','*.ps1')
  Get-ChildItem -Path $addon -Force -Recurse | Where-Object {
    -not ($_.FullName -like "$stage*") -and
    -not ($_.PSIsContainer -and $exclude -contains $_.Name) -and
    -not ($_.Name -like '*.ps1' -and $_.DirectoryName -like '*\tools')
  } | ForEach-Object {
    $rel = $_.FullName.Substring($addon.Length).TrimStart('\','/')
    $target = Join-Path $container $rel
    if ($_.PSIsContainer) {
      if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target | Out-Null }
    } else {
      $dir = Split-Path -Parent $target
      if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
      Copy-Item $_.FullName -Destination $target -Force
    }
  }

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip)
  Remove-Item -Recurse -Force $stage
  Ok "ZIP → $zip"
  return $zip
}

function Get-WowRoot([string]$Override){
  if ($Override) { if (Test-Path $Override) { return (Resolve-Path $Override).Path } else { throw "WowRoot not found: $Override" } }
  $pf86=${env:ProgramFiles(x86)}; $pf=${env:ProgramFiles}
  $cands=@(
    (Join-Path $pf86 'World of Warcraft'),
    (Join-Path $pf   'World of Warcraft'),
    'C:\World of Warcraft'
  )
  foreach ($d in (Get-PSDrive -PSProvider FileSystem | % Root)) {
    $cands += (Join-Path $d 'Program Files (x86)\World of Warcraft')
    $cands += (Join-Path $d 'World of Warcraft')
  }
  foreach ($c in $cands | Get-Unique) {
    if (Test-Path (Join-Path $c '_retail_'))  { return $c }
    if (Test-Path (Join-Path $c '_classic_')) { return $c }
  }
  throw "Could not auto-detect WoW root. Use -WowRoot 'C:\Program Files (x86)\World of Warcraft'"
}
function Get-AddOnsPath([string]$root,[string]$game){
  if ($game -eq 'retail'){ return (Join-Path $root '_retail_\Interface\AddOns') }
  return (Join-Path $root '_classic_\Interface\AddOns')
}
function Deploy-Addon([string]$addon,[string]$addons,[string]$name){
  $dest = Join-Path $addons $name
  Info "Deploying → $dest"
  if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
  New-Item -ItemType Directory -Path $dest | Out-Null
  # Exclude tooling
  robocopy $addon $dest /MIR /XD .git .github .vscode dist tools /XF *.ps1 README* LICENSE* *.zip > $null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
  Ok "Deployed files."
  return $dest
}

# --- Do work ---
$zipPath = $null
$deployPath = $null

switch ($Mode) {
  'zip'    {
    $zipPath = Make-Zip -addon $AddonDir -ver $Version -name $AddonName
    Info "Output ZIP: $zipPath"
    if ($Open) { try { Invoke-Item (Split-Path -Parent $zipPath) } catch {} }
  }
  'deploy' {
    $root   = Get-WowRoot -Override $WowRoot
    $addons = Get-AddOnsPath -root $root -game $Game
    Info "WoW root : $root"
    Info "AddOns   : $addons"
    if (!(Test-Path $addons)) { New-Item -ItemType Directory -Path $addons -Force | Out-Null }
    $deployPath = Deploy-Addon -addon $AddonDir -addons $addons -name $AddonName
    if ($Open) { try { Invoke-Item $deployPath } catch {} }
  }
  'both'   {
    $zipPath = Make-Zip -addon $AddonDir -ver $Version -name $AddonName
    $root   = Get-WowRoot -Override $WowRoot
    $addons = Get-AddOnsPath -root $root -game $Game
    Info "WoW root : $root"
    Info "AddOns   : $addons"
    if (!(Test-Path $addons)) { New-Item -ItemType Directory -Path $addons -Force | Out-Null }
    $deployPath = Deploy-Addon -addon $AddonDir -addons $addons -name $AddonName
    if ($Open) { try { Invoke-Item $deployPath } catch {} }
    Info "Output ZIP: $zipPath"
  }
}

Ok "Done."
if ($Pause) {
  Write-Host ""
  Read-Host "Press ENTER to close"
}
