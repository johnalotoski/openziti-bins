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

    srcBinZitiEdgeTunnel = version: sha256:
      fetchzip {
        inherit sha256;
        url = "https://github.com/openziti/ziti-tunnel-sdk-c/releases/download/v${version}/ziti-edge-tunnel-Linux_x86_64.zip";
      };

    mkZitiPkg = v: state: {
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

    mkZitiBinTypePkg = v: binType: state: {
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

    mkZitiCliFnPkg = v: state: {
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

    mkZitiConsole = inputs': self: {
      ziti-console = let
        napalmPackage = inputs'.napalm.legacyPackages.buildPackage self.inputs.zitiConsole.outPath {};
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

    mkZitiEdgeTunnelPkg = v: state: {
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

    mkZitiPkgs = state: foldl (acc: v: acc // (mkZitiPkg v state)) {} (attrNames state.srcBinZiti);
    mkZitiBinTypePkgs = state: binType: foldl (acc: v: acc // (mkZitiBinTypePkg v binType state)) {} (attrNames state.srcZiti);
    mkZitiCliFnPkgs = state: foldl (acc: v: acc // (mkZitiCliFnPkg v state)) {} (attrNames state.srcZiti);
    mkZitiEdgeTunnelPkgs = state: foldl (acc: v: acc // (mkZitiEdgeTunnelPkg v state)) {} (attrNames state.srcBinZitiEdgeTunnel);
  }
