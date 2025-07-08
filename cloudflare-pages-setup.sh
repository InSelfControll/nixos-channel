#!/bin/bash
set -e

echo "🚀 Setting up NixOS Channel for Cloudflare Pages..."

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p nixos-channel/store-paths
mkdir -p nixos-channel/binary-cache
mkdir -p nixos-channel/metadata
mkdir -p functions
mkdir -p .github/workflows

# Move existing files to appropriate locations
echo "📦 Moving existing files..."
if [ -f "package.nix" ]; then
    mv package.nix nixos-channel/
    echo "✅ Moved package.nix"
fi

if [ -f "versions.json" ]; then
    mv versions.json nixos-channel/metadata/
    echo "✅ Moved versions.json"
fi

if [ -f "update.sh" ]; then
    mv update.sh nixos-channel/
    chmod +x nixos-channel/update.sh
    echo "✅ Moved update.sh"
fi

# Create Cloudflare Pages configuration files
echo "⚙️ Creating Cloudflare Pages configuration..."

# Create _headers file for caching
cat > _headers << 'EOF'
# Cache store paths for longer
/store-paths/*
  Cache-Control: public, max-age=3600, s-maxage=86400
  X-Content-Type-Options: nosniff

# Cache binary cache files
/binary-cache/*
  Cache-Control: public, max-age=86400, s-maxage=604800
  X-Content-Type-Options: nosniff

# Cache metadata
/metadata/*
  Cache-Control: public, max-age=300, s-maxage=3600
  X-Content-Type-Options: nosniff

# Root channel file
/nixos-channel
  Cache-Control: public, max-age=300, s-maxage=1800
  Content-Type: text/plain
EOF

# Create _redirects file
cat > _redirects << 'EOF'
# Redirect root to channel info
/  /nixos-channel  200
/channel  /nixos-channel  200
EOF

# Create middleware for advanced request handling
cat > functions/_middleware.js << 'EOF'
export async function onRequest(context) {
  const { request, env } = context;
  const url = new URL(request.url);

  // Add CORS headers for API requests
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  // Handle OPTIONS requests
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  // Continue with the request
  const response = await context.next();

  // Add CORS headers to response
  Object.entries(corsHeaders).forEach(([key, value]) => {
    response.headers.set(key, value);
  });

  return response;
}
EOF

# Create GitHub Actions workflow
cat > .github/workflows/build-and-deploy.yml << 'EOF'
name: Build and Deploy NixOS Channel

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 */6 * * *'  # Run every 6 hours

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Install Nix
      uses: cachix/install-nix-action@v22
      with:
        nix_path: nixpkgs=channel:nixos-unstable

    - name: Setup Cachix
      uses: cachix/cachix-action@v12
      with:
        name: your-cache-name
        authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'

    - name: Update packages
      run: |
        cd nixos-channel
        if [ -f update.sh ]; then
          chmod +x update.sh
          ./update.sh
        fi

    - name: Build packages
      run: |
        cd nixos-channel
        if [ -f package.nix ]; then
          nix-build package.nix
        fi

    - name: Generate store paths
      run: |
        cd nixos-channel
        # Generate store paths list
        find /nix/store -maxdepth 1 -type d -name "*" | sort > store-paths/store-paths.txt

        # Generate binary cache info
        echo "StoreDir: /nix/store" > binary-cache/nix-cache-info
        echo "WantMassQuery: 1" >> binary-cache/nix-cache-info
        echo "Priority: 30" >> binary-cache/nix-cache-info

    - name: Create channel manifest
      run: |
        cd nixos-channel
        # Create main channel file
        cat > nixos-channel << EOF2
        # NixOS Channel
        # Generated: $(date)
        # Store paths: $(wc -l < store-paths/store-paths.txt)

        This is a NixOS channel repository.

        Available endpoints:
        - /store-paths/ - Store path listings
        - /binary-cache/ - Binary cache files
        - /metadata/ - Package metadata
        EOF2

    - name: Deploy to Cloudflare Pages
      run: |
        echo "Files ready for Cloudflare Pages deployment"
        ls -la
EOF

# Create package.json for Cloudflare Pages
cat > package.json << 'EOF'
{
  "name": "nixos-channel",
  "version": "1.0.0",
  "description": "NixOS Channel for Cloudflare Pages",
  "main": "index.js",
  "scripts": {
    "build": "echo 'Build completed'",
    "dev": "echo 'Development server'"
  },
  "keywords": ["nixos", "nix", "channel"],
  "author": "",
  "license": "MIT"
}
EOF

# Create wrangler.toml for Cloudflare configuration
cat > wrangler.toml << 'EOF'
name = "nixos-channel"
compatibility_date = "2023-10-30"

[env.production]
zone_id = "your-zone-id"
account_id = "your-account-id"

[[env.production.routes]]
pattern = "your-domain.com/*"
zone_id = "your-zone-id"
EOF

# Create README
cat > README.md << 'EOF'
# NixOS Channel for Cloudflare Pages

This repository contains a NixOS channel that's deployed on Cloudflare Pages.

## Structure

```
├── nixos-channel/           # Main channel directory
│   ├── store-paths/        # Store path listings
│   ├── binary-cache/       # Binary cache files
│   ├── metadata/           # Package metadata
│   ├── package.nix         # Package definitions
│   └── update.sh           # Update script
├── functions/              # Cloudflare Pages functions
├── .github/workflows/      # GitHub Actions
├── _headers               # Caching headers
├── _redirects            # URL redirects
└── wrangler.toml         # Cloudflare configuration
```

## Setup Instructions

1. **Fork this repository**
2. **Configure Cloudflare Pages**:
   - Go to Cloudflare Dashboard → Pages
   - Create a new project
   - Connect your GitHub repository
   - Set build command: `npm run build`
   - Set build output directory: `/`

3. **Set up GitHub Secrets**:
   - `CACHIX_AUTH_TOKEN`: Your Cachix authentication token
   - `CLOUDFLARE_API_TOKEN`: Your Cloudflare API token

4. **Configure wrangler.toml**:
   - Update `zone_id` and `account_id` with your values
   - Update domain patterns

## Usage

The channel will be available at your Cloudflare Pages URL:
- Main channel: `https://your-site.pages.dev/nixos-channel`
- Store paths: `https://your-site.pages.dev/store-paths/`
- Binary cache: `https://your-site.pages.dev/binary-cache/`

## Adding to NixOS Configuration

Add this to your NixOS configuration:

```nix
{
  nix.binaryCaches = [
    "https://cache.nixos.org"
    "https://your-site.pages.dev/binary-cache"
  ];

  nix.binaryCachePublicKeys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    # Add your public key here
  ];
}
```

## Automatic Updates

The channel updates automatically every 6 hours via GitHub Actions.
You can also trigger manual updates by pushing to the main branch.

## Development

To run locally:
```bash
# Update packages
cd nixos-channel && ./update.sh

# Build packages
nix-build nixos-channel/package.nix
```
EOF

echo "✅ Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Push this repository to GitHub"
echo "2. Configure Cloudflare Pages:"
echo "   - Go to Cloudflare Dashboard → Pages"
echo "   - Create new project from GitHub"
echo "   - Set build command: npm run build"
echo "   - Set build output directory: /"
echo "3. Set up GitHub secrets:"
echo "   - CACHIX_AUTH_TOKEN"
echo "   - CLOUDFLARE_API_TOKEN"
echo "4. Update wrangler.toml with your zone_id and account_id"
echo ""
echo "🎉 Your NixOS channel will be live at: https://your-site.pages.dev"
