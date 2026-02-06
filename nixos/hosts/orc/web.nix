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
            "tcp:80": "http://localhost:9000"
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

        web.port=9000;
        
        storage = {
          # persistence defaults to memory, so every rebuld loses data
          type = "sqlite";
          path = "/var/lib/gatus/gatus.db";

          maximum-number-of-results = 1000;
          maximum-number-of-events = 500;
        };

        endpoints = [
          {
            name = "rokeachphoto";
            url = "https://rokeachphoto.com/";
            interval = "1m";
            conditions = [
              "[STATUS] == 200"
            ];
          }
          {
            name = "rokeachphoto dgt";
            url = "https://dgt.rokeachphoto.com/";
            interval = "1m";
            conditions = [
              "[STATUS] == 200"
            ];
          }
          {
            name = "rokeachphoto dgt bridge";
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
            name = "zeeba external";
            url = "https://zeeba.dgt.is/";
            interval = "1m";
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

          {
            name = "stashcast demo";
            url = "https://demo.stashcast.dgt.is/";
            # interval = "1m";
            conditions = [
              "[STATUS] == 200"
            ];
          }

        ];
      };
    };

    caddy = {
      enable = true;


      virtualHosts."http://localhost".extraConfig = ''
        # respond "Hello, local!"
        reverse_proxy 127.0.0.1:8000
      '';

      # TODO: set ddns up for orc, in case the IP is not static. not sure.
      virtualHosts = {

        # for now this service is running in docker compose from home dir

        "demo.stashcast.dgt.is" = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:8000
          '';
        };
      };
      

    };

  };

  environment.systemPackages = with pkgs; [

  ];
}
