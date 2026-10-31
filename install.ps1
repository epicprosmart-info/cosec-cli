<#
.SYNOPSIS
  Installs cosec-cli on Windows (PowerShell 5.1 or 7, no Administrator rights).

.DESCRIPTION
  Published at https://github.com/epicprosmart-info/cosec-cli. Download it, read it, then run it:

    Invoke-WebRequest https://github.com/epicprosmart-info/cosec-cli/releases/latest/download/install.ps1 -OutFile install.ps1
    powershell -ExecutionPolicy Bypass -File .\install.ps1            # or: -Version v1.2.0

  Downloads the zip for this CPU together with SHA256SUMS from the same release, always compares the
  sha256 before unpacking, verifies the cosign signature when cosign.exe is on PATH, installs into
  %LOCALAPPDATA%\Programs\cosec-cli and adds that folder to the *user* PATH. Nothing is sent anywhere
  except HTTP GET requests for the release files.

.PARAMETER Version
  Release tag such as v1.2.0 (default: latest). Env: COSEC_CLI_VERSION
.PARAMETER InstallDir
  Target folder (default: $env:LOCALAPPDATA\Programs\cosec-cli). Env: COSEC_CLI_INSTALL_DIR
.PARAMETER BaseUrl
  Mirror that serves the release files, e.g. the portal /api/downloads/<v> (air-gapped). Env: COSEC_CLI_BASE_URL
.PARAMETER RequireSignature
  Refuse to install unless the cosign signature of SHA256SUMS verifies. Env: COSEC_CLI_REQUIRE_SIG=1
#>
[CmdletBinding()]
param(
  [string]$Version = $(if ($env:COSEC_CLI_VERSION) { $env:COSEC_CLI_VERSION } else { 'latest' }),
  [string]$InstallDir = $(if ($env:COSEC_CLI_INSTALL_DIR) { $env:COSEC_CLI_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\cosec-cli' }),
  [string]$BaseUrl = $env:COSEC_CLI_BASE_URL,
  [switch]$RequireSignature = ($env:COSEC_CLI_REQUIRE_SIG -eq '1')
)

$ErrorActionPreference = 'Stop'
$Repo = 'epicprosmart-info/cosec-cli'

# Public key that signs SHA256SUMS. Must be byte-identical to cosign.pub in the repository and in install.sh
# (checked by lint.yml). Empty while releases are unsigned: signature checks are then skipped unless required.
$CosignPub = @'
'@

function Fail([int]$Code, [string]$Message) { Write-Error -Message "install.ps1: $Message" -ErrorAction Continue; exit $Code }

if ($Version -ne 'latest' -and $Version -notmatch '^v\d+\.\d+\.\d+') { Fail 2 "Version must be 'latest' or a tag like v1.2.0 (got '$Version')" }

# PowerShell 5.1 defaults to TLS 1.0 on older Windows builds; GitHub requires 1.2.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

$procArch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
switch ($procArch) {
  'AMD64' { $arch = 'amd64' }
  'ARM64' { $arch = 'arm64' }
  default { Fail 2 "unsupported CPU '$procArch' - supported: AMD64, ARM64" }
}

if ($BaseUrl) { $base = $BaseUrl.TrimEnd('/') }
elseif ($Version -eq 'latest') { $base = "https://github.com/$Repo/releases/latest/download" }
else { $base = "https://github.com/$Repo/releases/download/$Version" }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("cosec-cli-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
$keep = $false
try {
  Write-Host "fetching SHA256SUMS from $base"
  try { Invoke-WebRequest -UseBasicParsing -Uri "$base/SHA256SUMS" -OutFile (Join-Path $tmp 'SHA256SUMS') }
  catch {
    $err = $_.Exception.Message
    # GitHub's releases/latest skips pre-releases: with only -rc tags published it is a 404. Fall back to the
    # newest published release (one API call, only on this miss).
    $newest = $null
    if ($Version -eq 'latest' -and -not $BaseUrl) {
      try { $newest = (Invoke-RestMethod -UseBasicParsing -Uri "https://api.github.com/repos/$Repo/releases?per_page=1" -Headers @{ 'User-Agent' = 'cosec-cli-install' })[0].tag_name } catch { }
    }
    if ($newest -notmatch '^v\d+\.\d+\.\d+') { Fail 1 "cannot download $base/SHA256SUMS (no such release, or no network): $err" }
    Write-Host "no final release yet - using the newest pre-release $newest"
    $Version = $newest; $base = "https://github.com/$Repo/releases/download/$newest"
    try { Invoke-WebRequest -UseBasicParsing -Uri "$base/SHA256SUMS" -OutFile (Join-Path $tmp 'SHA256SUMS') }
    catch { Fail 1 "cannot download $base/SHA256SUMS (no such release, or no network): $($_.Exception.Message)" }
  }

  # The zip name carries the tag; SHA256SUMS (a fixed name) tells us which one the release holds.
  $suffix = "_windows_$arch.zip"
  $sums = Get-Content (Join-Path $tmp 'SHA256SUMS') | ForEach-Object {
    $parts = ($_ -split '\s+', 2); if ($parts.Count -eq 2) { [pscustomobject]@{ Hash = $parts[0].ToLower(); Name = $parts[1].Trim().TrimStart('*') } }
  }
  $entry = $sums | Where-Object { $_.Name -like "cosec-cli_*$suffix" } | Select-Object -First 1
  if (-not $entry) { Fail 1 "this release has no build for windows/$arch (see $base/SHA256SUMS)" }
  $file = $entry.Name
  $tag = $file.Substring('cosec-cli_'.Length, $file.Length - 'cosec-cli_'.Length - $suffix.Length)
  if ($Version -ne 'latest' -and $tag -ne $Version) { Fail 1 "SHA256SUMS at $base describes $tag, not $Version" }

  # ---- signature (cosign) ----
  $cosign = Get-Command cosign -ErrorAction SilentlyContinue
  if ($cosign -and $CosignPub.Trim()) {
    $sigOk = $true
    try { Invoke-WebRequest -UseBasicParsing -Uri "$base/SHA256SUMS.sig" -OutFile (Join-Path $tmp 'SHA256SUMS.sig') } catch { $sigOk = $false }
    if ($sigOk) {
      Set-Content -Path (Join-Path $tmp 'cosign.pub') -Value $CosignPub -NoNewline
      & $cosign.Source verify-blob --key (Join-Path $tmp 'cosign.pub') --signature (Join-Path $tmp 'SHA256SUMS.sig') (Join-Path $tmp 'SHA256SUMS') 2>$null | Out-Null
      if ($LASTEXITCODE -ne 0) { Fail 1 "cosign signature of SHA256SUMS does NOT verify - do not install; report at https://github.com/$Repo/blob/main/SECURITY.md" }
      Write-Host 'signature ok (cosign)'
    } elseif ($RequireSignature) { Fail 1 "release $tag has no SHA256SUMS.sig but a signature is required" }
    else { Write-Host "note: release $tag is not signed; sha256 is still verified" }
  } elseif ($RequireSignature) {
    if (-not $CosignPub.Trim()) { Fail 2 'a signature is required but this installer embeds no public key (releases are not signed yet)' }
    Fail 2 'a signature is required but cosign is not installed - https://docs.sigstore.dev/cosign/system_config/installation/'
  }

  # ---- download + sha256 (always) ----
  Write-Host "downloading $file"
  $zip = Join-Path $tmp $file
  try { Invoke-WebRequest -UseBasicParsing -Uri "$base/$file" -OutFile $zip } catch { Fail 1 "cannot download $base/${file}: $($_.Exception.Message)" }
  $got = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLower()
  if ($got -ne $entry.Hash) {
    Remove-Item -Force $zip
    Fail 1 "checksum mismatch for $file (expected $($entry.Hash), got $got) - download again; if it repeats, report at https://github.com/$Repo/blob/main/SECURITY.md"
  }
  Write-Host 'sha256 ok'

  # ---- install (user scope, no Administrator) ----
  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  $exe = Join-Path $tmp 'cosec-cli.exe'
  if (-not (Test-Path $exe)) { Fail 1 "the archive does not contain cosec-cli.exe" }
  Move-Item -Force -Path $exe -Destination (Join-Path $InstallDir 'cosec-cli.exe')
  Write-Host "installed $InstallDir\cosec-cli.exe"

  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $onPath = ($userPath -split ';') -contains $InstallDir
  if (-not $onPath) {
    [Environment]::SetEnvironmentVariable('Path', (($userPath.TrimEnd(';') + ';' + $InstallDir).TrimStart(';')), 'User')
    Write-Host "added $InstallDir to your user PATH - open a new terminal for it to take effect"
  }
  if (-not (($env:Path -split ';') -contains $InstallDir)) { $env:Path += ";$InstallDir" }
  & (Join-Path $InstallDir 'cosec-cli.exe') --version
} finally {
  if (-not $keep) { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $tmp }
}
