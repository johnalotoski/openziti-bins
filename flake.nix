{
  description = "OpenZiti patched binaries";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    napalm = {
      url = "github:nix-community/napalm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zitiConsole = {
      url = "github:openziti/ziti-console";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-compat,
    flake-parts,
    napalm,
    zitiConsole,
  }:
    flake-parts.lib.mkFlake {inherit self;} {
      systems = ["x86_64-linux"];
      perSystem = {
        inputs',
        pkgs,
        system,
        ...
      }: let
        inherit (pkgs.lib) pipe recursiveUpdate;

        zitiLib = (import lib/lib.nix) pkgs;
        zitiVersions = (import ./versions.nix) pkgs;
        inherit (zitiVersions) state;
      in
        with pkgs; rec {
          devShells.default = mkShell {
            buildInputs = with packages; [
              alejandra
              shfmt
              treefmt
              ziti-cli-functions_latest
              ziti-controller_latest
              ziti-edge-tunnel_latest
              ziti_latest
              ziti-router_latest
              ziti-tunnel_latest
            ];
          };

          legacyPackages = packages;

          packages = with zitiLib;
            pipe {} [
              (recursiveUpdate (mkZitiPkgs state))
              (recursiveUpdate (mkZitiBinTypePkgs state "controller"))
              (recursiveUpdate (mkZitiBinTypePkgs state "router"))
              (recursiveUpdate (mkZitiBinTypePkgs state "tunnel"))
              (recursiveUpdate (mkZitiCliFnPkgs state))
              (recursiveUpdate mkZitiConsole)
              (recursiveUpdate (mkZitiEdgeTunnelPkgs state))
              (recursiveUpdate {default = packages.ziti-edge-tunnel_latest;})
            ];
        };
    };
}
