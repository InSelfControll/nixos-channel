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
