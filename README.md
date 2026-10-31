# cosec-cli

[ภาษาไทย](README.th.md) · [Releases](https://github.com/epicprosmart-info/cosec-cli/releases) · [CI guide](https://cosec-shield.epicprosmart.com/#/help/ci) · [Security](SECURITY.md) · [License](LICENSE.md)

Command-line client for [CoSec Shield](https://cosec-shield.epicprosmart.com): upload an SBOM from any CI and fail
the build when the project's gate says `fail`, inspect threat-case exposure (`case php2shell`), verify encrypted
audit files offline (`audit verify`), and connect an AI agent through the MCP bridge (`mcp connect`).

One static binary, no runtime, for **Linux, macOS and Windows** on amd64 and arm64. Latest release: **v1.0.0-rc.1**.

> This repository distributes **binaries only**. It contains no source code; the "Source code" archives GitHub
> attaches to every release hold nothing but the files on this page.

## Install

Every method below downloads the archive **and** `SHA256SUMS` from the same release and checks the sha256 before
anything is unpacked. Pick one per OS.

### macOS (12 or later, Apple Silicon and Intel)

**Homebrew**

```sh
brew install epicprosmart-info/tap/cosec-cli      # later: brew upgrade cosec-cli
```

**Install script** (download, read, run)

```sh
curl -fsSLO https://github.com/epicprosmart-info/cosec-cli/releases/latest/download/install.sh
sh install.sh                                    # pin: COSEC_CLI_VERSION=v1.0.0-rc.1 sh install.sh
```

**By hand**

```sh
V=v1.0.0-rc.1; B=https://github.com/epicprosmart-info/cosec-cli/releases/download/$V
curl -fsSLO "$B/cosec-cli_${V}_darwin_arm64.tar.gz" && curl -fsSLO "$B/SHA256SUMS"   # Intel: darwin_amd64
grep "_darwin_arm64.tar.gz$" SHA256SUMS | shasum -a 256 -c -
tar -xzf "cosec-cli_${V}_darwin_arm64.tar.gz" cosec-cli && sudo install -m 0755 cosec-cli /usr/local/bin/
cosec-cli --version
```

Only a file saved by a **browser** carries the quarantine flag; clear it with
`xattr -d com.apple.quarantine /usr/local/bin/cosec-cli`. Files from `curl`, Homebrew or the script do not need this.

### Windows (10 / Server 2016 or later, no administrator rights)

**Scoop**

```powershell
scoop bucket add epicprosmart-info https://github.com/epicprosmart-info/scoop-bucket
scoop install cosec-cli                          # later: scoop update cosec-cli
```

**Install script** (PowerShell 5.1 or 7; installs to `%LOCALAPPDATA%\Programs\cosec-cli` and adds it to your user PATH)

```powershell
Invoke-WebRequest https://github.com/epicprosmart-info/cosec-cli/releases/latest/download/install.ps1 -OutFile install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1          # pin: -Version v1.0.0-rc.1
```

**By hand**

```powershell
$v = 'v1.0.0-rc.1'; $b = "https://github.com/epicprosmart-info/cosec-cli/releases/download/$v"
Invoke-WebRequest "$b/cosec-cli_${v}_windows_amd64.zip" -OutFile cosec-cli.zip      # ARM: windows_arm64
Invoke-WebRequest "$b/SHA256SUMS" -OutFile SHA256SUMS
$want = (Select-String -Path SHA256SUMS -Pattern '_windows_amd64\.zip$').Line.Split(' ')[0]
if ((Get-FileHash cosec-cli.zip -Algorithm SHA256).Hash.ToLower() -ne $want) { throw 'checksum mismatch' }
Expand-Archive cosec-cli.zip -DestinationPath "$env:LOCALAPPDATA\Programs\cosec-cli" -Force
$env:Path += ";$env:LOCALAPPDATA\Programs\cosec-cli"      # this window only; the script makes it permanent
cosec-cli --version
```

### Linux (any distribution, including Alpine)

**Install script** (POSIX `sh`; needs `curl` or `wget` and `tar`)

```sh
curl -fsSLO https://github.com/epicprosmart-info/cosec-cli/releases/latest/download/install.sh
sh install.sh                                    # pin: COSEC_CLI_VERSION=v1.0.0-rc.1 sh install.sh
```

The script installs to `/usr/local/bin` when that is writable, otherwise to `~/.local/bin`, and never calls
`sudo`. Set `COSEC_CLI_INSTALL_DIR` to choose, `COSEC_CLI_BASE_URL` to use an internal mirror.

**Package** (Debian/Ubuntu or RHEL/Fedora; installs `/usr/bin/cosec-cli`, no service, no dependencies)

```sh
V=v1.0.0-rc.1; B=https://github.com/epicprosmart-info/cosec-cli/releases/download/$V
curl -fsSLO "$B/cosec-cli_${V#v}_amd64.deb" && curl -fsSLO "$B/SHA256SUMS" && sha256sum -c --ignore-missing SHA256SUMS
sudo dpkg -i "cosec-cli_${V#v}_amd64.deb"       # RHEL / Fedora: sudo rpm -i cosec-cli_${V#v}_amd64.rpm
```

**By hand** (also for Dockerfiles and runner images: pinned version, static layer)

```sh
V=v1.0.0-rc.1; B=https://github.com/epicprosmart-info/cosec-cli/releases/download/$V
curl -fsSLO "$B/cosec-cli_${V}_linux_amd64.tar.gz" && curl -fsSLO "$B/SHA256SUMS"   # ARM: linux_arm64
sha256sum -c --ignore-missing SHA256SUMS
tar -xzf "cosec-cli_${V}_linux_amd64.tar.gz" cosec-cli && sudo install -m 0755 cosec-cli /usr/local/bin/
cosec-cli --version
```

## Verify a release

| File | What it is |
|---|---|
| `cosec-cli_<tag>_<os>_<arch>.tar.gz` / `.zip` | one binary, `cosec-cli` or `cosec-cli.exe`, at the archive root |
| `cosec-cli_<x.y.z>_<arch>.deb` / `.rpm` | the same Linux binary as a package |
| `*.cdx.json` | CycloneDX SBOM of each binary |
| `SHA256SUMS` | sha256 of every file above, plus the install scripts |
| `SHA256SUMS.sig` | cosign signature of `SHA256SUMS` (attached once releases are signed; key: [`cosign.pub`](cosign.pub)) |
| `install.sh`, `install.ps1` | the scripts above, exactly as on `main` at this tag |
| `release.json` | machine-readable list of the files with sha256 and URLs |

```sh
sha256sum -c --ignore-missing SHA256SUMS                                   # macOS: shasum -a 256 -c
cosign verify-blob --key cosign.pub --signature SHA256SUMS.sig SHA256SUMS  # when SHA256SUMS.sig exists
```

A mismatch means a corrupted or tampered download: delete it, download again, and report a repeat as described in
[SECURITY.md](SECURITY.md).

## Use in CI

```sh
export COSEC_URL=https://cosec.example.com COSEC_PROJECT=01H…    # COSEC_TOKEN comes from your CI secret store
syft . -o cyclonedx-json > project_sbom.json
cosec-cli --file project_sbom.json --commit "$(git rev-parse HEAD)" --timeout 5m
```

| Exit code | Meaning |
|:---:|---|
| 0 | gate `pass` (or `warn` without `--fail-on warn`) |
| 1 | gate `fail` |
| 2 | usage / upload error (the reasons are printed) |
| 3 | timed out waiting for the scan |

The token is read only from `COSEC_TOKEN` (never a flag) and plain `http://` URLs are refused except for localhost.

- **GitHub Actions**: use the action instead, no binary needed: `epicprosmart-info/cosec-shield/.github/actions/cosec-gate@v1`.
- **GitLab, Jenkins, Azure Pipelines, Bitbucket** and everything else: install `cosec-cli` on the runner with one of the
  methods above (pin the version in runner images) and follow the
  [CI guide](https://cosec-shield.epicprosmart.com/#/help/ci) for ready-made snippets.

Other commands: `cosec-cli case <slug>`, `cosec-cli audit verify|decrypt`, `cosec-cli mcp connect|bridge|status`,
`cosec-cli -h`.

## Update

```sh
cosec-cli update --check          # compares with the latest release here; prints the upgrade command for your OS
```

The check is the only network call `cosec-cli` ever makes on its own initiative, and only when you run it. The
binary never downloads or replaces itself. Upgrade with `brew upgrade cosec-cli`, `scoop update cosec-cli`, the
install script, or the new package.

## Uninstall

| Installed with | Remove |
|---|---|
| Homebrew | `brew uninstall cosec-cli` |
| Scoop | `scoop uninstall cosec-cli` |
| install.sh / by hand | `rm /usr/local/bin/cosec-cli` (or `~/.local/bin/cosec-cli`) |
| install.ps1 / by hand | delete `%LOCALAPPDATA%\Programs\cosec-cli` and remove it from your user PATH |
| deb / rpm | `sudo dpkg -r cosec-cli` / `sudo rpm -e cosec-cli` |

MCP profiles and keys live in `~/.config/cosec-cli/` and the OS keychain; `cosec-cli mcp disconnect` removes them.

## License

Proprietary binary license, see [LICENSE.md](LICENSE.md). Third-party components are listed in the SBOM attached
to each release.
