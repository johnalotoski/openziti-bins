self: {
  pkgs,
  lib,
  inputs,
  config,
  ...
}: let
  inherit (lib) mkIf mkOption;
  inherit (lib.types) bool package port;

  cfg = config.services.ziti-console;
  ziti-console = cfg.package;
in {
  options.services.ziti-console = {
    enable = mkOption {
      type = bool;
      default = false;
      description = ''
        Enable the OpenZiti console service.
      '';
    };

    package = mkOption {
      type = package;
      default = self.packages.${pkgs.system}.ziti-console;
      description = ''
        The default ziti-console package to use.
        Defaults to `ziti-console`.
      '';
    };

    portHttp = mkOption {
      type = port;
      default = 1408;
      description = ''
        The HTTP port ZAC uses.
      '';
    };

    portHttps = mkOption {
      type = port;
      default = 8443;
      description = ''
        The HTTPS port ZAC uses.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.ziti-console = {
      wantedBy = ["multi-user.target"];

      startLimitIntervalSec = 0;
      startLimitBurst = 0;

      path = with pkgs; [nodejs];

      environment = {
        PORT = toString cfg.portHttp;
        PORTTLS = toString cfg.portHttps;

        # Tmp workaround to share required creds for PoC -- use another mechanism; ex: vault
        ZAC_SERVER_CERT_CHAIN = "/var/lib/ziti-controller/pki/ziti-controller-intermediate/certs/ziti-controller-server.cert";
        ZAC_SERVER_KEY = "/var/lib/ziti-controller/pki/ziti-controller-intermediate/keys/ziti-controller-server.key";
      };

      serviceConfig = {
        Restart = "always";
        RestartSec = 5;
        StateDirectory = "ziti-console";
        WorkingDirectory = "/var/lib/ziti-console";
        LimitNOFILE = 65535;

        ExecStartPre = let
          preScript = pkgs.writeShellApplication {
            name = "ziti-console-preScript.sh";
            text = ''
              if ! [ -f .bootstrap-pre-complete ]; then
                cp -a ${ziti-console}/* /var/lib/ziti-console

                touch .bootstrap-pre-complete
              fi

              until [ -f "$ZAC_SERVER_CERT_CHAIN" ]; do
                echo "Waiting for $ZAC_SERVER_CERT_CHAIN..."
                sleep 2
              done

              until [ -f "$ZAC_SERVER_KEY" ]; do
                echo "Waiting for $ZAC_SERVER_KEY..."
                sleep 2
              done
            '';
          };
        in "${preScript}/bin/ziti-console-preScript.sh";

        ExecStart = let
          script = pkgs.writeShellApplication {
            name = "ziti-console";
            text = ''
              node server.js
            '';
          };
        in "${script}/bin/ziti-console";
      };
    };
  };
}
