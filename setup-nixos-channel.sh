#!/bin/bash
# setup-nixos-channel.sh - Create NixOS channel repository structure
# Tailored for existing package structure with update scripts

set -e

CHANNEL_NAME=${1:-"warp-channel"}
GITHUB_USER=${2:-"yourusername"}
REPO_NAME=${3:-"nixos-channel"}

echo "Setting up NixOS channel: $CHANNEL_NAME"
echo "GitHub: $GITHUB_USER/$REPO_NAME"

# Create comprehensive directory structure
mkdir -p .github/workflows
mkdir -p channel/store-paths
mkdir -p channel/nixexprs.tar.xz
mkdir -p cache/nar
mkdir -p cache/repodata
mkdir -p docs
mkdir -p pkgs/warp-terminal
mkdir -p modules
mkdir -p lib
mkdir -p scripts
# Move existing files to proper locations
if [ -f "package.nix" ]; then
    mv package.nix pkgs/warp-terminal/default.nix
    echo "✅ Moved package.nix to pkgs/warp-terminal/default.nix"
fi

if [ -f "versions.json" ]; then
    mv versions.json pkgs/warp-terminal/
    echo "✅ Moved versions.json to pkgs/warp-terminal/"
fi

if [ -f "update.sh" ]; then
    mv update.sh pkgs/warp-terminal/
    chmod +x pkgs/warp-terminal/update.sh
    echo "✅ Moved update.sh to pkgs/warp-terminal/"
fi

# Create top-level default.nix for the channel
cat > default.nix << 'EOL'
# Top-level packages for the channel
{ lib ? (import <nixpkgs> {}).lib
, newScope ? (import <nixpkgs> {}).newScope
, pkgs ? import <nixpkgs> {}
}:

let
  callPackage = newScope self;

  self = {
    # Warp Terminal
    warp-terminal = callPackage ./pkgs/warp-terminal {
      waylandSupport = true;
    };

    # Add more packages here as needed
    # example-package = callPackage ./pkgs/example-package {};
  };
in
self
EOL

# Create lib/default.nix for shared utilities
cat > lib/default.nix << 'EOL'
{ lib }:

{
  # Shared utilities for this channel
  # Example: version helpers, common build functions, etc.

  # Helper to check if a package needs updating
  needsUpdate = pkg: currentVersion: 
    pkg.version != currentVersion;

  # Helper to generate update scripts
  mkUpdateScript = path: script: {
    inherit path script;
  };
}
EOL

# Create GitHub Actions workflow for building and updating
cat > .github/workflows/build-and-deploy.yml << 'EOL'
name: Build and Deploy NixOS Channel

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
  schedule:
    # Check for updates daily at 6 AM UTC
    - cron: '0 6 * * *'
  workflow_dispatch:

jobs:
  update-packages:
    runs-on: ubuntu-latest
    outputs:
      updated: ${{ steps.check-updates.outputs.updated }}
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      with:
        token: ${{ secrets.GITHUB_TOKEN }}

    - name: Install Nix
      uses: cachix/install-nix-action@v27
      with:
        nix_path: nixpkgs=channel:nixos-unstable

    - name: Check for updates
      id: check-updates
      run: |
        cd pkgs/warp-terminal
        git config --global user.name "github-actions[bot]"
        git config --global user.email "github-actions[bot]@users.noreply.github.com"

        # Store original versions
        cp versions.json versions.json.orig

        # Run update script
        ./update.sh

        # Check if anything changed
        if ! cmp -s versions.json versions.json.orig; then
          echo "updated=true" >> $GITHUB_OUTPUT
          echo "📦 Updates found!"

          # Commit changes if on main branch and not PR
          if [[ "$GITHUB_REF" == "refs/heads/main" ]] && [[ "$GITHUB_EVENT_NAME" != "pull_request" ]]; then
            git add versions.json
            git commit -m "chore: update warp-terminal versions

            $(diff versions.json.orig versions.json || true)"
            git push
          fi
        else
          echo "updated=false" >> $GITHUB_OUTPUT
          echo "✅ No updates needed"
        fi

    - name: Test build after update
      if: steps.check-updates.outputs.updated == 'true'
      run: |
        nix-build -A warp-terminal

  build-channel:
    runs-on: ubuntu-latest
    needs: update-packages
    if: always()
    permissions:
      contents: read
      pages: write
      id-token: write

    steps:
    - name: Checkout
      uses: actions/checkout@v4
      with:
        # Get the latest commit if updates were made
        ref: ${{ github.ref }}

    - name: Install Nix
      uses: cachix/install-nix-action@v27
      with:
        nix_path: nixpkgs=channel:nixos-unstable

    - name: Build packages
      run: |
        echo "Building all packages..."
        nix-build -A warp-terminal -o result-warp-terminal

        # Test that packages work
        echo "Testing warp-terminal build..."
        if [ -L result-warp-terminal ]; then
          echo "✅ warp-terminal built successfully"
        else
          echo "❌ warp-terminal build failed"
          exit 1
        fi

    - name: Generate channel structure
      run: |
        ./scripts/generate-channel.sh

    - name: Generate documentation
      run: |
        ./scripts/generate-docs.sh

    - name: Setup Pages
      if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
      uses: actions/configure-pages@v4

    - name: Upload artifact
      if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
      uses: actions/upload-pages-artifact@v3
      with:
        path: ./public

  deploy:
    if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build-channel
    steps:
    - name: Deploy to GitHub Pages
      id: deployment
      uses: actions/deploy-pages@v4
EOL

# Create channel generation script
cat > scripts/generate-channel.sh << 'EOL'
#!/bin/bash

set -e

CHANNEL_DIR="public"
STORE_PATHS_FILE="$CHANNEL_DIR/store-paths"
CACHE_DIR="$CHANNEL_DIR"

echo "🔨 Generating NixOS channel structure..."

# Create output directory
mkdir -p "$CHANNEL_DIR"

# Create store-paths file
echo "📝 Creating store-paths file..."
echo "# Store paths for warp-terminal channel" > "$STORE_PATHS_FILE"

# Add all built packages
for result in result-*; do
  if [ -L "$result" ]; then
    echo "Processing $result..."
    nix-store --query --requisites "$result" >> "$STORE_PATHS_FILE"
  fi
done

# Sort and deduplicate store paths
sort -u "$STORE_PATHS_FILE" -o "$STORE_PATHS_FILE"

# Create nixexprs.tar.xz containing the channel expression
echo "📦 Creating nixexprs.tar.xz..."
tar -cJf "$CHANNEL_DIR/nixexprs.tar.xz"   --transform 's,^,nixpkgs/,'   --exclude='result*'   --exclude='.git*'   --exclude='public'   --exclude='cache'   --exclude='*.md'   default.nix pkgs/ lib/ modules/

# Generate binary cache
echo "🏗️  Generating binary cache..."
mkdir -p "$CACHE_DIR/nar"

# Create nix-cache-info
cat > "$CACHE_DIR/nix-cache-info" << 'EOF'
StoreDir: /nix/store
WantMassQuery: 1
Priority: 40
EOF

# Process each store path for binary cache
echo "Processing store paths for binary cache..."
processed=0
while IFS= read -r path; do
  # Skip comments and empty lines
  if [ -n "$path" ] && [ "${path#\#}" = "$path" ]; then
    echo "  Processing: $(basename "$path")"

    # Create compressed NAR
    nar_file="$CACHE_DIR/nar/$(basename "$path").nar"
    nix-store --export "$path" | xz > "$nar_file.xz"

    # Generate .narinfo file
    narinfo_file="$CACHE_DIR/$(basename "$path").narinfo"
    file_size=$(stat -c%s "$nar_file.xz")
    file_hash=$(nix-hash --flat --type sha256 "$nar_file.xz")
    nar_hash=$(nix-store --query --hash "$path" | cut -d: -f2)
    nar_size=$(nix-store --query --size "$path")
    references=$(nix-store --query --references "$path" | tr '
' ' ' | sed 's/ $//')

    cat > "$narinfo_file" << EOF
StorePath: $path
URL: nar/$(basename "$path").nar.xz
Compression: xz
FileHash: sha256:$file_hash
FileSize: $file_size
NarHash: sha256:$nar_hash
NarSize: $nar_size
References: $references
EOF
    ((processed++))
  fi
done < "$STORE_PATHS_FILE"

echo "✅ Processed $processed store paths"
echo "✅ Channel generation complete!"
echo "📂 Output directory: $CHANNEL_DIR"
EOL

chmod +x scripts/generate-channel.sh

# Create documentation generation script
cat > scripts/generate-docs.sh << 'EOL'
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
EOL

chmod +x scripts/generate-docs.sh

# Create Cloudflare Pages configuration
cat > _headers << 'EOL'
# Caching headers for Cloudflare Pages

/*
  Cache-Control: public, max-age=3600
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  X-XSS-Protection: 1; mode=block

/nar/*
  Cache-Control: public, max-age=31536000, immutable

/*.narinfo
  Cache-Control: public, max-age=3600

/nix-cache-info
  Cache-Control: public, max-age=3600

/nixexprs.tar.xz
  Cache-Control: public, max-age=3600

/store-paths
  Cache-Control: public, max-age=3600
  Content-Type: text/plain

# Documentation files
/docs/*
  Cache-Control: public, max-age=1800

# Main page
/index.html
  Cache-Control: public, max-age=1800
EOL

# Create redirects for Cloudflare Pages
cat > _redirects << 'EOL'
# Redirects for Cloudflare Pages

# Redirect root requests to index.html
/  /index.html  200

# Channel-specific redirects
/channel/*  /:splat  301
EOL

# Create comprehensive README
cat > README.md << EOL
# $CHANNEL_NAME

A custom NixOS channel providing the Warp terminal with automatic updates.

## 🚀 Quick Start

\`\`\`bash
# Add the channel
sudo nix-channel --add https://$GITHUB_USER.github.io/$REPO_NAME $CHANNEL_NAME
sudo nix-channel --update

# Install Warp terminal
nix-env -iA $CHANNEL_NAME.warp-terminal
\`\`\`

## 📦 Available Packages

- **warp-terminal** - Fast, modern terminal with AI features

## 🏗️ Repository Structure

\`\`\`
├── pkgs/
│   └── warp-terminal/          # Warp terminal package
│       ├── default.nix         # Package definition
│       ├── versions.json       # Version tracking
│       └── update.sh          # Auto-update script
├── lib/                       # Shared utilities
├── modules/                   # NixOS modules
├── scripts/
│   ├── generate-channel.sh    # Channel generation
│   └── generate-docs.sh       # Documentation generation
├── .github/workflows/         # CI/CD automation
└── public/                    # Generated channel files
\`\`\`

## 🔄 Automatic Updates

This channel automatically:
- Checks for new Warp terminal releases daily
- Builds and tests packages
- Updates the binary cache
- Deploys to GitHub Pages and Cloudflare Pages

## 🏗️ Binary Cache

Speed up installations by adding our binary cache:

\`\`\`nix
nix.settings.substituters = [
  "https://$GITHUB_USER.github.io/$REPO_NAME"
];
\`\`\`

## 🔧 Development

### Building Locally

\`\`\`bash
# Build all packages
nix-build -A warp-terminal

# Generate channel
./scripts/generate-channel.sh
\`\`\`

### Adding Packages

1. Create a new directory in \`pkgs/\`
2. Add the package to \`default.nix\`
3. Update GitHub Actions workflow if needed

### Updating Packages

The \`update.sh\` scripts run automatically, but you can trigger manually:

\`\`\`bash
cd pkgs/warp-terminal
./update.sh
\`\`\`

## 📖 Documentation

- [Package Documentation](https://your-site.pages.dev/docs/packages.html)
- [Usage Examples](https://your-site.pages.dev/)

## 🤝 Contributing

1. Fork this repository
2. Create a feature branch
3. Make your changes
4. Test locally
5. Submit a pull request

## 📄 License

This channel configuration is MIT licensed. Individual packages may have different licenses.

## 🐛 Issues

Report issues at: https://github.com/$GITHUB_USER/$REPO_NAME/issues
EOL

# Create .gitignore
cat > .gitignore << 'EOL'
# Build outputs
result*
.direnv/

# Generated files
public/
cache/

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# Temporary files
*.tmp
*.log
EOL

# Create GitHub issue templates
mkdir -p .github/ISSUE_TEMPLATE

cat > .github/ISSUE_TEMPLATE/bug_report.md << 'EOL'
---
name: Bug report
about: Create a report to help us improve
title: '[BUG] '
labels: 'bug'
assignees: ''
---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Run command '...'
2. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Environment:**
- NixOS version: [e.g. 23.11]
- Channel version: [e.g. latest]
- Architecture: [e.g. x86_64-linux]

**Additional context**
Add any other context about the problem here.
EOL

cat > .github/ISSUE_TEMPLATE/package_request.md << 'EOL'
---
name: Package request
about: Request a new package to be added to the channel
title: '[REQUEST] '
labels: 'enhancement'
assignees: ''
---

**Package name**
Name of the package you'd like to see added.

**Package description**
What does this package do?

**Homepage/Repository**
Link to the official homepage or source repository.

**Why should this be included?**
Explain why this package would be valuable in this channel.

**Additional context**
Any other information about the package.
EOL

echo "✅ NixOS channel repository structure created!"
echo ""
echo "📁 Directory structure:"
echo "   ├── pkgs/warp-terminal/     (your existing package)"
echo "   ├── .github/workflows/     (CI/CD automation)"
echo "   ├── scripts/               (build scripts)"
echo "   └── public/                (generated channel files)"
echo ""
echo "🚀 Next steps:"
echo "1. Initialize git repository:"
echo "   git init"
echo "   git add ."
echo "   git commit -m "Initial channel setup""
echo ""
echo "2. Create GitHub repository and push:"
echo "   git remote add origin https://github.com/$GITHUB_USER/$REPO_NAME.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. Set up GitHub Pages:"
echo "   - Go to repository Settings > Pages"
echo "   - Source: GitHub Actions"
echo ""
echo "4. Set up Cloudflare Pages:"
echo "   - Connect your GitHub repository"
echo "   - Build command: ./scripts/generate-channel.sh && ./scripts/generate-docs.sh"
echo "   - Output directory: public"
echo ""
echo "5. Enable GitHub Actions:"
echo "   - Actions will run automatically on push"
echo "   - Daily updates will check for new Warp versions"
echo ""
echo "🌐 Your channel will be available at:"
echo "   - GitHub Pages: https://$GITHUB_USER.github.io/$REPO_NAME"
echo "   - Cloudflare Pages: https://your-project.pages.dev"
