self: {
  pkgs,
  lib,
  inputs,
  config,
  ...
}: let
  inherit (lib) mkIf mkOption;
  inherit (lib.types) bool package port str;

  zitiExternalHostname = "zt.${config.cluster.domain}";
  zitiController = "ziti-controller";
  zitiEdgeController = zitiExternalHostname;
  zitiRouter = "ziti-router";
  zitiRouterHome = "/var/lib/${zitiRouter}";
  zitiNetwork = "${config.cluster.name}-zt";
  zitiEdgeRouter = zitiExternalHostname;
  zitiEdgeRouterRawName = "${zitiNetwork}-edge-router";

  # Config refs:
  #   ziti create config router --help
  #   https://github.com/openziti/ziti/blob/release-next/ziti/cmd/ziti/cmd/config_templates/router.yml
  #   https://github.com/openziti/ziti/blob/release-next/etc/edge.router.yml
  routerConfigNix = {
    v = 3;
    identity = {
      cert = "${zitiRouterHome}/pki/routers/${zitiEdgeRouter}/${zitiEdgeRouterRawName}-client.cert";
      server_cert = "${zitiRouterHome}/pki/routers/${zitiEdgeRouter}/${zitiEdgeRouterRawName}-server.cert";
      key = "${zitiRouterHome}/pki/routers/${zitiEdgeRouter}/${zitiEdgeRouterRawName}-server.key";
      ca = "${zitiRouterHome}/pki/routers/${zitiEdgeRouter}/cas.cert";
    };
    ctrl = {
      endpoint = "tls:${zitiController}:${toString cfg.portManagementApi}";
    };
    link = {
      dialers = [
        {
          binding = "transport";
        }
      ];
      listeners = [
        {
          binding = "transport";
          bind = "tls:0.0.0.0:${toString cfg.portFabricLinks}";
          advertise = "tls:${zitiEdgeRouter}:${toString cfg.portFabricLinks}";
          options = {
            outQueueSize = 4;
          };
        }
      ];
    };
    listeners = [
      {
        binding = "edge";
        address = "tls:0.0.0.0:${toString cfg.portEdgeConnection}";
        options = {
          advertise = "${zitiEdgeRouter}:${toString cfg.portEdgeConnection}";
          connectTimeoutMs = 1000;
          getSessionTimeout = "60s";
        };
      }
      {
        binding = "tunnel";
        options = {
          mode = "host";
        };
      }
    ];
    edge = {
      heartbeatIntervalSeconds = 60;
      csr = {
        country = "US";
        province = "CO";
        locality = "Longmont";
        organization = "IOG";
        organizationalUnit = "IO";
        sans = {
          dns = [
            "${zitiEdgeRouter}"
            "localhost"
          ];
          ip = [
            "127.0.0.1"
          ];
        };
      };
    };
    forwarder = {
      latencyProbeInterval = 10;
      xgressDialQueueLength = 1000;
      xgressDialWorkerCount = 128;
      linkDialQueueLength = 1000;
      linkDialWorkerCount = 32;
    };
  };

  routerConfigFile = pkgs.toPrettyJSON "${zitiEdgeRouter}.yaml" routerConfigNix;
  cfg = config.services.ziti-router;

  ziti-pkg = cfg.packageZiti;
  ziti-router-pkg = cfg.packageZitiRouter;
  ziti-tunnel-pkg = cfg.packageZitiTunnel;
  ziti-cli-functions = cfg.packageZitiCliFunctions;
in {
  options.services.ziti-router = {
    enable = mkOption {
      type = bool;
      default = false;
      description = ''
        Enable the OpenZiti router service.
      '';
    };

    enableBashIntegration = mkOption {
      type = bool;
      # Defaults to false to avoid an auto-conflict when controller and router are on the same host
      default = false;
      description = ''
        Enable integration of OpenZiti bash completions and sourcing of the Ziti environment.

        NOTE: If multiple OpenZiti services are running on one host; the bash integration
              should be enabled for only one of the services.
      '';
    };

    packageZiti = mkOption {
      type = package;
      default = self.packages.${pkgs.system}.ziti_latest;
      description = ''
        The default ziti package to use.
        Defaults to `ziti_latest`.
      '';
    };

    packageZitiRouter = mkOption {
      type = package;
      default = self.packages.${pkgs.system}.ziti-router_latest;
      description = ''
        The default ziti-router package to use.
        Defaults to `ziti-router_latest`.
      '';
    };

    packageZitiTunnel = mkOption {
      type = package;
      default = self.packages.${pkgs.system}.ziti-tunnel_latest;
      description = ''
        The default ziti-tunnel package to use.
        Defaults to `ziti-tunnel_latest`.
      '';
    };

    packageZitiCliFunctions = mkOption {
      type = package;
      default = self.packages.${pkgs.system}.ziti-cli-functions_latest;
      description = ''
        The default ziti-cli-functions package to use.
        Defaults to `ziti-cli-functions_latest`.
      '';
    };

    extraBootstrapPre = mkOption {
      type = str;
      default = "";
      description = ''
        Extra code which will be run at the end of the systemd ExecStartPre block.
      '';
    };

    extraBootstrapPost = mkOption {
      type = str;
      default = "";
      description = ''
        Extra code which will be run at the end of the systemd ExecStartPost block.
      '';
    };

    openFirewall = mkOption {
      type = bool;
      default = true;
      description = ''
        Whether to automatically open the TCP firewall ports for Ziti controller
        port bindings.
      '';
    };

    portEdgeConnection = mkOption {
      type = port;
      default = 3022;
      description = ''
        Ziti edge router connection port binding.
      '';
    };

    portFabricLinks = mkOption {
      type = port;
      default = 10080;
      description = ''
        Ziti router fabric links port binding.
      '';
    };

    portManagementApi = mkOption {
      type = port;
      default = 6262;
      description = ''
        Ziti controller management API port binding.
      '';
    };

    portRestApi = mkOption {
      type = port;
      default = 1280;
      description = ''
        Ziti controller REST API port binding.
      '';
    };
  };

  config = mkIf cfg.enable {
    # OpenZiti CLI package
    environment.systemPackages = with pkgs; [
      step-cli
      ziti-cli-functions
      ziti-pkg
      ziti-router-pkg
      ziti-tunnel-pkg
    ];

    programs.bash.interactiveShellInit = mkIf cfg.enableBashIntegration ''
      [ -f ${zitiRouterHome}/${zitiNetwork}.env ] && source ${zitiRouterHome}/${zitiNetwork}.env
    '';

    networking.hosts = {
      "127.0.0.1" = [zitiEdgeRouter zitiExternalHostname];
    };

    # Required edge router public ports
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [
      cfg.portEdgeConnection
      cfg.portFabricLinks
    ];

    systemd.services.ziti-router = {
      wantedBy = ["multi-user.target"];

      startLimitIntervalSec = 0;
      startLimitBurst = 0;

      environment = rec {
        EXTERNAL_DNS = zitiExternalHostname;
        HOME = zitiRouterHome;
        ZITI_BIN_DIR = "${zitiRouterHome}/ziti-bin";
        ZITI_CONTROLLER_INTERMEDIATE_NAME = "${zitiController}-intermediate";
        ZITI_CONTROLLER_RAWNAME = zitiController;
        ZITI_EDGE_CONTROLLER_HOSTNAME = EXTERNAL_DNS;
        ZITI_EDGE_CONTROLLER_PORT = toString cfg.portRestApi;
        ZITI_EDGE_CONTROLLER_RAWNAME = zitiEdgeController;
        ZITI_EDGE_ROUTER_HOSTNAME = EXTERNAL_DNS;
        ZITI_EDGE_ROUTER_PORT = toString cfg.portEdgeConnection;
        ZITI_EDGE_ROUTER_RAWNAME = zitiEdgeRouterRawName;
        ZITI_EDGE_ROUTER_ROLES = "public";
        ZITI_HOME = zitiRouterHome;
        ZITI_NETWORK = zitiNetwork;
        ZITI_PKI_OS_SPECIFIC = "${zitiRouterHome}/pki";

        # Must be configured in the preStart script below in order to acquire external IP
        # EXTERNAL_IP = "...";
        # ZITI_EDGE_CONTROLLER_IP_OVERRIDE = "...";
        # ZITI_EDGE_ROUTER_IP_OVERRIDE = "...";
      };

      serviceConfig = {
        Restart = "always";
        RestartSec = 5;
        StateDirectory = zitiRouter;
        WorkingDirectory = zitiRouterHome;
        LimitNOFILE = 65535;

        ExecStartPre = let
          preScript = pkgs.writeShellApplication {
            name = "${zitiRouter}-preScript.sh";
            runtimeInputs = with pkgs; [dnsutils fd gnugrep ziti-pkg ziti-router-pkg];
            text = ''
              if ! [ -f .bootstrap-pre-complete ]; then
                # Following env vars must be configured here vs systemd environment in order to acquire external IP
                EXTERNAL_IP=$(dig +short myip.opendns.com @resolver1.opendns.com);
                ZITI_EDGE_CONTROLLER_IP_OVERRIDE="$EXTERNAL_IP";
                ZITI_EDGE_ROUTER_IP_OVERRIDE="$EXTERNAL_IP";
                export EXTERNAL_IP
                export ZITI_EDGE_CONTROLLER_IP_OVERRIDE
                export ZITI_EDGE_ROUTER_IP_OVERRIDE

                # shellcheck disable=SC1091
                source ${ziti-cli-functions}/bin/ziti-cli-functions.sh

                mkdir -p \
                  "$ZITI_BIN_DIR" \
                  "$ZITI_PKI_OS_SPECIFIC/routers/${zitiEdgeRouter}"

                # Link the nix pkgs openziti bins to the nix store path.
                # The functions refer to these
                ln -sf ${ziti-pkg}/bin/ziti "$ZITI_BIN_DIR"/ziti
                ln -sf ${ziti-pkg}/bin/ziti-router "$ZITI_BIN_DIR"/ziti-router

                # Tmp workaround to share required certs for PoC -- use another mechanism; ex: vault
                while ! [ -f /var/lib/ziti-controller/pki/cas.pem ]; do
                  echo "Waiting for shared cert access..."
                  sleep 2
                done
                cp -a /var/lib/ziti-controller/pki/ziti-controller-intermediate /var/lib/ziti-router/pki/
                cp -a /var/lib/ziti-controller/pki/${zitiExternalHostname}-intermediate /var/lib/ziti-router/pki/
                cp -a /var/lib/ziti-controller/pki/cas.pem /var/lib/ziti-router/pki/routers/${zitiExternalHostname}/cas.cert

                # Create PoC router pki
                createRouterPki "$ZITI_EDGE_ROUTER_RAWNAME"
                fd -t f "$ZITI_EDGE_ROUTER_RAWNAME" "pki/$ZITI_CONTROLLER_INTERMEDIATE_NAME" -x mv {} pki/routers/${zitiEdgeRouter}

                # Tmp workaround to share required certs for PoC -- use another mechanism; ex: vault
                while ! [ -f /var/lib/ziti-controller/${zitiNetwork}.env ]; do
                  echo "Waiting for shared access..."
                  sleep 2
                done

                # Ensure the controller is healthy
                while [[ "$(curl -w "%{http_code}" -m 1 -s -k -o /dev/null https://${zitiEdgeController}:${toString cfg.portRestApi}/version)" != "200" ]]; do
                  echo "waiting for https://${zitiEdgeController}:${toString cfg.portRestApi}"
                  sleep 3
                done

                # Ensure the controller has fully bootstrapped
                sleep 10

                # shellcheck disable=SC1090
                source <(grep ZITI_USER= /var/lib/ziti-controller/${zitiNetwork}.env)

                # shellcheck disable=SC1090
                source <(grep ZITI_PWD= /var/lib/ziti-controller/${zitiNetwork}.env)

                ziti edge login \
                  "${zitiEdgeController}:${toString cfg.portRestApi}" \
                  -u "$ZITI_USER" \
                  -p "$ZITI_PWD" \
                  -c /var/lib/ziti-router/pki/${zitiExternalHostname}-intermediate/certs/${zitiExternalHostname}-intermediate.cert

                FOUND=$(ziti edge list edge-routers 'name = "'"$ZITI_EDGE_ROUTER_HOSTNAME"'"' | grep -c "$ZITI_EDGE_ROUTER_HOSTNAME") || true
                if [ "$FOUND" -gt 0 ]; then
                  echo "Found existing edge-router $ZITI_EDGE_ROUTER_HOSTNAME..."
                else
                  echo "Creating edge-router $ZITI_EDGE_ROUTER_HOSTNAME identity..."
                  ziti edge create edge-router "$ZITI_EDGE_ROUTER_HOSTNAME" -o "$ZITI_HOME/$ZITI_EDGE_ROUTER_HOSTNAME.jwt" -t -a "$ZITI_EDGE_ROUTER_ROLES"
                  sleep 1
                  echo "Enrolling edge-router $ZITI_EDGE_ROUTER_HOSTNAME..."
                  ziti-router enroll ${routerConfigFile} --jwt "$ZITI_HOME/$ZITI_EDGE_ROUTER_HOSTNAME.jwt"
                  echo ""
                fi

                # Include user defined pre start bootstrap scripting
                ${cfg.extraBootstrapPre}

                touch .bootstrap-pre-complete
              fi
            '';
          };
        in "${preScript}/bin/${zitiRouter}-preScript.sh";

        ExecStart = let
          script = pkgs.writeShellApplication {
            name = zitiRouter;
            runtimeInputs = with pkgs; [iproute2 iptables];
            text = ''
              exec ${ziti-router-pkg}/bin/ziti-router run ${routerConfigFile}
            '';
          };
        in "${script}/bin/${zitiRouter}";

        ExecStartPost = let
          postScript = pkgs.writeShellApplication {
            name = "${zitiRouter}-postScript.sh";
            text = ''
              if ! [ -f .bootstrap-post-complete ]; then
                # Include user defined pre start bootstrap scripting
                ${cfg.extraBootstrapPre}

                touch .bootstrap-post-complete
              fi
            '';
          };
        in "${postScript}/bin/${zitiRouter}-postScript.sh";
      };
    };
  };
}
