pkgs: let
  inherit (pkgs.lib) fakeSha256;
in {
  state = {
    srcZiti = rec {
      latest = v0-27-5;

      v0-27-5 = {
        version = "0.27.5";
        hash = "sha256-C9wVfmjb8nE10Zlfa0MJduUy86L9CEIPMDsJx7MwAwk=";
      };

      v0-27-2 = {
        version = "0.27.2";
        hash = "sha256-3Fo2PoyibmT/pSALIN6gM4kSSv8kKgTzeNKa/vGI5gc=";
      };

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
      latest = v0-27-5;

      v0-27-5 = {
        version = "0.27.5";
        hash = "sha256-bLOcK6Bh3J5dZ8+kudX/pxFaPVRP9GU0uHfO5xDBGiA=";
      };

      v0-27-2 = {
        version = "0.27.2";
        hash = "sha256-BsEsRuNEdMWrMTkokRHVrq9SjGsxw2aclrsVvxF595A=";
      };

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

    srcBinZitiEdgeTunnel = let
    in rec {

      x86_64-linux = rec {
        latest = v0-21-3;

        v0-21-3 = {
          version = "0.21.3";
          hash = "sha256-O9vA08WVEond+R447ZLyYBgDSaj2VHp+5C20FxxYWUc=";
        };

        v0-20-22 = {
          version = "0.20.22";
          hash = "sha256-ji29IzPLrM5Qh1Tg+WTn5z222267aks7qVICQOQi22A=";
        };

        v0-20-21 = {
          version = "0.20.21";
          hash = "sha256-8/ci7ULITRcRpHnZcr7afcOt+y6aLfxeaRdJHN0Ma1U=";
        };

        v0-20-20 = {
          version = "0.20.20";
          hash = "sha256-dlFY+U7p1yfFhphlU1UZJek85K0QanYIi457U7dcGMM=";
        };

        v0-20-18 = {
          version = "0.20.18";
          hash = "sha256-D773ZeEs/NUp/lwVCKxYz5voq/MXeLiJU5YcB/Vcs8g=";
        };

        v0-20-6 = {
          version = "0.20.6";
          hash = "sha256-fyOJJ88DvRCVHNtlWt1eUJdH1XRAyeSgHeJTwxWM8e0=";
        };

        v0-20-2 = {
          version = "0.20.2";
          hash = "sha256-ZgeVSGqy12CQJEErzQ1gaXtJbv5bVncH66Li1X8D3P0=";
        };

        v0-20-0 = {
          version = "0.20.0";
          hash = "sha256-/AS8PUaBjfunEwXvWnVmwMQSdQ0CHYM+FpbCSploaeA=";
        };

        v0-19-11 = {
          version = "0.19.11";
          hash = "sha256-cZne4M7XZV+bpOq5moRexMqhKCkBQ8pMpa7A7oBOcX8=";
        };
      };

      x86_64-darwin = rec {
        latest = v0-21-3;

        v0-21-3 = {
          version = "0.21.3";
          hash = "sha256-e2TUDH9A+nriVgHEHg9uY+3tvj5p0ArtRS9Kgsitwwg=";
        };

        v0-20-22 = {
          version = "0.20.22";
          hash = "sha256-bYif71NfMgajWXjDyRB9FQOOjliUmt0qNvO6C3g1lfM=";
        };

        v0-20-21 = {
          version = "0.20.21";
          hash = "sha256-HpnhiDSM3grranJ7gt3HM8Zfn4BBBTxQjnFy8ASsiFw=";
        };
      };

      aarch64-darwin = rec {
        latest = v0-21-3;

        v0-21-3 = {
          version = "0.21.3";
          hash = "sha256-TAFbQ0B+Kg2SvyW/JvG77aZfZRgaw3kA8XQRGr93AR4=";
        };

        v0-20-22 = {
          version = "0.20.22";
          hash = "sha256-u+lsg2znaJTinR9/WUfUVP8YS7QkWo4d4Du9Fj79iaE=";
        };

        v0-20-21 = {
          version = "0.20.21";
          hash = "sha256-UwD91Hx4c95JT3rGc4WxnNQbpNP8xq6an7m31VB/9CM=";
        };
      };
    };
  };
}
