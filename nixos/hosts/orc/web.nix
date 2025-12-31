{ pkgs, config, ... }:

let

in
{
  
  # expose 'http://uptime' service on tailnet
  environment.etc."tailscale/serveconfig.json".text = ''
    {
      "version": "0.0.1",
      "services": {
        "svc:uptime": {
          "endpoints": {
            "tcp:80": "http://localhost:8080"
          }
        }
      }
    }
  '';

  systemd.services.tailscale-serve-web = {
    wantedBy = [ "multi-user.target" ];
    after = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve set-config --all /etc/tailscale/serveconfig.json";
    };
  };


  services = {

    gatus = {
      enable = true;
      settings = {

        storage = {
          # persistence defaults to memory, so every rebuld loses data
          type = "sqlite";
          path = "/var/lib/gatus/gatus.db";

          maximum-number-of-results = 1000;
          maximum-number-of-events = 500;
        };
        
        endpoints = [{
          name = "barrie bridge";
          url = "https://dgt.rokeachphoto.com/bridge/";
          interval = "1m";
          conditions = [
            "[STATUS] == 200"
            # "[TITLE] == bridge [150]"
            # "[RESPONSE_TIME] < 300"
          ];
        }
        {
          name = "blog";
          url = "https://www.dgt.is/";
          interval = "5m";
          conditions = [
            # "[TITLE] == Jono&#39;s Corner"
            "[STATUS] == 200"
          ];
        }

        {
          name = "matcha ping (tailnet)";
          url = "icmp://matcha";
          # interval = "2m";
          conditions = [
            "[CONNECTED] == true"
          ];
        }

        {
          name = "zeeba ping (tailnet)";
          url = "icmp://zeeba";
          # interval = "2m";
          conditions = [
            "[CONNECTED] == true"
          ];
        }

        {
          name = "alb ping (IP)";
          url = "icmp://23.93.90.200";
          # url = "icmp://23.93.93.159";
          # interval = "2m";
          conditions = [
            "[CONNECTED] == true"
          ];
        }

        {
          name = "alb ping (DNS)";
          url = "icmp://a.foodnotblogs.com";
          # interval = "2m";
          conditions = [
            "[CONNECTED] == true"
          ];
        }

        {
          name = "berk NAS IP ping";
          url = "icmp://192.168.1.140";
          # interval = "2m";
          conditions = [
            "[CONNECTED] == true"
          ];
        }

        {
          name = "triplit public prod";
          url = "https://zeeba.dgt.is/sfc";
          # interval = "2m";
          conditions = [
            "[STATUS] == 401"
          ];
        }

        ];
      };
    };

    # caddy = {
    #   enable = true;
    #   # virtualHosts."localhost".extraConfig = ''
    #   #   respond "Hello, local!"
    #   # '';

    #   # virtualHosts."http://orc".extraConfig = ''
    #   #   respond "Hello, orc!"
    #   # '';

    #   virtualHosts."http://orc".extraConfig = ''

    #       # running at root since the app does not seem to work well in a subpath
    #       route /* {
    #         reverse_proxy localhost:8080
    #       }

    #       # # Default response for other routes
    #       # respond "Hello, world!"
    #   '';

    # };

  };

  environment.systemPackages = with pkgs; [
    # php83
  ];
}
