#!/usr/bin/env bash
#
#    Flox — reproducible environments that travel with you
#    curl -fsSL https://get.flox.dev | bash
#    curl -fsSL https://get.flox.dev | bash -s -- --nightly   (send coffee)
#

set -euo pipefail

# ────────────────────────────────────────
#  Colors & poetry
# ────────────────────────────────────────
C=$(tput setaf 6 2>/dev/null || printf '\033[36m')   # calm cyan
G=$(tput setaf 2 2>/dev/null || printf '\033[32m')   # success green
Y=$(tput setaf 3 2>/dev/null || printf '\033[33m')   # warn yellow
R=$(tput setaf 1 2>/dev/null || printf '\033[31m')   # error red
B=$(tput bold 2>/dev/null || printf '\033[1m')
N=$(tput sgr0 2>/dev/null || printf '\033[0m')

STABLE_POETRY=(
  "Because 'works on my machine' should work on ALL machines. Yes, even Jenkins."
  "Dependencies that don't require a PhD in YAML archaeology."
  "It's like Docker, but your laptop battery doesn't burst into flames."
  "Finally, an environment that survives the 'npm install' boss fight."
  "Your dotfiles, but they actually work when you switch laptops at 2 AM."
  "No more 'let me share my screen' during onboarding. Just... flox activate."
  "Kubernetes at home? Nah. This? This sparks joy."
)

NIGHTLY_POETRY=(
  "Nightly builds: for when 'stable' sounds too much like your relationships."
  "YOLO-driven development. We merge to main and pray."
  "Fresh code, hot off the CI/CD pipeline — unit tests TBD."
  "Production is just nightly with more users, change my mind."
  "Warning: May cause random Slack pings at 3 AM. Worth it."
  "If it compiles, we ship it. That's the nightly way."
  "Bug fixes from the future, bugs from the present. Perfectly balanced."
)

say()       { echo -e "${C}$*${N}"; }
success()   { echo -e "${G}✓ $*${N}"; }
warn()      { echo -e "${Y}⚠ $*${N}"; }
cry()       { echo -e "${R}✗ $*${N}"; exit 1; }

random_line() {
  local arr=("$@")
  echo "${arr[$((RANDOM % ${#arr[@]}))]}"
}

# ────────────────────────────────────────
#  Channel & poetry switch
# ────────────────────────────────────────
CHANNEL="stable"
[[ " $* " =~ " --nightly " || "${FLOX_CHANNEL:-}" = nightly ]] && CHANNEL="nightly"

if [[ $CHANNEL = nightly ]]; then
  POETRY=("${NIGHTLY_POETRY[@]}")
else
  POETRY=("${STABLE_POETRY[@]}")
fi

clear 2>/dev/null || true

cat << EOF
${C}┌────────────────────────────────────────────┐${N}
  ${B}Flox${N} — dev environments that travel with you
  ${C}$(random_line "${POETRY[@]}")${N}
${C}└────────────────────────────────────────────┘${N}

EOF

say "Channel: ${B}$CHANNEL${N}"

tmp=$(mktemp) && trap 'rm -f "$tmp"' EXIT

case "$(uname -s | tr 'A-Z' 'a-z')" in
  darwin)
    if ! command -v brew >/dev/null; then
      warn "Homebrew not found — inviting it over…"
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        || cry "Homebrew setup didn't finish. See https://brew.sh"

      [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
      [[ -x /usr/local/bin/brew  ]]   && eval "$(/usr/local/bin/brew shellenv)"
      command -v brew >/dev/null || cry "Still no brew — manual time."
    fi

    say "Installing Flox the cozy Homebrew way…"
    brew install flox || cry "brew install flox hit a snag — check above."
    ;;

  linux)
    base="https://downloads.flox.dev/by-env/$CHANNEL"

    if [[ -f /etc/debian_version ]]; then
      family=debian
      suffix=deb
      install_cmd="sudo apt install -y"
    elif [[ -f /etc/redhat-release || -x "$(command -v dnf || command -v yum)" ]]; then
      family=rpm
      suffix=rpm
      install_cmd="sudo rpm -ivh"
      curl -fsSL "${base}/rpm/flox-archive-keyring.asc" | sudo rpm --import - 2>/dev/null || \
        warn "Key import skipped (common for nightly)"
    else
      family=unknown
    fi

    if [[ $family = unknown ]]; then
      cry "Automatic install not supported on this distro yet.

Quick manual steps:
  macOS           →  brew install flox
  Debian/Ubuntu   →  curl -LO ${base}/deb/flox.deb && sudo apt install ./flox.deb
  RPM family      →  curl -LO ${base}/rpm/flox.rpm && sudo rpm -ivh ./flox.rpm
  Nix             →  nix profile install github:flox/flox/latest
"
    fi

    say "Fetching package from the $CHANNEL channel…"

    arch=$(uname -m)
    [[ $arch = arm64 ]] && arch=aarch64

    for pkg in "flox.${arch}-linux.${suffix}" "flox.${suffix}"; do
      url="${base}/${suffix}/${pkg}"
      say "  Trying → $pkg"
      if curl --proto '=https' --tlsv1.2 -fsSL --retry 3 -o "$tmp" "$url" 2>/dev/null; then
        success "Found → $pkg"
        break
      fi
      warn "$pkg not available…"
    done

    [[ -s "$tmp" ]] || cry "No usable package found in $CHANNEL."

    say "Installing (sudo will ask nicely)…"
    $install_cmd "$tmp" || cry "Package install failed — see error above."
    ;;

  *)
    cry "This OS isn't covered by auto-install yet.

Manual options:
  brew install flox                 # macOS
  curl -LO ${base}/deb/flox.deb     && sudo apt install ./flox.deb
  curl -LO ${base}/rpm/flox.rpm     && sudo rpm -ivh ./flox.rpm
  nix profile install github:flox/flox/latest
"
    ;;
esac

# ────────────────────────────────────────
#  Victory lap
# ────────────────────────────────────────
if command -v flox >/dev/null; then
  success "Flox is ready!"
  flox --version | sed 's/^/  /'
  echo ""
  say "First steps:"
  echo "  ${C}flox init${N}          # create your environment"
  echo "  ${C}flox install hello${N} # add a classic"
  echo "  ${C}flox activate${N}      # step inside"
  echo ""
  say "$(random_line "${POETRY[@]}")"
else
  warn "'flox' not found in PATH yet. Restart shell or check output."
fi

echo ""