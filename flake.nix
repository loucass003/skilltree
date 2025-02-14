{
  description = "skilltree flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # eachDefaultSystem and other utility functions
    utils.url = "github:numtide/flake-utils";
    # Replacement for rustup
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, utils, fenix, }:
    # This helper function abstracts over the host platform.
    # See https://github.com/numtide/flake-utils#eachdefaultsystem--system---attrs
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          system = "${system}";
          config = {
            android_sdk.accept_license = true;
            allowUnfree = true;
          };
        };
        # Brings in the rust toolchain from the standard file
        # that rustup/cargo uses.
        rustToolchain = fenix.packages.${system}.fromToolchainFile {
          file = ./rust-toolchain.toml;
          sha256 = "sha256-rLP8+fTxnPHoR96ZJiCa/5Ans1OojI7MLsmSqR2ip8o=";
        };
        rustPlatform = pkgs.makeRustPlatform {
          inherit (rustToolchain) cargo rustc;
        };
      in
      # See https://nixos.wiki/wiki/Flakes#Output_schema
      {
        # `nix develop` pulls all of this in to become your shell.
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [
            rustToolchain
            pkgs.pkg-config

            # Common cargo tools we often use
            pkgs.cargo-deny
            pkgs.cargo-expand
            pkgs.cargo-binutils
            pkgs.cargo-apk
            # cmake for openxr
            pkgs.cmake
          ] ++ pkgs.lib.optionals (!pkgs.stdenv.isDarwin) (with pkgs; [
            androidenv.androidPkgs_9_0.androidsdk
          ]);

          # see https://github.com/NixOS/nixpkgs/blob/95b81c96f863ca8911dffcda45d1937efcd66a4b/pkgs/games/jumpy/default.nix#L60C5-L60C38
          buildInputs = [
            pkgs.zstd
            rustPlatform.bindgenHook
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux (with pkgs; [
            alsa-lib.dev
            libxkbcommon
            udev
            vulkan-loader
            wayland
            xorg.libX11
            xorg.libXcursor
            xorg.libXi
            xorg.libXrandr
            openxr-loader
          ]) ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.darwin.apple_sdk.frameworks.Cocoa
            # # This is missing on mac m1 nix, for some reason.
            # # see https://stackoverflow.com/a/69732679
            pkgs.libiconv
          ];
        };
        # This only formats the nix files.
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
