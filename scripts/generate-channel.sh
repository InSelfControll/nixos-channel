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
