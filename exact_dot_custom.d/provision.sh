#!/bin/bash

provision_mise() {
  curl https://mise.run | sh
}

provision_node() {
  command_exists mise || provision_mise
  mise use --global node
}

provision_python() {
  command_exists mise || provision_mise
  mise use --global python
}

# {{{ Provision Zig
provision_zig() {
  (
    set -e

    ZIG_VERSION="0.12.0"
    ZIG_HOME="$HOME/.local/share/zig"
    BIN_DIR="$HOME/.local/bin"

    mkdir -p "$ZIG_HOME"
    mkdir -p "$BIN_DIR"

    case "$(uname -s)" in
    Linux)
      OS="linux"
      ;;
    Darwin)
      OS="macos"
      ;;
    *)
      echo "Unsupported OS: $(uname -s)"
      exit 1
      ;;
    esac

    case "$(uname -m)" in
    x86_64)
      ARCH="x86_64"
      ;;
    aarch64 | arm64)
      ARCH="aarch64"
      ;;
    *)
      echo "Unsupported architecture: $(uname -m)"
      exit 1
      ;;
    esac

    FILENAME="zig-$OS-$ARCH-$ZIG_VERSION.tar.xz"
    DOWNLOAD_URL="https://ziglang.org/download/$ZIG_VERSION/$FILENAME"

    echo "Installing Zig $ZIG_VERSION for $OS-$ARCH to $ZIG_HOME..."
    echo
    curl -L "$DOWNLOAD_URL" | tar -xJ -C "$ZIG_HOME" --strip-components=1

    chmod +x "$ZIG_HOME/zig"
    ln -sf "$ZIG_HOME/zig" "$BIN_DIR/zig"
  )
}
# }}}

provision_all() {
  provision_mise
  provision_node
  provision_python
  provision_zig
}
