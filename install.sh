#!/bin/sh
# cosec-cli installer for Linux (any distribution, including Alpine/busybox) and macOS.
# Published at https://github.com/epicprosmart-info/cosec-cli — download it, read it, then run it:
#
#   curl -fsSLO https://github.com/epicprosmart-info/cosec-cli/releases/latest/download/install.sh
#   sh install.sh                     # or: COSEC_CLI_VERSION=v1.2.0 sh install.sh
#
# usage: sh install.sh [-v vX.Y.Z] [-d DIR] [-b BASE_URL] [--require-sig] [-h]
# env:   COSEC_CLI_VERSION      release tag (default: latest)
#        COSEC_CLI_INSTALL_DIR  target directory (default: /usr/local/bin when writable, else $HOME/.local/bin)
#        COSEC_CLI_BASE_URL     mirror that serves the release files (air-gapped networks, portal /api/downloads/<v>)
#        COSEC_CLI_REQUIRE_SIG  1 = refuse to install unless the cosign signature of SHA256SUMS verifies
#
# The script always checks the sha256 of the archive against SHA256SUMS from the same release before it
# unpacks anything, verifies the cosign signature when cosign is installed, never uses sudo, and makes no
# network request other than HTTP GET to the release files. Exit codes: 0 ok, 1 verification failed or
# cannot write the target, 2 usage / unsupported platform / missing tool.
set -eu

REPO=epicprosmart-info/cosec-cli
VERSION=${COSEC_CLI_VERSION:-latest}
DIR=${COSEC_CLI_INSTALL_DIR:-}
BASE=${COSEC_CLI_BASE_URL:-}
REQUIRE_SIG=${COSEC_CLI_REQUIRE_SIG:-0}

# Public key that signs SHA256SUMS. Must be byte-identical to cosign.pub in the repository and in install.ps1
# (checked by lint.yml). Empty while releases are unsigned: signature checks are then skipped unless required.
cosign_pub() {
cat <<'COSIGN_PUB'
COSIGN_PUB
}

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }
log() { printf '%s\n' "$*"; }
die() { code=$1; shift; printf 'install.sh: %s\n' "$*" >&2; exit "$code"; }

while [ $# -gt 0 ]; do
  case $1 in
    -v|--version) [ $# -ge 2 ] || die 2 "-v needs a value"; VERSION=$2; shift 2 ;;
    -d|--dir) [ $# -ge 2 ] || die 2 "-d needs a value"; DIR=$2; shift 2 ;;
    -b|--base-url) [ $# -ge 2 ] || die 2 "-b needs a value"; BASE=$2; shift 2 ;;
    --require-sig) REQUIRE_SIG=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die 2 "unknown argument: $1" ;;
  esac
done

# ---- tools ------------------------------------------------------------------------------------------------
if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL --retry 2 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -q -O "$2" "$1"; }
else
  die 2 "curl or wget is required (apk add curl / apt-get install curl)"
fi
command -v tar >/dev/null 2>&1 || die 2 "tar is required"
if command -v sha256sum >/dev/null 2>&1; then
  sha256_of() { sha256sum "$1" | cut -d' ' -f1; }
elif command -v shasum >/dev/null 2>&1; then
  sha256_of() { shasum -a 256 "$1" | cut -d' ' -f1; }
elif command -v openssl >/dev/null 2>&1; then
  sha256_of() { openssl dgst -sha256 -r "$1" | cut -d' ' -f1; }
else
  die 2 "sha256sum, shasum or openssl is required to verify the download"
fi

# ---- platform ---------------------------------------------------------------------------------------------
case $(uname -s) in
  Linux) os=linux ;;
  Darwin) os=darwin ;;
  *) die 2 "unsupported OS $(uname -s) — supported: linux, darwin (amd64, arm64); Windows: install.ps1" ;;
esac
case $(uname -m) in
  x86_64|amd64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) die 2 "unsupported CPU $(uname -m) — supported: amd64 (x86_64), arm64 (aarch64)" ;;
esac
if [ "$os" = darwin ] && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = 1 ]; then
  log "note: this shell runs under Rosetta; installing the native arm64 build"
  arch=arm64
fi

# ---- source -----------------------------------------------------------------------------------------------
case $VERSION in
  latest|v[0-9]*.[0-9]*.[0-9]*) ;;
  *) die 2 "COSEC_CLI_VERSION must be 'latest' or a tag like v1.2.0 (got '$VERSION')" ;;
esac
if [ -n "$BASE" ]; then base=${BASE%/}
elif [ "$VERSION" = latest ]; then base="https://github.com/$REPO/releases/latest/download"
else base="https://github.com/$REPO/releases/download/$VERSION"; fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/cosec-cli.XXXXXX")
keep=0
cleanup() { [ "$keep" = 1 ] || rm -rf "$tmp"; }
trap cleanup EXIT INT TERM

log "fetching SHA256SUMS from $base"
if ! fetch "$base/SHA256SUMS" "$tmp/SHA256SUMS" 2>/dev/null && [ "$VERSION" = latest ] && [ -z "$BASE" ]; then
  # GitHub's releases/latest skips pre-releases: with only -rc tags published it is a 404. Fall back to the
  # newest published release (one API call, only on this miss).
  fetch "https://api.github.com/repos/$REPO/releases?per_page=1" "$tmp/releases.json" 2>/dev/null || true
  newest=$(sed -n 's/^ *"tag_name": *"\(v[0-9][^"]*\)".*/\1/p' "$tmp/releases.json" 2>/dev/null | head -1)
  [ -n "$newest" ] || die 1 "cannot download $base/SHA256SUMS (no such release, or no network)"
  log "no final release yet — using the newest pre-release $newest"
  VERSION=$newest; base="https://github.com/$REPO/releases/download/$newest"
  fetch "$base/SHA256SUMS" "$tmp/SHA256SUMS" || die 1 "cannot download $base/SHA256SUMS (no such release, or no network)"
elif [ ! -s "$tmp/SHA256SUMS" ]; then
  die 1 "cannot download $base/SHA256SUMS (no such release, or no network)"
fi
# The archive name carries the tag; SHA256SUMS (a fixed name) tells us which one the release holds.
file=$(awk -v s="_${os}_${arch}.tar.gz" 'index($2, "cosec-cli_") == 1 && substr($2, length($2) - length(s) + 1) == s { print $2; exit }' "$tmp/SHA256SUMS")
[ -n "$file" ] || die 1 "this release has no build for $os/$arch (see $base/SHA256SUMS)"
tag=${file#cosec-cli_}; tag=${tag%"_${os}_${arch}.tar.gz"}
if [ "$VERSION" != latest ] && [ "$tag" != "$VERSION" ]; then
  die 1 "SHA256SUMS at $base describes $tag, not $VERSION"
fi

# ---- signature (cosign) -----------------------------------------------------------------------------------
pub=$(cosign_pub)
if command -v cosign >/dev/null 2>&1 && [ -n "$pub" ]; then
  if fetch "$base/SHA256SUMS.sig" "$tmp/SHA256SUMS.sig" 2>/dev/null; then
    printf '%s\n' "$pub" > "$tmp/cosign.pub"
    cosign verify-blob --key "$tmp/cosign.pub" --signature "$tmp/SHA256SUMS.sig" "$tmp/SHA256SUMS" >/dev/null 2>&1 \
      || die 1 "cosign signature of SHA256SUMS does NOT verify — do not install; report at https://github.com/$REPO/blob/main/SECURITY.md"
    log "signature ok (cosign)"
  elif [ "$REQUIRE_SIG" = 1 ]; then
    die 1 "release $tag has no SHA256SUMS.sig but COSEC_CLI_REQUIRE_SIG=1"
  else
    log "note: release $tag is not signed; sha256 is still verified"
  fi
elif [ "$REQUIRE_SIG" = 1 ]; then
  if [ -z "$pub" ]; then die 2 "COSEC_CLI_REQUIRE_SIG=1 but this installer embeds no public key (releases are not signed yet)"; fi
  die 2 "COSEC_CLI_REQUIRE_SIG=1 but cosign is not installed — https://docs.sigstore.dev/cosign/system_config/installation/"
fi

# ---- download + sha256 (always) --------------------------------------------------------------------------
log "downloading $file"
fetch "$base/$file" "$tmp/$file" || die 1 "cannot download $base/$file"
want=$(awk -v f="$file" '$2 == f || $2 == "*" f { print $1; exit }' "$tmp/SHA256SUMS")
got=$(sha256_of "$tmp/$file")
if [ -z "$want" ] || [ "$got" != "$want" ]; then
  rm -f "$tmp/$file"
  die 1 "checksum mismatch for $file (expected ${want:-?}, got $got) — download again; if it repeats, report at https://github.com/$REPO/blob/main/SECURITY.md"
fi
log "sha256 ok"
tar -xzf "$tmp/$file" -C "$tmp" cosec-cli
chmod 0755 "$tmp/cosec-cli"

# ---- install (no sudo) ------------------------------------------------------------------------------------
if [ -z "$DIR" ]; then
  if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then DIR=/usr/local/bin; else DIR="$HOME/.local/bin"; fi
fi
case $DIR in "$HOME"/*) mkdir -p "$DIR" ;; esac
if [ ! -d "$DIR" ] || [ ! -w "$DIR" ]; then
  keep=1
  log "cannot write to $DIR. The verified binary is at $tmp/cosec-cli — install it yourself, for example:"
  log "  sudo install -m 0755 $tmp/cosec-cli /usr/local/bin/cosec-cli && rm -rf $tmp"
  exit 1
fi
cp "$tmp/cosec-cli" "$DIR/.cosec-cli.$$" && chmod 0755 "$DIR/.cosec-cli.$$" && mv -f "$DIR/.cosec-cli.$$" "$DIR/cosec-cli"
log "installed $DIR/cosec-cli"
"$DIR/cosec-cli" --version
case ":$PATH:" in
  *":$DIR:"*) ;;
  *) log ""; log "$DIR is not in PATH. Add this line to your shell profile (~/.profile, ~/.bashrc or ~/.zshrc):"
     log "  export PATH=\"$DIR:\$PATH\"" ;;
esac
