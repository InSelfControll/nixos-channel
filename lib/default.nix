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
