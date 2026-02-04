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
  printf '%s' "${arr[RANDOM % ${#arr[@]}]}"
}

# spinner & friendly downloader (tty-only animation)
show_spinner() {
  local pid=$1; local msg=${2:-working}
  if [[ ! -t 1 ]]; then
    return
  fi
  local spin=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
  printf '  %s ' "${msg}"
  while kill -0 "$pid" 2>/dev/null; do
    for s in "${spin[@]}"; do
      printf '%s' "$s"
      sleep 0.06
      printf '\b'
    done
  done
  printf '\r' && printf '  ' && printf '\r'
}

download_with_spinner() {
  local url=$1
  say "Fetching: ${url}"
  (curl --proto '=https' --tlsv1.2 -fsSL --retry 3 -o "$tmp" "$url") &
  local cpid=$!
  show_spinner "$cpid" "Downloading"
  wait "$cpid"
  return $?
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
${C}      .--.      ${N}
${C}     / _.-' .-""-._${N}
${C}    / /     /  🚀  \${N}
${C}   / /     /  .--.  \${N}
${C}  /_/     /__/____\__\${N}
  ${B}Flox — dev environments that travel with you${N}
  ${C}$(random_line "${POETRY[@]}")${N}
  ${Y}Hint: Brew, curl, or magic (not included).${N}

EOF

say "Channel: ${B}${CHANNEL}${N}"

# ────────────────────────────────────────
#  Setup & cleanup
# ────────────────────────────────────────
tmp=$(mktemp)
cleanup() { rm -f "$tmp"; }
trap cleanup EXIT INT TERM

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
      if curl -fsSL "${channel_url}/rpm/flox-archive-keyring.asc" | sudo rpm --import - 2>/dev/null; then
        success "GPG key imported"
      else
        warn "GPG key import skipped (common for nightly)"
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

    say "Fetching package from the ${CHANNEL} channel…"

    # Try architecture-specific package first, then generic
    pkg_found=false
    for pkg in "flox.${arch}-linux.${suffix}" "flox.${suffix}"; do
      url="${channel_url}/${suffix}/${pkg}"
      say "  Trying → ${pkg} (fingers crossed)"
      if download_with_spinner "$url"; then
        success "Found → ${pkg}"
        pkg_found=true
        break
      fi
      warn "${pkg} not available…"
    done

    [[ "$pkg_found" == true && -s "$tmp" ]] || cry "No usable package found in ${CHANNEL}."

    say "Installing (sudo will ask nicely)…"
    $install_cmd "$tmp" || cry "Package install failed — see error above."
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
  printf '\n'
  say "First steps:"
  printf '  %sflox init%s          # create your environment\n' "$C" "$N"
  printf '  %sflox install hello%s # add a classic\n' "$C" "$N"
  printf '  %sflox activate%s      # step inside\n' "$C" "$N"
  printf '  %shello%s              # "Hello, world!"\n' "$C" "$N"
  printf '\n'
  say "$(random_line "${POETRY[@]}")"
else
  warn "'flox' not found in PATH yet. Restart your shell or check the output above."
fi

printf '\n'