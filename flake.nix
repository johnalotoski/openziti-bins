{
  description = "OpenZiti patched binaries";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";

    napalm = {
      url = "github:nix-community/napalm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zitiConsole = {
      url = "github:openziti/ziti-console";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, napalm, zitiConsole }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
    };

    srcZiti = version: sha256: pkgs.fetchFromGitHub {
      inherit sha256;
      owner = "openziti";
      repo = "ziti";
      rev = "v${version}";
    };

    srcBinZiti = version: sha256: pkgs.fetchurl {
      inherit sha256;
      url = "https://github.com/openziti/ziti/releases/download/v${version}/ziti-linux-amd64-${version}.tar.gz";
    };

    srcBinZitiEdgeTunnel = version: sha256: pkgs.fetchzip {
      inherit sha256;
      url = "https://github.com/openziti/ziti-tunnel-sdk-c/releases/download/v${version}/ziti-edge-tunnel-Linux_x86_64.zip";
    };

    hashes = {
      srcZiti = {
        "0.26.10" = "sha256-+16ufjL6ej4lGkRsA6wNBN4s8EeQc2utzEGBIJ0ijls=";
        "0.26.9" = "sha256-cp07b5MyzK6109l7lB11bBa2+sXzGwqC2QJExuSwL5k=";
        "0.26.8" = "sha256-wmHpL9TaytEnyFZ7FuDffUD4VwRUkQigJS++BiP1fZo=";
      };

      srcBinZiti = {
        "0.26.10" = "sha256-kIJak44wjWi6iLyKdiSifNhZSZmjyNrcLCx/ggVQArE=";
        "0.26.9" = "sha256-QA/ks618eI+yJH+sBJyygORq5bCLeVefq3m9xo11Pf4=";
        "0.26.8" = "sha256-OovvwJ6cwiktccqkPdTXy8IvS4EdYLrIxqnB8Dz2sWM=";
      };

      srcBinZitiEdgeTunnel = {
        "0.20.0" = "sha256-/AS8PUaBjfunEwXvWnVmwMQSdQ0CHYM+FpbCSploaeA=";
        "0.19.11" = "sha256-cZne4M7XZV+bpOq5moRexMqhKCkBQ8pMpa7A7oBOcX8=";
      };
    };

  in with pkgs; rec {
    defaultPackage.x86_64-linux = ziti-edge-tunnel.x86_64-linux;

    packages.x86_64-linux = let
      sanitize = s: builtins.replaceStrings ["."] ["_"] s;

      mkZitiPkg = version: {
        "ziti_${sanitize version}" = stdenv.mkDerivation rec {
          inherit version;
          name = "ziti-${version}";

          src = srcBinZiti version hashes.srcBinZiti.${version};
          sourceRoot = ".";
          nativeBuildInputs = [autoPatchelfHook installShellFiles];

          postPhases = ["postAutoPatchelf"];

          installPhase = ''
            install -m755 -d $out/bin/
            install -m755 -D ziti/* $out/bin/
          '';

          postAutoPatchelf = ''
            installShellCompletion --cmd ziti \
              --bash <($out/bin/ziti completion bash) \
              --fish <($out/bin/ziti completion fish) \
              --zsh <($out/bin/ziti completion zsh)
              # No support for powershell in installShellCompletion
              # --powershell <($out/bin/ziti completion powershell)
          '';

          meta = with lib; {
            homepage = "https://github.com/openziti/ziti";
            description = "The parent project for OpenZiti. Here you will find the executables for a fully zero trust, application embedded, programmable network";
            license = licenses.asl20;
            platforms = platforms.linux;
          };
        };
      };

      mkZitiCliFnPkg = version: {
        "ziti-cli-functions_${sanitize version}" = writeShellApplication {
          runtimeInputs = [coreutils curl hostname jq killall openssl];
          name = "ziti-cli-functions.sh";
          text = let
            zitiCliFnSrc = (srcZiti version hashes.srcZiti.${version}) + "/quickstart/docker/image/ziti-cli-functions.sh";
            cleanedShell = runCommandLocal "ziti-cli-fns-cleaned.sh" {
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
          napalmPackage = napalm.legacyPackages.x86_64-linux.buildPackage zitiConsole.outPath {};
        in stdenv.mkDerivation rec {
          name = napalmPackage.name;
          src = napalmPackage.outPath;
          installPhase = ''
            mkdir $out
            cp -a _napalm-install/* $out/
          '';

          meta = with lib; {
            homepage = "https://github.com/openziti/ziti-console";
            platforms = platforms.linux;
          };
        };
      };

      mkZitiEdgeTunnelPkg = version: {
        "ziti-edge-tunnel_${sanitize version}" = stdenv.mkDerivation rec {
          inherit version;
          name = "ziti-edge-tunnel-${version}";

          src = srcBinZitiEdgeTunnel version hashes.srcBinZitiEdgeTunnel.${version};
          sourceRoot = ".";
          nativeBuildInputs = [autoPatchelfHook];
          runtimeDependencies = [systemd];

          installPhase = ''
            install -m755 -D source/ziti-edge-tunnel $out/bin/ziti-edge-tunnel
          '';

          meta = with lib; {
            homepage = "https://github.com/openziti/ziti-tunnel-sdk-c";
            description = "Ziti: programmable network overlay and associated edge components for application-embedded, zero-trust networking";
            license = licenses.asl20;
            platforms = platforms.linux;
          };
        };
      };

      mkZitiPkgs = lib.foldl (acc: v: acc // (mkZitiPkg v)) {} (builtins.attrNames hashes.srcBinZiti);
      mkZitiCliFnPkgs = lib.foldl (acc: v: acc // (mkZitiCliFnPkg v)) {} (builtins.attrNames hashes.srcZiti);
      mkZitiEdgeTunnelPkgs = lib.foldl (acc: v: acc // (mkZitiEdgeTunnelPkg v)) {} (builtins.attrNames hashes.srcBinZitiEdgeTunnel);

    in lib.pipe {} [
      (lib.recursiveUpdate mkZitiPkgs)
      (lib.recursiveUpdate mkZitiCliFnPkgs)
      (lib.recursiveUpdate mkZitiConsole)
      (lib.recursiveUpdate mkZitiEdgeTunnelPkgs)
    ];
  };
}
