# 📥 get-flox

[![Downloads](https://img.shields.io/github/downloads/noor-latif/get-flox/total?label=downloads&color=blue)](https://github.com/noor-latif/get-flox/releases)
[![Ubuntu](https://github.com/noor-latif/get-flox/actions/workflows/test-ubuntu.yml/badge.svg)](https://github.com/noor-latif/get-flox/actions/workflows/test-ubuntu.yml)
[![Debian](https://github.com/noor-latif/get-flox/actions/workflows/test-debian.yml/badge.svg)](https://github.com/noor-latif/get-flox/actions/workflows/test-debian.yml)
[![Fedora](https://github.com/noor-latif/get-flox/actions/workflows/test-fedora.yml/badge.svg)](https://github.com/noor-latif/get-flox/actions/workflows/test-fedora.yml)
[![Amazon Linux](https://github.com/noor-latif/get-flox/actions/workflows/test-amazonlinux.yml/badge.svg)](https://github.com/noor-latif/get-flox/actions/workflows/test-amazonlinux.yml)
[![macOS](https://github.com/noor-latif/get-flox/actions/workflows/test-macos.yml/badge.svg)](https://github.com/noor-latif/get-flox/actions/workflows/test-macos.yml)
[![NixOS](https://github.com/noor-latif/get-flox/actions/workflows/test-nixos.yml/badge.svg)](https://github.com/noor-latif/get-flox/actions/workflows/test-nixos.yml)
[![macOS + Nix](https://github.com/noor-latif/get-flox/actions/workflows/test-macos-nix.yml/badge.svg)](https://github.com/noor-latif/get-flox/actions/workflows/test-macos-nix.yml)

A polished, one-liner installer for [Flox](https://flox.dev) — the tool for reproducible development environments.

Built to solve [floxdocs#409](https://github.com/flox/floxdocs/issues/409), this script provides a unified installation experience across multiple platforms and package managers.

## 🚀 Quick Start

To install Flox, run the following command in your terminal:

```bash
curl -sSfL https://github.com/noor-latif/get-flox/releases/download/latest/install.sh | bash
```

## ✨ Features

- **Platform-Agnostic**: Automatically detects your OS and architecture (x86_64, aarch64).
- **Package Manager Aware**: 
  - **macOS**: Installs via Homebrew (installs Homebrew first if missing).
  - **Linux (Debian/Ubuntu)**: Installs via `.deb` package using `apt`.
  - **Linux (RHEL/Fedora/CentOS)**: Installs via `.rpm` package using `dnf` or `yum`.
  - **Nix Support**: If Nix is detected, it uses `nix profile install` and configures Flox substituters.
- **Robust**: Includes retries for downloads and handles dependency resolution for Linux packages.
- **Polished UX**: Provides a clean, colorful interface and helpful "next steps" after installation.

## 📋 Supported Platforms

Verified via CI on:

| OS | Architectures | Method |
| :--- | :--- | :--- |
| **macOS** 14, 15 | Intel, Apple Silicon | Homebrew |
| **Ubuntu** 22.04, 24.04 | x86_64, aarch64 | APT (.deb) |
| **Debian** 12 | x86_64 | APT (.deb) |
| **Fedora** | x86_64, aarch64 | DNF (.rpm) |
| **Amazon Linux** | x86_64 | YUM (.rpm) |
| **NixOS / Generic Nix** | x86_64, aarch64 | Nix Profile |

## 🛠️ How it Works

The script performs the following steps:
1. **Environment Detection**: Checks for OS, CPU architecture, and existing package managers (Nix, Homebrew, etc.).
2. **Setup**: Configures necessary binary caches (substituters) if installing via Nix.
3. **Installation**:
   - On **macOS**, it ensures Homebrew is installed before running `brew install flox`.
   - On **Linux**, it downloads the appropriate package for your architecture and installs it using the native package manager.
   - On **Nix** environments, it adds Flox to the user or system profile.
4. **Verification**: Confirms the installation was successful and provides a quick start guide.

## 🤝 Contributing

Contributions are welcome! If you encounter any issues or want to add support for a new platform, feel free to open an issue or submit a pull request.

## Known Limitations

- **Re-installation on systems with existing Flox**: If Flox is already installed, the script may incorrectly select the Nix installation method, resulting in a non-critical error. This does not break your existing Flox installation.

