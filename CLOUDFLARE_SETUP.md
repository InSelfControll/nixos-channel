# 🌐 NixOS Channel on Cloudflare Pages Setup Guide

This guide will help you set up a complete NixOS channel with binary cache on Cloudflare Pages.

## 🚀 Quick Setup

1. **Run the setup script:**
   ```bash
   chmod +x cloudflare-pages-setup.sh
   ./cloudflare-pages-setup.sh
   ```

2. **Move your existing files:**
   ```bash
   # Move your existing package files
   mkdir -p pkgs/warp-terminal
   mv package.nix pkgs/warp-terminal/default.nix
   mv versions.json pkgs/warp-terminal/
   mv update.sh pkgs/warp-terminal/
   chmod +x pkgs/warp-terminal/update.sh
   ```

3. **Create top-level default.nix:**
   ```nix
   { pkgs ? import <nixpkgs> {} }:

   {
     warp-terminal = pkgs.callPackage ./pkgs/warp-terminal {
       waylandSupport = true;
     };
   }
   ```

## 🔧 Cloudflare Pages Configuration

### 1. Create Cloudflare Pages Project

1. Go to [Cloudflare Pages](https://pages.cloudflare.com/)
2. Connect your GitHub repository  
3. Set build configuration:
   - **Framework preset:** None
   - **Build command:** `./build.sh`
   - **Output directory:** `public`
   - **Node.js version:** `18`

### 2. Set Environment Variables

In your Cloudflare Pages project settings, add:

```
NODE_VERSION=18
NIX_CONFIG=experimental-features = nix-command flakes
```

### 3. Configure GitHub Secrets

Add these secrets to your GitHub repository:

- `CLOUDFLARE_API_TOKEN` - Your Cloudflare API token with Pages:Edit permissions
- `CLOUDFLARE_ACCOUNT_ID` - Your Cloudflare account ID  
- `CLOUDFLARE_PROJECT_NAME` - Your Pages project name
- `CACHIX_AUTH_TOKEN` (optional) - For Cachix binary cache
- `CACHIX_CACHE_NAME` (optional) - Your Cachix cache name

## 📦 Key Features

### ✅ What You Get

- **🚀 Automatic builds** on every push
- **⏰ Daily update checks** for new package versions  
- **📦 Binary cache** with XZ compression for optimal performance
- **🌐 CDN distribution** via Cloudflare's global network
- **⚡ Optimized caching** headers for maximum performance
- **🎯 Web interface** with usage instructions and statistics
- **🔄 GitHub Actions CI/CD** fully automated pipeline
- **🛡️ Cloudflare Functions** for advanced request handling

### 🏗️ Architecture

```
GitHub Repo → GitHub Actions → Build Channel → Deploy to Cloudflare Pages
     ↓              ↓                ↓                    ↓
Package Sources → Nix Build → Binary Cache → Global CDN
```

## 🌐 Performance Optimizations

Based on [Cloudflare's cache configuration](https://developers.cloudflare.com/cache/how-to/), this setup includes:

- **XZ compression** for NAR files (better compression than gzip)
- **Immutable caching** for binary cache files (1 year TTL)
- **Proper MIME types** for all Nix-related files
- **HTTP/2 and HTTP/3** support automatically
- **Brotli compression** for text files
- **Edge caching** globally distributed

## 🚀 Usage Examples

Once deployed, users can:

### Add Your Channel
```bash
# Add the channel
sudo nix-channel --add https://your-project.pages.dev my-channel
sudo nix-channel --update

# Install packages
nix-env -iA my-channel.warp-terminal
```

### Use as Binary Cache
```bash
# Temporary usage
nix-build --substituters https://your-project.pages.dev

# Permanent configuration in /etc/nix/nix.conf
extra-substituters = https://your-project.pages.dev
extra-trusted-public-keys = your-key-here
```

### NixOS Configuration
```nix
{ config, pkgs, ... }:

{
  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://your-project.pages.dev"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "your-signing-key-here"
    ];
  };
}
```

## 🔄 Automatic Updates

The system automatically:
- **Daily checks** for package updates at 6 AM UTC
- **Rebuilds packages** when updates are found
- **Commits changes** back to the repository
- **Deploys new versions** to Cloudflare Pages
- **Updates binary cache** with new packages

## 🛠️ Troubleshooting

### Build Failures
- Check GitHub Actions logs for detailed error messages
- Verify Nix expressions are syntactically valid
- Ensure all dependencies are available in Nixpkgs

### Cache Issues  
- Verify `_headers` file is properly configured
- Check Cloudflare cache settings in dashboard
- Confirm file permissions and content types

### Performance Issues
- Monitor Cloudflare Analytics for cache hit ratios
- Check file sizes and compression effectiveness
- Optimize packages for smaller closure sizes

## 📊 Monitoring & Analytics

Your channel includes:
- **Build status** tracking in GitHub Actions
- **Performance metrics** in Cloudflare Analytics  
- **Cache hit ratios** and bandwidth usage
- **Error tracking** via Cloudflare logs
- **Real User Monitoring** for end-user experience

## 🔒 Security Features

- **Content Security Policy** headers
- **XSS protection** enabled
- **Frame options** to prevent clickjacking
- **Secure transport** enforced (HTTPS only)
- **Referrer policy** configured

## 🎯 Best Practices

1. **Keep packages small** - Minimize closure sizes
2. **Use proper versioning** - Tag releases appropriately  
3. **Monitor cache usage** - Track bandwidth and storage
4. **Test builds locally** - Verify before pushing
5. **Document packages** - Provide clear usage instructions

Ready to deploy your NixOS channel to Cloudflare Pages! 🚀

## 📞 Support

- **GitHub Issues** - Report bugs and feature requests
- **NixOS Discourse** - Community support and discussions
- **Cloudflare Community** - Platform-specific questions
