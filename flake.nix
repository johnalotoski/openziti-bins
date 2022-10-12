{
  description = "OpenZiti patched binaries";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
    };
  in with pkgs; rec {
    defaultPackage.x86_64-linux = ziti-edge-tunnel.x86_64-linux;

    packages.x86_64-linux.ziti-edge-tunnel = stdenv.mkDerivation rec {
      name = "ziti-edge-tunnel-${version}";
      version = "0.20.0";

      src = pkgs.fetchzip {
        url = "https://github.com/openziti/ziti-tunnel-sdk-c/releases/download/v${version}/ziti-edge-tunnel-Linux_x86_64.zip";
        sha256 = "sha256-/AS8PUaBjfunEwXvWnVmwMQSdQ0CHYM+FpbCSploaeA=";
      };

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

    packages.x86_64-linux.ziti = stdenv.mkDerivation rec {
      name = "ziti-${version}";
      version = "0.26.9";

      src = pkgs.fetchurl {
        url = "https://github.com/openziti/ziti/releases/download/v${version}/ziti-linux-amd64-${version}.tar.gz";
        sha256 = "sha256-QA/ks618eI+yJH+sBJyygORq5bCLeVefq3m9xo11Pf4=";
      };

      sourceRoot = ".";
      nativeBuildInputs = [ autoPatchelfHook ];

      installPhase = ''
        install -m755 -d $out/bin/
        install -m755 -D ziti/* $out/bin/
      '';

      meta = with lib; {
        homepage = "https://github.com/openziti/ziti";
        description = "The parent project for OpenZiti. Here you will find the executables for a fully zero trust, application embedded, programmable network";
        platforms = platforms.linux;
      };
    };
  };
}
