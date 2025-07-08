#!/bin/bash

set -e

PUBLIC_DIR="public"
DOCS_DIR="$PUBLIC_DIR/docs"

echo "📚 Generating documentation..."

mkdir -p "$DOCS_DIR"

# Generate main index.html
cat > "$PUBLIC_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Warp Terminal NixOS Channel</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        .header { background: #1a1a1a; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .code { background: #f5f5f5; padding: 15px; border-radius: 4px; font-family: monospace; overflow-x: auto; }
        .section { margin: 20px 0; }
        h1, h2, h3 { color: #333; }
        .version { color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Warp Terminal NixOS Channel</h1>
        <p>Fast, modern terminal with AI features - packaged for NixOS</p>
    </div>

    <div class="section">
        <h2>📦 Installation</h2>
        <p>Add this channel to your NixOS configuration:</p>
        <div class="code">
# Add the channel<br>
sudo nix-channel --add https://$GITHUB_USER.github.io/$REPO_NAME warp-channel<br>
sudo nix-channel --update<br><br>
# Install warp-terminal<br>
nix-env -iA warp-channel.warp-terminal
        </div>
    </div>

    <div class="section">
        <h2>🏗️ NixOS Configuration</h2>
        <p>Add to your <code>configuration.nix</code>:</p>
        <div class="code">
{ config, pkgs, ... }:<br><br>
{<br>
&nbsp;&nbsp;environment.systemPackages = with pkgs; [<br>
&nbsp;&nbsp;&nbsp;&nbsp;warp-channel.warp-terminal<br>
&nbsp;&nbsp;];<br><br>
&nbsp;&nbsp;# Optional: Enable Wayland support<br>
&nbsp;&nbsp;programs.warp-terminal = {<br>
&nbsp;&nbsp;&nbsp;&nbsp;enable = true;<br>
&nbsp;&nbsp;&nbsp;&nbsp;waylandSupport = true;<br>
&nbsp;&nbsp;};<br>
}
        </div>
    </div>

    <div class="section">
        <h2>🚀 Binary Cache</h2>
        <p>Speed up installations by using our binary cache:</p>
        <div class="code">
nix.settings.substituters = [<br>
&nbsp;&nbsp;"https://$GITHUB_USER.github.io/$REPO_NAME"<br>
];<br>
nix.settings.trusted-public-keys = [<br>
&nbsp;&nbsp;# Add your signing key here<br>
];
        </div>
    </div>

    <div class="section">
        <h2>📋 Available Packages</h2>
        <ul>
            <li><strong>warp-terminal</strong> - The Warp terminal application</li>
        </ul>
    </div>

    <div class="section">
        <h2>🔄 Updates</h2>
        <p>This channel is automatically updated daily. Packages are built and tested on every update.</p>
        <p class="version">Last updated: $(date)</p>
    </div>

    <div class="section">
        <h2>📖 Documentation</h2>
        <ul>
            <li><a href="/docs/packages.html">Package Documentation</a></li>
            <li><a href="/store-paths">Store Paths</a></li>
            <li><a href="/nix-cache-info">Cache Info</a></li>
        </ul>
    </div>

    <div class="section">
        <h2>🐛 Issues & Contributions</h2>
        <p>Report issues or contribute at: <a href="https://github.com/$GITHUB_USER/$REPO_NAME">GitHub Repository</a></p>
    </div>
</body>
</html>
EOF

# Generate package documentation
cat > "$DOCS_DIR/packages.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Package Documentation - Warp Terminal Channel</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        .package { border: 1px solid #ddd; border-radius: 8px; padding: 15px; margin: 15px 0; }
        .package h3 { margin-top: 0; color: #2563eb; }
        .meta { background: #f8f9fa; padding: 10px; border-radius: 4px; font-size: 0.9em; }
        .code { background: #f5f5f5; padding: 10px; border-radius: 4px; font-family: monospace; }
    </style>
</head>
<body>
    <h1>📦 Package Documentation</h1>

    <div class="package">
        <h3>warp-terminal</h3>
        <p><strong>Description:</strong> Rust-based terminal with AI features</p>
        <p><strong>Homepage:</strong> <a href="https://www.warp.dev">https://www.warp.dev</a></p>
        <p><strong>License:</strong> Unfree</p>

        <div class="meta">
            <strong>Platforms:</strong> x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin<br>
            <strong>Maintainers:</strong> Channel maintainers<br>
            <strong>Auto-updates:</strong> ✅ Daily version checks
        </div>

        <h4>Installation:</h4>
        <div class="code">nix-env -iA warp-channel.warp-terminal</div>

        <h4>Options:</h4>
        <ul>
            <li><code>waylandSupport</code> - Enable Wayland support (default: false)</li>
        </ul>
    </div>

    <p><a href="/">← Back to main page</a></p>
</body>
</html>
EOF

echo "✅ Documentation generated!"
