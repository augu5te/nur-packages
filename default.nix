# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage

{ pkgs ? import <nixpkgs> {} }:

rec {
  # The `lib`, `modules`, and `overlay` names are special
  lib = import ./lib { inherit pkgs; }; # functions
  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays

  glibc-batsky = pkgs.glibc.overrideAttrs (attrs: {
    patches = attrs.patches ++ [ ./pkgs/glibc-batsky/clock_gettime.patch
      ./pkgs/glibc-batsky/gettimeofday.patch ];
  });

  batsky = pkgs.callPackage ./pkgs/batsky { };

  slurm-multiple-slurmd = pkgs.slurm.overrideAttrs (oldAttrs: {configureFlags = oldAttrs.configureFlags ++ ["--enable-multiple-slurmd"];});

  bs-slurm = pkgs.replaceDependency {
    drv = slurm-multiple-slurmd;
    oldDependency = pkgs.glibc;
    newDependency = glibc-batsky;
  };
  
}

