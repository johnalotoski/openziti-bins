{
  description = "OpenZiti patched binaries";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-22.11-darwin";

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
    nixpkgs-darwin,
    flake-compat,
    flake-parts,
    napalm,
    zitiConsole,
  }:
    flake-parts.lib.mkFlake {inherit self;} {
      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      perSystem = {
        inputs',
        pkgs,
        system,
        ...
      }: let
        inherit (pkgs.lib) pipe recursiveUpdate;
        inherit (zitiVersions) state;

        zitiLib = (import lib/lib.nix) pkgs;
        zitiVersions = (import ./versions.nix) pkgs;
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
              (recursiveUpdate (mkZitiConsole inputs' self))
              (recursiveUpdate (mkZitiEdgeTunnelPkgs state system))
              (recursiveUpdate {default = packages.ziti-edge-tunnel_latest;})
              (recursiveUpdate {
                ziti-edge-tunnel_latest_large_tcp = stdenv.mkDerivation rec {
                  version = "unstable";
                  name = "ziti-edge-tunnel_latest_large_tcp";

                  nativeBuildInputs = lib.optionals (system == "x86_64-linux") [autoPatchelfHook];
                  runtimeDependencies = lib.optionals (system == "x86_64-linux") [systemd];
                  buildInputs = [unzip];
                  src = ./zip/ziti-edge-tunnel-Linux_x86_64.zip;

                  sourceRoot = ".";

                  installPhase = ''
                    install -m755 -D ziti-edge-tunnel $out/bin/ziti-edge-tunnel
                  '';

                  meta = {
                    homepage = "https://github.com/openziti/ziti-tunnel-sdk-c";
                    description = "Ziti: programmable network overlay and associated edge components for application-embedded, zero-trust networking";
                    license = lib.licenses.asl20;
                    platforms = ["x86_64-linux"];
                  };
                };
              })
            ];
        };

      flake = {
        nixosModules = {
          ziti-controller = import ./modules/ziti-controller.nix self;
          ziti-console = import ./modules/ziti-console.nix self;
          ziti-edge-tunnel = import ./modules/ziti-edge-tunnel.nix self;
          ziti-router = import ./modules/ziti-router.nix self;
        };
      };
    };
}
