# Tools for Claude Code in the VM. Debian gives the base system (git, curl,
# python3, gcc from build-essential); Nix gives the rest.
#
# Edit this file on the host (claude-vm/home/home.nix in your dots), then run
# ./provision.sh again. Inside the VM, Claude can also use "nix shell
# nixpkgs#name" for a tool it needs only once.
{ pkgs, ... }:
{
  home.username = "dev";
  home.homeDirectory = "/home/dev";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # No targets.genericLinux here: the VM has no desktop, and in 26.05 that
  # option also turns on GPU driver setup, which wants a sudo script.

  home.packages = with pkgs; [
    fd
    tree
    file
    unzip
    zip
    shellcheck
    uv
    nodejs
    gnumake
    htop
  ];
}
