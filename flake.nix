{
  description = "OpenZiti patched binaries";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
  flake-parts.lib.mkFlake { inherit self; } {
    systems = ["x86_64-linux"];
    perSystem = { inputs', pkgs, system, ... }:

    let
    inherit (builtins) attrNames;
    inherit (pkgs.lib) fakeSha256 foldl licenses pipe platforms recursiveUpdate;

    srcZiti = version: sha256:
      pkgs.fetchFromGitHub {
        inherit sha256;
        owner = "openziti";
        repo = "ziti";
        rev = "v${version}";
      };

    srcBinZiti = version: sha256:
      pkgs.fetchurl {
        inherit sha256;
        url = "https://github.com/openziti/ziti/releases/download/v${version}/ziti-linux-amd64-${version}.tar.gz";
      };

    srcBinZitiEdgeTunnel = version: sha256:
      pkgs.fetchzip {
        inherit sha256;
        url = "https://github.com/openziti/ziti-tunnel-sdk-c/releases/download/v${version}/ziti-edge-tunnel-Linux_x86_64.zip";
      };

    state = {
      srcZiti = rec {
        latest = let l = v0-26-10; in {inherit (l) version hash;};

        v0-26-10 = {
          version = "0.26.10";
          hash = "sha256-+16ufjL6ej4lGkRsA6wNBN4s8EeQc2utzEGBIJ0ijls=";
        };

        v0-26-9 = {
          version = "0.26.9";
          hash = "sha256-cp07b5MyzK6109l7lB11bBa2+sXzGwqC2QJExuSwL5k=";
        };

        v0-26-8 = {
          version = "0.26.8";
          hash = "sha256-wmHpL9TaytEnyFZ7FuDffUD4VwRUkQigJS++BiP1fZo=";
        };
      };

      srcBinZiti = rec {
        latest = let l = v0-26-10; in {inherit (l) version hash;};

        v0-26-10 = {
          version = "0.26.10";
          hash = "sha256-kIJak44wjWi6iLyKdiSifNhZSZmjyNrcLCx/ggVQArE=";
        };

        v0-26-9 = {
          version = "0.26.9";
          hash = "sha256-QA/ks618eI+yJH+sBJyygORq5bCLeVefq3m9xo11Pf4=";
        };

        v0-26-8 = {
          version = "0.26.8";
          hash = "sha256-OovvwJ6cwiktccqkPdTXy8IvS4EdYLrIxqnB8Dz2sWM=";
        };
      };

      srcBinZitiEdgeTunnel = rec {
        latest = let l = v0-20-2; in {inherit (l) version hash;};

        # Working
        v0-20-2 = {
          version = "0.20.2";
          hash = "sha256-ZgeVSGqy12CQJEErzQ1gaXtJbv5bVncH66Li1X8D3P0=";
        };

        # False positive matches
        # Artifacts not yet available
        # v0-20-1 = {
        #   version = "0.20.1";
        #   hash = fakeSha256;
        # };

        # Broken DNS resolution
        v0-20-0 = {
          version = "0.20.0";
          hash = "sha256-/AS8PUaBjfunEwXvWnVmwMQSdQ0CHYM+FpbCSploaeA=";
        };

        # Working without obvious issues for vpn service
        v0-19-11 = {
          version = "0.19.11";
          hash = "sha256-cZne4M7XZV+bpOq5moRexMqhKCkBQ8pMpa7A7oBOcX8=";
        };
      };
    };
  in with pkgs; rec {

      devShells.default = mkShell {
        buildInputs = with packages; [
          ziti-cli-functions_latest
          ziti-controller_latest
          ziti-edge-tunnel_latest
          ziti_latest
          ziti-router_latest
          ziti-tunnel_latest
        ];
      };

      legacyPackages = packages;

      packages = let
        mkZitiPkg = v: {
          "ziti_${v}" = stdenv.mkDerivation rec {
            inherit (state.srcBinZiti.${v}) version;
            name = "ziti_${version}";

            src = srcBinZiti version state.srcBinZiti.${v}.hash;
            sourceRoot = ".";
            nativeBuildInputs = [autoPatchelfHook installShellFiles];

            postPhases = ["postAutoPatchelf"];

            installPhase = ''
              install -m755 -d $out/bin/
              install -m755 -D ziti/ziti $out/bin/
            '';

            postAutoPatchelf = ''
              installShellCompletion --cmd ziti \
                --bash <($out/bin/ziti completion bash) \
                --fish <($out/bin/ziti completion fish) \
                --zsh <($out/bin/ziti completion zsh)
                # No support for powershell in installShellCompletion
                # --powershell <($out/bin/ziti completion powershell)
            '';

            meta = {
              homepage = "https://github.com/openziti/ziti";
              description = "The parent project for OpenZiti. Here you will find the executables for a fully zero trust, application embedded, programmable network";
              license = licenses.asl20;
              platforms = platforms.linux;
            };
          };
        };

        mkZitiBinTypePkg = v: binType: {
          "ziti-${binType}_${v}" = stdenv.mkDerivation rec {
            inherit (state.srcBinZiti.${v}) version;
            name = "ziti-${binType}_${version}";

            src = srcBinZiti version state.srcBinZiti.${v}.hash;
            sourceRoot = ".";
            nativeBuildInputs = [autoPatchelfHook];

            installPhase = ''
              install -m755 -d $out/bin/
              install -m755 -D ziti/ziti-${binType} $out/bin/
            '';

            meta = {
              homepage = "https://github.com/openziti/ziti";
              description = "The parent project for OpenZiti. Here you will find the executables for a fully zero trust, application embedded, programmable network";
              license = licenses.asl20;
              platforms = platforms.linux;
            };
          };
        };

        mkZitiCliFnPkg = v: {
          "ziti-cli-functions_${v}" = writeShellApplication {
            runtimeInputs = [coreutils curl hostname jq killall openssl];
            name = "ziti-cli-functions.sh";
            text = let
              inherit (state.srcZiti.${v}) version hash;

              zitiCliFnSrc = (srcZiti version hash) + "/quickstart/docker/image/ziti-cli-functions.sh";

              cleanedShell =
                runCommandLocal "ziti-cli-fns-cleaned-${version}.sh" {
                  buildInputs = [coreutils gnused];
                } ''
                  # Trim non NixOS shebang header and select shellcheck disable
                  tail -n +6 ${zitiCliFnSrc} > ziti-cli-fns-cleaned.sh

                  # Disable shellcheck alerts
                  # TODO: fix upstream
                  sed -i '1s|^|#!/run/current-system/sw/bin/bash\n# shellcheck disable=SC2046,SC2155,SC2296\n|' ziti-cli-fns-cleaned.sh

                  chmod +x ziti-cli-fns-cleaned.sh
                  patchShebangs ziti-cli-fns-cleaned.sh
                  cp ziti-cli-fns-cleaned.sh $out
                '';
            in ''
              # shellcheck disable=SC1091
              source ${cleanedShell}
            '';
          };
        };

        mkZitiConsole = {
          ziti-console = let
            napalmPackage = inputs'.napalm.legacyPackages.buildPackage zitiConsole.outPath {};
          in
            stdenv.mkDerivation rec {
              name = napalmPackage.name;
              src = napalmPackage.outPath;
              installPhase = ''
                mkdir $out
                cp -a _napalm-install/* $out/
              '';

              meta = {
                homepage = "https://github.com/openziti/ziti-console";
                platforms = platforms.linux;
              };
            };
        };

        mkZitiEdgeTunnelPkg = v: {
          "ziti-edge-tunnel_${v}" = stdenv.mkDerivation rec {
            inherit (state.srcBinZitiEdgeTunnel.${v}) version;
            name = "ziti-edge-tunnel_${version}";

            src = srcBinZitiEdgeTunnel version state.srcBinZitiEdgeTunnel.${v}.hash;
            sourceRoot = ".";
            nativeBuildInputs = [autoPatchelfHook];
            runtimeDependencies = [systemd];

            installPhase = ''
              install -m755 -D source/ziti-edge-tunnel $out/bin/ziti-edge-tunnel
            '';

            meta = {
              homepage = "https://github.com/openziti/ziti-tunnel-sdk-c";
              description = "Ziti: programmable network overlay and associated edge components for application-embedded, zero-trust networking";
              license = licenses.asl20;
              platforms = platforms.linux;
            };
          };
        };

        mkZitiPkgs = foldl (acc: v: acc // (mkZitiPkg v)) {} (attrNames state.srcBinZiti);
        mkZitiBinTypePkgs = binType: foldl (acc: v: acc // (mkZitiBinTypePkg v binType)) {} (attrNames state.srcZiti);
        mkZitiCliFnPkgs = foldl (acc: v: acc // (mkZitiCliFnPkg v)) {} (attrNames state.srcZiti);
        mkZitiEdgeTunnelPkgs = foldl (acc: v: acc // (mkZitiEdgeTunnelPkg v)) {} (attrNames state.srcBinZitiEdgeTunnel);
      in
        pipe {} [
          (recursiveUpdate mkZitiPkgs)
          (recursiveUpdate (mkZitiBinTypePkgs "controller"))
          (recursiveUpdate (mkZitiBinTypePkgs "router"))
          (recursiveUpdate (mkZitiBinTypePkgs "tunnel"))
          (recursiveUpdate mkZitiCliFnPkgs)
          (recursiveUpdate mkZitiConsole)
          (recursiveUpdate mkZitiEdgeTunnelPkgs)
          (recursiveUpdate { default = packages.ziti-edge-tunnel_latest; })
        ];
    };
  };
}
