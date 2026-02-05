#!/usr/bin/env bash
#
#    Flox — reproducible environments that travel with you
#    curl -fsSL https://get.flox.dev | bash
#    curl -fsSL https://get.flox.dev | bash -s -- --nightly   (send coffee)
#

set -euo pipefail

readonly BASE_URL="https://downloads.flox.dev/by-env"

# ────────────────────────────────────────
#  Colors & styling (disable if not a tty)
# ────────────────────────────────────────
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

readonly -a STABLE_POETRY=(
  "Because 'works on my machine' should work on ALL machines. Yes, even Jenkins."
  "Dependencies that don't require a PhD in YAML archaeology."
  "It's like Docker, but your laptop battery doesn't burst into flames."
  "Finally, an environment that survives the 'npm install' boss fight."
  "Your dotfiles, but they actually work when you switch laptops at 2 AM."
  "No more 'let me share my screen' during onboarding. Just... flox activate."
  "Kubernetes at home? Nah. This? This sparks joy."
   "Small, reliable dev environments that just work."
)

readonly -a NIGHTLY_POETRY=(
  "Nightly builds: for when 'stable' sounds too much like your relationships."
  "YOLO-driven development. We merge to main and pray."
  "Fresh code, hot off the CI/CD pipeline — unit tests TBD."
  "Production is just nightly with more users, change my mind."
  "Warning: May cause random Slack pings at 3 AM. Worth it."
  "If it compiles, we ship it. That's the nightly way."
  "Bug fixes from the future, bugs from the present. Perfectly balanced."
)

# ────────────────────────────────────────
#  Utility functions
# ────────────────────────────────────────
say()       { printf '%b\n' "${C}$*${N}"; }
success()   { printf '%b\n' "${G}✓ $*${N}"; }
warn()      { printf '%b\n' "${Y}⚠ $*${N}" >&2; }
cry()       { printf '%b\n' "${R}✗ $*${N}" >&2; exit 1; }

random_line() {
  local -a arr=("$@")
  local line
  line="${arr[RANDOM % ${#arr[@]}]}"
  # Trim leading/trailing whitespace
  line="${line#${line%%[![:space:]]*}}"
  line="${line%${line##*[![:space:]]}}"
  printf '%s' "$line"
}

# Check for available commands
has() { command -v "$1" >/dev/null 2>&1; }

# Download helper with curl/wget fallback and retries for robustness
download_to() {
  local url="$1" out="$2"
  if has curl; then
    curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-delay 1 -o "$out" "$url"
    return $?
  elif has wget; then
    wget -q -O "$out" "$url"
    return $?
  else
    return 127
  fi
}

usage() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS]

Install Flox — reproducible environments that travel with you.

Options:
  --nightly     Install nightly build instead of stable
  --help, -h    Show this help message

Environment Variables:
  FLOX_CHANNEL  Set to 'nightly' for nightly builds

Examples:
  curl -fsSL https://get.flox.dev | bash
  curl -fsSL https://get.flox.dev | bash -s -- --nightly
EOF
  exit 0
}

detect_arch() {
  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64)  echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
    *)             echo "$arch" ;;
  esac
}

# ────────────────────────────────────────
#  Parse arguments & configure channel
# ────────────────────────────────────────
CHANNEL="${FLOX_CHANNEL:-stable}"

for arg in "$@"; do
  case "$arg" in
    --nightly)  CHANNEL="nightly" ;;
    --help|-h)  usage ;;
    *)          warn "Unknown option: $arg" ;;
  esac
done

if [[ $CHANNEL == "nightly" ]]; then
  POETRY=("${NIGHTLY_POETRY[@]}")
else
  CHANNEL="stable"
  POETRY=("${STABLE_POETRY[@]}")
fi

# ────────────────────────────────────────
#  Display banner
# ────────────────────────────────────────
clear 2>/dev/null || true

cat <<EOF
${C}┌────────────────────────────────────────────┐${N}
  ${B}Flox${N} — dev environments that travel with you
  ${C}$(random_line "${POETRY[@]}")${N}
${C}└────────────────────────────────────────────┘${N}
EOF

say "Channel: ${B}${CHANNEL}${N}"

# ────────────────────────────────────────
#  Setup & cleanup
# ────────────────────────────────────────
# Use a temporary directory so we can control the downloaded filename
tmpdir=$(mktemp -d)
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT INT TERM

# Prefer sudo when not running as root
if [[ $(id -u) -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

# ────────────────────────────────────────
#  Installation
# ────────────────────────────────────────
os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(detect_arch)

case "$os" in
  darwin)
    if ! command -v brew &>/dev/null; then
      warn "Homebrew not found — inviting it over…"
      NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        || cry "Homebrew setup didn't finish. See https://brew.sh"

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
      tmpkey="${tmpdir}/flox-archive-keyring.asc"
      if download_to "${channel_url}/rpm/flox-archive-keyring.asc" "$tmpkey" 2>/dev/null; then
        if $SUDO rpm --import "$tmpkey" 2>/dev/null; then
          success "GPG key imported"
        else
          warn "GPG key import skipped (import failed)"
        fi
      else
        warn "GPG key download skipped (common for nightly)"
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

    # Ensure the downloaded file has a proper extension so installers
    # like `apt` accept it. We'll write into our tempdir with a name.
    tmp="${tmpdir}/flox.${suffix}"


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

# ────────────────────────────────────────
#  Victory lap
# ────────────────────────────────────────
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
  say "$(random_line "${POETRY[@]}")"
else
  warn "'flox' not found in PATH yet. Restart your shell or check the output above."
fi

printf '\n'