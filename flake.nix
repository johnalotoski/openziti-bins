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
      version = "0.19.11";

      src = pkgs.fetchzip {
        url = "https://github.com/openziti/ziti-tunnel-sdk-c/releases/download/v${version}/ziti-edge-tunnel-Linux_x86_64.zip";
        sha256 = "sha256-cZne4M7XZV+bpOq5moRexMqhKCkBQ8pMpa7A7oBOcX8=";
      };

      sourceRoot = ".";
      nativeBuildInputs = [ autoPatchelfHook ];
      runtimeDependencies = [ systemd ];

      installPhase = ''
        install -m755 -D source/ziti-edge-tunnel $out/bin/ziti-edge-tunnel
      '';

      meta = with lib; {
        homepage = "https://openziti.github.io";
        description = "Ziti: programmable network overlay and associated edge components for application-embedded, zero-trust networking";
        platforms = platforms.linux;
      };
    };
  };
}
