{ pkgs, config, ... }:

let
  # Reusable PHP site configuration
  rokeachphotoPhp = ''
    root * /srv/rokeachphoto
    
    # Handle PHP files with FastCGI
    php_fastcgi 127.0.0.1:9000
    
    # Serve static files
    file_server
  '';

  # Function to read a secret from a file
  # The secret file should be created manually on the system at the specified path
  # and should NOT be tracked in git
  readSecretFile = path:
    let
      secret = builtins.readFile path;
      # Trim whitespace (including newlines) from the secret
      trimmedSecret = builtins.replaceStrings ["\n"] [""] secret;
    in
    builtins.toString trimmedSecret;
in
{

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      # mynginx = {
      #   image = "nginx:latest";
      #   ports = [ "8080:80" ];
      #   environment = {
      #     NGINX_PORT = "8080";
      #   };
      #   volumes = [ "/host/path:/container/path" ];
      #   cmd = [ "nginx" "-g" "daemon off;" ];
      # };
      triplit = {
        image = "aspencloud/triplit-server";
        ports = [ "8080:8080" ];
        environment = {
          LOCAL_DATABASE_URL = "/data/sfcarpool.db";
          # Read secret from file - the file should be created at /etc/triplit-jwt-secret
          # and should NOT be tracked in git
          JWT_SECRET = readSecretFile /etc/triplit-jwt-secret;
        };
        # name = "triplit-server";
        # volumes = [ "/run/sfcarpool/sfcarpool.db:/app/sfcarpool.db" ];
        volumes = [ "/run/sfcarpool:/data" ];
      };

      triplit-dev = {
        image = "aspencloud/triplit-server";
        ports = [ "8082:8080" ];
        environment = {
          LOCAL_DATABASE_URL = "/data/sfcarpool-dev.db";
          JWT_SECRET = readSecretFile /etc/triplit-jwt-secret;
        };
        # name = "triplit-server";
        volumes = [ "/run/sfcarpool:/data" ];
      };

    };
  };


  # just for samba
  users.users.ron = {
    isSystemUser = true;
    # group = "samba-users";
    group = "ron";
  };
  users.groups.ron = {};


  # TODO: add https://netalertx.com/ and coolify

  services = {

    # TODO: maybe move this out of web.nix
    samba = {
      enable = true;
      securityType = "user";
      openFirewall = true;

      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "smbnix";
          "netbios name" = "smbnix";
          "security" = "user";
          #"use sendfile" = "yes";
          #"max protocol" = "smb2";
          # note: localhost is the ipv6 localhost ::1
          # "hosts allow" = "192.168.1. 192.168.200. 192.168.100.127.0.0.1 localhost";
          # "hosts deny" = "0.0.0.0/0";
          # "guest account" = "nobody";
          # "map to guest" = "bad user";
        };
        "public" = {
          "path" = "/dpool/samba/Public";
          "browseable" = "yes";
          "read only" = "no";
          "guest ok" = "yes";
          "guest only" = "yes";  # Optional: Enforce guests only, no auth
          "create mask" = "0644";
          "directory mask" = "0755";
          # "force user" = "username";
          # "force group" = "groupname";
        };
        # "private" = {
        #   "path" = "/dpool/samba/Private";
        #   "browseable" = "yes";
        #   "read only" = "no";
        #   "guest ok" = "no";
        #   "create mask" = "0644";
        #   "directory mask" = "0755";
        #   "force user" = "username";
        #   "force group" = "groupname";
        # };

        # "my_share" = {
        #   "path" = "/home/jono";
        #   "valid users" = "jono";
        #   "force user" = "jono";
        #   "public" = "no";
        #   "writeable" = "yes";
        # };

        "jono" = {
          path = "/dpool/samba/jono";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "valid users" = "jono";
          comment = "Jono's share";
        };

        "ron" = {
          path = "/dpool/samba/ron";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "valid users" = "ron";
          comment = "Ron's share";
        };

      };
    };

    gatus = {
      enable = true;

      settings = {
  
        web.port = 8005;

        alerting = {
          telegram = {
            token = readSecretFile /etc/gatus-secret-token;
            id = "345186623";
          };
        };

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
            alerts = [{
              type = "telegram";
              description = "healthcheck failed";
              send-on-resolved = true;
            }];
          }
          # {
          #   name = "rokeachphoto bogus";
          #   url = "https://bogus.rokeachphoto.com/";
          #   interval = "1m";
          #   conditions = [
          #     "[STATUS] == 200"
          #   ];
          #   alerts = [{
          #     type = "telegram";
          #     description = "r bogus service healthcheck failed";
          #     send-on-resolved = true;
          #   }];
          # }
          {
            name = "rokeachphoto dgt bridge";
            url = "https://dgt.rokeachphoto.com/bridge/";
            interval = "1m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{
              type = "telegram";
              description = "healthcheck failed";
              send-on-resolved = true;
            }];
          }
          {
            name = "google";
            url = "https://www.google.com/";
            conditions = [
              "[STATUS] == 200"
            ];
          }
          {
            name = "ping 1.1.1.1";
            url = "icmp://1.1.1.1";
            interval = "1m";
            conditions = [
              "[CONNECTED] == true"
            ];
            alerts = [{
              type = "telegram";
              description = "healthcheck failed";
              send-on-resolved = true;
            }];
          }
        ];
      };
    };


    # used to advertise the shares to Windows hosts
    samba-wsdd = {
      enable = true;
      openFirewall = true;
    };

    avahi.publish.userServices = true;


    postgresql = {
      enable = true;
      ensureDatabases = [ "digitus" "carpool" "plausible" ];
      ensureUsers = [
        {
          name = "carpool";
          ensureDBOwnership = true;
          ensureClauses = {
            login = true;
            # password = "looprac";
            createdb = true;
          };
        }
        {
          name = "plausible";
          ensureDBOwnership = true;
        }
      ];

      settings = {
        log_connections = true;
        log_statement = "all";
        logging_collector = true;
        log_disconnections = true;
        # log_destination = lib.mkForce "syslog";
      };  

      authentication = pkgs.lib.mkOverride 10 ''
        #type database DBuser origin-address auth-method
        local all      all     trust
        # ... other auth rules ...

        # ipv4
        host  all      all     127.0.0.1/32   trust
        # ipv6
        host  all      all     ::1/128        trust
      '';

      # TODO: I dont think these users are being created
      initialScript = pkgs.writeText "backend-initScript" ''
        alter user carpool with password 'looprac';
      '';
    };


    # grafana = {
    #   enable = true;
    #   settings = {
    #     server = {
    #       serve_from_sub_path = true;
    #       http_port = 2342;
    #       http_addr = "0.0.0.0";
    #     };
    #   };
    # };


    # prometheus = {
    #   enable = true;

    #   globalConfig.scrape_interval = "10s"; # "1m"
    #   port = 9001;

    #   exporters = {
    #     postgres = {
    #       enable = true;
    #       listenAddress = "0.0.0.0";
    #       port = 9187;
    #     };
    #     node = {
    #       enable = true;
    #       enabledCollectors = [ "systemd" ];
    #       port = 9002;
    #       extraFlags = [
    #         "--collector.ethtool"
    #         "--collector.softirqs"
    #         "--collector.tcpstat"
    #       ];
    #     };
    #   };
    #   scrapeConfigs = [
    #     {
    #       job_name = "node";
    #       static_configs = [{
    #         targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
    #       }];
    #     }
    #   ];

    # };

    # loki = {
    #   enable = true;
    #   configFile = ./files/loki.yaml;
    # };

    # alloy = {
    #   enable = true;
    # };

    #  umami = { # only in unstable. so wait for 25.11 or use docker. or use plausable in nix
    #    enable = true;
    #    createPostgresqlDatabase = true;
    #    settings = {
    #      DATABASE_URL = "postgresql://umami:umami@localhost:5432/umami";
    #      HASH_SALT = "your-hash-salt-here";
    #    };
    #  };

    # plausible = {
    #    enable = true;
    #    server = {
    #      baseUrl = "http://analytics.dgt.is";
    #      port = 8000;
    #      secretKeybaseFile = "/run/secrets/plausible-secret-key-base";
    #    };
    #    database = {
    #       clickhouse.setup = true;
    #       postgres = {
    #         setup = false;
    #         dbname = "plausible";
    #       };
    #    };
    # };

    # clickhouse = {
    #   enable = true;
    # };

    caddy = {
      enable = true;
      # virtualHosts."localhost".extraConfig = ''
      #   respond "Hello, local!"
      # '';

      virtualHosts."http://zeeba".extraConfig = ''
        respond "Hello, zeeba!"
      '';

      virtualHosts."zeeba.dgt.is".extraConfig = ''

          route /sfc* {
            uri strip_prefix /sfc
            reverse_proxy localhost:8080
          }

          route /sfc-stage* {
            uri strip_prefix /sfc-stage
            reverse_proxy localhost:8082
          }
          
          # Default response for other routes
          respond "Hello, zeeba world!"
      '';

      virtualHosts."rokeachphoto.dgt.is".extraConfig = rokeachphotoPhp;
      virtualHosts."dgt.rokeachphoto.com".extraConfig = rokeachphotoPhp;
    };

    phpfpm.pools.rokeachphoto = {
      user = "caddy";
      group = "caddy";
      phpPackage = pkgs.php83;
      settings = {
        "listen" = "127.0.0.1:9000";
        "pm" = "dynamic";
        "pm.max_children" = 5;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 3;
      };
    };
  };

  environment.etc."alloy/config.alloy".text = ''
      loki.write "default" {
        endpoint {
          url = "http://127.0.0.1:3100/loki/api/v1/push"
        }
      }
      loki.relabel "zeeba_journal" {
        forward_to = []
        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label = "systemd_unit"
        }
        rule {
          source_labels = ["__journal_syslog_identifier"]
          target_label = "syslog_identifier"
        }
      }

      loki.source.journal "zeeba_journal" {
        forward_to = [loki.write.default.receiver]
        relabel_rules = loki.relabel.zeeba_journal.rules
        // format_as_json = true
      }

      loki.source.journal "systemd" {
        max_age    = "24h"
        forward_to = [loki.write.default.receiver]
      }
    '';

  environment.systemPackages = with pkgs; [
    php83
    php83Packages.composer
  ];
}
