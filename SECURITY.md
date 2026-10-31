# Security

## Verify what you download

Every release of `cosec-cli` ships `SHA256SUMS` covering all files, a CycloneDX SBOM per binary (`*.cdx.json`),
and, once releases are signed, a cosign signature `SHA256SUMS.sig` made with the key whose public half is
[`cosign.pub`](cosign.pub) in this repository (also embedded in `install.sh` and `install.ps1`; the three copies are
compared by `lint.yml`).

```sh
# 1. checksums — Linux
sha256sum -c --ignore-missing SHA256SUMS
# 1. checksums — macOS
grep "$(ls cosec-cli_*_darwin_*.tar.gz)" SHA256SUMS | shasum -a 256 -c -
# 2. signature of the checksum file (when SHA256SUMS.sig is attached)
cosign verify-blob --key cosign.pub --signature SHA256SUMS.sig SHA256SUMS
```

```powershell
# Windows
$want = (Select-String -Path SHA256SUMS -Pattern '_windows_amd64\.zip$').Line.Split(' ')[0]
(Get-FileHash cosec-cli_*_windows_amd64.zip -Algorithm SHA256).Hash.ToLower() -eq $want
```

A checksum mismatch means a corrupted or tampered download. Delete the file and download it again. If it
happens twice, report it (below) with the file name, the hash you got and where you downloaded from.

`install.sh` and `install.ps1` perform the sha256 check on every run and the signature check whenever `cosign`
is installed (`COSEC_CLI_REQUIRE_SIG=1` makes a missing or failing signature fatal).

## What this repository is

This repository distributes **binaries only**. It holds no source code. The "Source code (zip / tar.gz)"
archives GitHub attaches to every release automatically contain nothing but the files you see on `main`
(README, LICENSE, SECURITY, the install scripts, the public key and the workflows). The `verify-release`
workflow checks this after every release.

The binaries are built with `CGO_ENABLED=0 -trimpath -ldflags "-s -w"` (static, no build-machine paths,
no symbol table) and gated by CoSec Shield itself before they are signed.

## What cosec-cli sends

- The upload / gate / `case` commands talk only to the `COSEC_URL` you configure, over HTTPS (plain `http://`
  is refused except for localhost), with the token from `COSEC_TOKEN`. The token is never accepted as a flag.
- `cosec-cli update --check` makes one `HEAD` request to the GitHub releases page and nothing else. No other
  command checks for updates, and the binary never downloads or replaces itself.
- Every request carries `User-Agent: cosec-cli/<version> (<os>/<arch>)`. There is no telemetry.

## Reporting a vulnerability

Email **security@epicprosmart.com**. Please include the `cosec-cli --version` output, the OS, and steps to
reproduce. Do not open a public issue for security reports. You will get an acknowledgement within three
business days; fixes ship as a new release here and are announced in the release notes.

Vulnerabilities in CoSec Shield itself (the server, the portal or the GitHub Action) go to the same address.
