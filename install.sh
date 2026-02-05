#!/usr/bin/env bash
#
# Flox — reproducible environments installer

set -euo pipefail

readonly BASE_URL="https://downloads.flox.dev/by-env"

# Colors & styling (disable if not a tty)
if [[ -t 1 ]]; then
  C=$(tput setaf 6 2>/dev/null || printf '\033[36m')   # calm cyan
  G=$(tput setaf 2 2>/dev/null || printf '\033[32m')   # success green
  Y=$(tput setaf 3 2>/dev/null || printf '\033[33m')   # warn yellow
  R=$(tput setaf 1 2>/dev/null || printf '\033[31m')   # error red
  B=$(tput bold 2>/dev/null || printf '\033[1m')
  N=$(tput sgr0 2>/dev/null || printf '\033[0m')
else
  C="" G="" Y="" R="" B="" N=""
fi
## (trimmed)

# Utility functions
say()       { printf '%b\n' "${C}$*${N}"; }
success()   { printf '%b\n' "${G}✓ $*${N}"; }
warn()      { printf '%b\n' "${Y}⚠ $*${N}" >&2; }
cry()       { printf '%b\n' "${R}✗ $*${N}" >&2; exit 1; }

# Check for available commands
has() { command -v "$1" >/dev/null 2>&1; }

TMPFILES=()
cleanup_tmpfiles() {
  local f
  for f in "${TMPFILES[@]:-}"; do
    rm -f "$f" 2>/dev/null || true
  done
}
trap cleanup_tmpfiles EXIT

mktempfile() {
  local f
  if has mktemp; then
    f="$(mktemp 2>/dev/null || true)"
  fi
  if [ -z "${f:-}" ]; then
    f="/tmp/flox.$RANDOM.$$"
    : >"$f" 2>/dev/null || true
  fi
  TMPFILES+=("$f")
  printf '%s' "$f"
}

download_to() {
  local url="$1" out="$2"
  if has curl; then
    curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-delay 1 -o "$out" "$url"
    return $?
  elif has wget; then
    wget -q -O "$out" "$url"
    return $?
  else
    warn "No downloader found (curl or wget required)"
    return 127
  fi
}

## Non-interactive installer (minimal)

detect_arch() {
  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64)  echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
    *)             echo "$arch" ;;
  esac
}

# Channel (stable only)
CHANNEL="stable"

# Display banner
clear 2>/dev/null || true

cat <<EOF
${C}┌────────────────────────────────────────────┐${N}
  ${B}Flox — reproducible dev environments${N}
${C}└────────────────────────────────────────────┘${N}
EOF

say "Channel: ${B}${CHANNEL}${N}"

# Setup & cleanup
## Temp files handled via TMPFILES / mktempfile

# Prefer sudo when not running as root
if [[ $(id -u) -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

# Installation
os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(detect_arch)

case "$os" in
  darwin)
    if ! command -v brew &>/dev/null; then
      warn "Homebrew not found — inviting it over…"
      hb_tmp="$(mktempfile)"
      if download_to "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" "$hb_tmp"; then
        NONINTERACTIVE=1 /bin/bash "$hb_tmp" || cry "Homebrew setup didn't finish. See https://brew.sh"
      else
        cry "Failed to download Homebrew bootstrap script"
      fi

      # Source brew environment for both possible install locations
      for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [[ -x "$brew_path" ]] && eval "$("$brew_path" shellenv)" && break
      done

      command -v brew &>/dev/null || cry "Still no brew — manual installation required."
    fi

    say "Installing Flox via Homebrew…"
    brew install flox || cry "brew install flox hit a snag — check above."
    ;;

  linux)
    channel_url="${BASE_URL}/${CHANNEL}"

    # Nix support: follow official guidance — use `nix profile install`
    if [[ -f /etc/os-release ]] && grep -qi '^ID=nixos' /etc/os-release 2>/dev/null || [[ -f /etc/NIXOS ]] || has nix; then
      say "Detected Nix/NixOS — installing via nix profile…"
      if ! has nix; then
        cry "Nix not found. Please install Nix first: https://nixos.org/download.html"
      fi

      NX_FLAGS=(--experimental-features 'nix-command flakes' --accept-flake-config 'github:flox/flox/latest')

      # Configure Flox binary cache / substituters when possible.
      FLOX_SUBSTITUTER_URL="https://cache.flox.dev"
      FLOX_PUBLIC_KEY="flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="

      if [[ $(id -u) -eq 0 ]]; then
        # On NixOS we recommend adding the values to /etc/nixos/configuration.nix
        # and running `sudo nixos-rebuild switch`. Editing that file
        # automatically is dangerous, so we only notify the admin if missing.
        if grep -qi '^ID=nixos' /etc/os-release 2>/dev/null || [[ -f /etc/NIXOS ]]; then
          if ! grep -qF "$FLOX_SUBSTITUTER_URL" /etc/nixos/configuration.nix 2>/dev/null; then
            warn "Flox binary cache not configured in /etc/nixos/configuration.nix."
            say "Add the following to /etc/nixos/configuration.nix and run 'sudo nixos-rebuild switch':"
            printf '\n  nix.settings.trusted-substituters = [ "%s" ];\n  nix.settings.trusted-public-keys = [ "%s" ];\n\n' "$FLOX_SUBSTITUTER_URL" "$FLOX_PUBLIC_KEY"
          fi
        else
          # Generic Nix: ensure /etc/nix/nix.conf contains the substituters
          if [ -w /etc/nix ] || [ ! -e /etc/nix/nix.conf ]; then
            mkdir -p /etc/nix 2>/dev/null || true
            if ! grep -qF "$FLOX_SUBSTITUTER_URL" /etc/nix/nix.conf 2>/dev/null; then
              say "Adding Flox substituters to /etc/nix/nix.conf"
              cp /etc/nix/nix.conf /etc/nix/nix.conf.bak 2>/dev/null || true
              printf '\nextra-trusted-substituters = %s\nextra-trusted-public-keys = %s\n' "$FLOX_SUBSTITUTER_URL" "$FLOX_PUBLIC_KEY" >> /etc/nix/nix.conf
              # Restart nix-daemon if present
              if command -v systemctl &>/dev/null && systemctl is-active --quiet nix-daemon; then
                systemctl restart nix-daemon.socket || true
              fi
            fi
          else
            warn "Cannot write /etc/nix/nix.conf — please add Flox cache substituters manually."
          fi
        fi
      fi

      if [[ $(id -u) -eq 0 ]]; then
        say "Installing Flox system-wide (default profile)"
        if $SUDO -H nix profile install --profile /nix/var/nix/profiles/default "${NX_FLAGS[@]}"; then
          success "Flox installed system-wide via Nix"
          exit 0
        else
          cry "System-wide Nix install failed — see nix output above."
        fi
      else
        say "Installing Flox into the current user's profile"
        if nix profile install "${NX_FLAGS[@]}"; then
          success "Flox installed to user profile via Nix"
          exit 0
        else
          cry "User-profile Nix install failed — see nix output above."
        fi
      fi
    fi

    # Detect package manager
    if [[ -f /etc/debian_version ]]; then
      family="debian"
      suffix="deb"
      install_cmd="sudo apt install -y"
    elif [[ -f /etc/redhat-release ]] || command -v dnf &>/dev/null || command -v yum &>/dev/null; then
      family="rpm"
      suffix="rpm"
      install_cmd="sudo rpm -ivh"
      # Import GPG key for RPM-based systems
      tmpkey="$(mktempfile)"
      if download_to "${channel_url}/rpm/flox-archive-keyring.asc" "$tmpkey" 2>/dev/null; then
        if $SUDO rpm --import "$tmpkey" 2>/dev/null; then
          success "GPG key imported"
        else
          warn "GPG key import skipped (import failed)"
        fi
      fi
    else
      family="unknown"
    fi

    if [[ "$family" == "unknown" ]]; then
      cry "Automatic install not supported on this distro yet.

Quick manual steps:
  macOS           → brew install flox
  Debian/Ubuntu   → curl -LO ${channel_url}/deb/flox.deb && sudo apt install ./flox.deb
  RPM family      → curl -LO ${channel_url}/rpm/flox.rpm && sudo rpm -ivh ./flox.rpm
  Nix             → nix profile install github:flox/flox/latest
"
    fi

    tmp="$(mktempfile)"

    # Try architecture-specific package first, then generic
    pkg_found=false
    for pkg in "flox.${arch}-linux.${suffix}" "flox.${suffix}"; do
      url="${channel_url}/${suffix}/${pkg}"
      if download_to "$url" "$tmp" 2>/dev/null; then
        success "Found → ${pkg}"
        pkg_found=true
        break
      fi
      warn "${pkg} not available…"
    done

    [[ "$pkg_found" == true && -s "$tmp" ]] || cry "No usable package found in ${CHANNEL}."

    # Make the package file and containing directory world-readable/traversable
    # so tools like `_apt` can access it.
    chmod 755 "$(dirname "$tmp")" 2>/dev/null || true
    chmod 644 "$tmp" 2>/dev/null || true

    # Install using the canonical local-deb form: `apt install ./pkg.deb`.
    # Run a quiet install first, retry verbose on failure, then fall back
    # to `dpkg -i` + `apt-get install -f -y` if apt fails.
    if [[ "$family" == "debian" ]]; then
      dir="$(dirname "$tmp")"
      file="$(basename "$tmp")"
      say "Installing. sudo will ask nicely…"
      if (cd "$dir" && DEBIAN_FRONTEND=noninteractive sudo apt install -y -qq "./$file" >/dev/null 2>&1); then
        success "Package installed"
      else
        warn "Quiet install failed — retrying with output"
        if (cd "$dir" && DEBIAN_FRONTEND=noninteractive sudo apt install -y "./$file"); then
          success "Package installed"
        else
          warn "apt install failed — attempting dpkg fallback"
          if (cd "$dir" && sudo dpkg -i "./$file"); then
            # Fix any missing dependencies
            if sudo apt-get install -f -y; then
              success "Package installed (dpkg + apt -f)"
            else
              cry "dpkg install succeeded but fixing dependencies failed — see error above."
            fi
          else
            cry "Package install failed — see error above."
          fi
        fi
      fi
    else
      say "Installing. sudo will ask nicely…"
      $install_cmd "$tmp" || cry "Package install failed — see error above."
    fi
    ;;

  *)
    cry "This OS ('${os}') isn't covered by auto-install yet.

Manual options:
  macOS       → brew install flox
  Debian      → curl -LO ${BASE_URL}/stable/deb/flox.deb && sudo apt install ./flox.deb
  RPM family  → curl -LO ${BASE_URL}/stable/rpm/flox.rpm && sudo rpm -ivh ./flox.rpm
  Nix         → nix profile install github:flox/flox/latest
"
    ;;
esac

# Victory lap
if command -v flox &>/dev/null; then
  success "Flox is ready!"
  flox --version | sed 's/^/  /'
  say "First steps:"
  printf '  %sflox init%s          # create your environment\n' "$C" "$N"
  printf '  %sflox install hello%s # add a classic\n' "$C" "$N"
  printf '  %sflox activate%s      # step inside\n' "$C" "$N"
  printf '  %shello%s              # "Hello, world!"\n' "$C" "$N"
  printf '  %sflox remove hello%s  # clean up\n' "$C" "$N"
  printf '\n'
  say "Enjoy flox!"
  
  
else
  warn "'flox' not found in PATH yet. Restart your shell or check the output above."
fi

printf '\n'