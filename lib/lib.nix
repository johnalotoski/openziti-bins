pkgs: let
  inherit (builtins) attrNames;
  inherit (pkgs.lib) foldl licenses platforms;
in
  with pkgs; rec {
    srcZiti = version: sha256:
      fetchFromGitHub {
        inherit sha256;
        owner = "openziti";
        repo = "ziti";
        rev = "v${version}";
      };

    srcBinZiti = version: sha256:
      fetchurl {
        inherit sha256;
        url = "https://github.com/openziti/ziti/releases/download/v${version}/ziti-linux-amd64-${version}.tar.gz";
      };

    srcBinZitiEdgeTunnel = version: sha256: {
      x86_64-linux = fetchzip {
        inherit sha256;
        url = "https://github.com/openziti/ziti-tunnel-sdk-c/releases/download/v${version}/ziti-edge-tunnel-Linux_x86_64.zip";
      };

      x86_64-darwin = fetchzip {
        inherit sha256;
        url = "https://github.com/openziti/ziti-tunnel-sdk-c/releases/download/v${version}/ziti-edge-tunnel-Darwin_x86_64.zip";
      };

      aarch64-darwin = fetchzip {
        inherit sha256;
        url = "https://github.com/openziti/ziti-tunnel-sdk-c/releases/download/v${version}/ziti-edge-tunnel-Darwin_arm64.zip";
      };
    };

    mkZitiPkg = v: state: lib.optionalAttrs (system == "x86_64-linux") {
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

    mkZitiBinTypePkg = v: binType: state: lib.optionalAttrs (system == "x86_64-linux") {
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

    mkZitiCliFnPkg = v: state: lib.optionalAttrs (system == "x86_64-linux") {
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

    mkZitiConsole = inputs': self: lib.optionalAttrs (system == "x86_64-linux") {
      ziti-console = let
        napalmPackage = inputs'.napalm.legacyPackages.buildPackage self.inputs.zitiConsole.outPath {
          npmCommands = "npm install --no-audit --loglevel verbose --ignore-scripts --nodedir=${nodejs}/include/node";
        };
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

    mkZitiEdgeTunnelPkg = v: state: system: {
      "ziti-edge-tunnel_${v}" = stdenv.mkDerivation rec {
        inherit (state.srcBinZitiEdgeTunnel.${system}.${v}) version;
        name = "ziti-edge-tunnel_${version}";

        src = (srcBinZitiEdgeTunnel version state.srcBinZitiEdgeTunnel.${system}.${v}.hash).${system};
        sourceRoot = ".";
        nativeBuildInputs = lib.optionals (system == "x86_64-linux") [autoPatchelfHook];
        runtimeDependencies = lib.optionals (system == "x86_64-linux") [systemd];

        installPhase = ''
          install -m755 -D source/ziti-edge-tunnel $out/bin/ziti-edge-tunnel
        '';

        meta = {
          homepage = "https://github.com/openziti/ziti-tunnel-sdk-c";
          description = "Ziti: programmable network overlay and associated edge components for application-embedded, zero-trust networking";
          license = licenses.asl20;
          platforms = ["x86_64-linux" "x86_64-darwin" "aarch64-darwin"];
        };
      };
    };

    mkZitiPkgs = state: foldl (acc: v: acc // (mkZitiPkg v state)) {} (attrNames state.srcBinZiti);
    mkZitiBinTypePkgs = state: binType: foldl (acc: v: acc // (mkZitiBinTypePkg v binType state)) {} (attrNames state.srcZiti);
    mkZitiCliFnPkgs = state: foldl (acc: v: acc // (mkZitiCliFnPkg v state)) {} (attrNames state.srcZiti);
    mkZitiEdgeTunnelPkgs = state: system: foldl (acc: v: acc // (mkZitiEdgeTunnelPkg v state system)) {} (attrNames state.srcBinZitiEdgeTunnel.${system});
  }
