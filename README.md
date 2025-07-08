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
