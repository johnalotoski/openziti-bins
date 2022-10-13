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

    zitiVersion = "0.26.9";
    zitiTunnelerVersion = "0.20.0";

    srcZiti = version: pkgs.fetchFromGitHub {
      owner = "openziti";
      repo = "ziti";
      rev = "v${version}";
      sha256 = "sha256-cp07b5MyzK6109l7lB11bBa2+sXzGwqC2QJExuSwL5k=";
    };

    srcBinZiti = version: pkgs.fetchurl {
      url = "https://github.com/openziti/ziti/releases/download/v${version}/ziti-linux-amd64-${version}.tar.gz";
      sha256 = "sha256-QA/ks618eI+yJH+sBJyygORq5bCLeVefq3m9xo11Pf4=";
    };

    srcBinZitiTunneler = version: pkgs.fetchzip {
      url = "https://github.com/openziti/ziti-tunnel-sdk-c/releases/download/v${version}/ziti-edge-tunnel-Linux_x86_64.zip";
      sha256 = "sha256-/AS8PUaBjfunEwXvWnVmwMQSdQ0CHYM+FpbCSploaeA=";
    };

  in with pkgs; rec {
    defaultPackage.x86_64-linux = ziti-edge-tunnel.x86_64-linux;

    packages.x86_64-linux = {
      ziti = stdenv.mkDerivation rec {
        name = "ziti-${version}";
        version = zitiVersion;

        src = srcBinZiti zitiVersion;
        sourceRoot = ".";
        nativeBuildInputs = [autoPatchelfHook installShellFiles];

        installPhase = ''
          install -m755 -d $out/bin/
          install -m755 -D ziti/* $out/bin/
        '';

        postInstall = ''
          installShellCompletion --cmd ziti \
            --bash <($out/bin/ziti completion bash) \
            --bash <($out/bin/ziti completion fish) \
            --bash <($out/bin/ziti completion powershell) \
            --bash <($out/bin/ziti completion zsh)
        '';

        meta = with lib; {
          homepage = "https://github.com/openziti/ziti";
          description = "The parent project for OpenZiti. Here you will find the executables for a fully zero trust, application embedded, programmable network";
          platforms = platforms.linux;
        };
      };

      ziti-cli-functions = writeShellApplication {
        runtimeInputs = [coreutils curl hostname jq killall openssl];
        name = "ziti-cli-functions.sh";
        text = let
          zitiCliFnSrc = (srcZiti zitiVersion) + "/quickstart/docker/image/ziti-cli-functions.sh";
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

      ziti-console = napalm.legacyPackages.x86_64-linux.buildPackage zitiConsole.outPath {};

      ziti-edge-tunnel = stdenv.mkDerivation rec {
        name = "ziti-edge-tunnel-${version}";
        version = zitiTunnelerVersion;

        src = srcBinZitiTunneler zitiTunnelerVersion;

        sourceRoot = ".";
        nativeBuildInputs = [ autoPatchelfHook ];
        runtimeDependencies = [ systemd ];

        installPhase = ''
          install -m755 -D source/ziti-edge-tunnel $out/bin/ziti-edge-tunnel
        '';

        meta = with lib; {
          homepage = "https://github.com/openziti/ziti-tunnel-sdk-c";
          description = "Ziti: programmable network overlay and associated edge components for application-embedded, zero-trust networking";
          platforms = platforms.linux;
        };
      };
    };
  };
}
