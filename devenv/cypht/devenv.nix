# run > devenv shell
#  > devenv up  # for services


# Move to a flake, so config could be moved to another directory. https://discourse.nixos.org/t/change-devenv-root-path-for-devenv/26213/4

# trying to solve this with a symlink did not work and gave errer:
#        error: access to path '/home' is forbidden because it is not under Git control; maybe you should 'git add' it to the repository '/home/jono/src/cypht'?

{ pkgs, lib, config, ... }:

let
  app = "phpdemo";
  domain = "${app}.example.com";
  dataDir = "/srv/http/${domain}";
  app_dir = builtins.toString ./.;
in {

  dotenv.enable = true;
  dotenv.filename = ".env.local";

  enterShell = ''
      if [[ ! -d vendor ]]; then
        # composer update
        composer install
      fi
  '';

  languages.php.enable = true;

  languages.php.fpm.settings = {
    "error_log" = "/dev/stderr";
  };

  languages.php.fpm.pools = {

    mypool = {
      settings = {
        "pm" = "dynamic";
        "pm.max_children" = 75;
        "pm.start_servers" = 3;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 20;
        "pm.max_requests" = 500;
        "listen"="127.0.0.1:9000";
        "php_admin_value[error_log]" = "stderr";
        "php_admin_flag[log_errors]" = true;
        "catch_workers_output" = true;
        # "access.log" = "/dev/stdout";
      };
    };

    # TODO: get this to log to process compose out
    #   until then: tail -f .devenv/state/php-fpm/php-fpm.log 

  };

  services.caddy.enable = true;
  services.caddy.virtualHosts.":8000" = {
    extraConfig = ''
      # root * ${app_dir}
      root * /home/jono/src/cypht
#      php_fastcgi unix/${config.languages.php.fpm.pools.mypool.socket}
      php_fastcgi 127.0.0.1:9000
      file_server
    '';
  };


  # TODO: figure out how to get nginx working instead of caddy
  services.nginx.enable = true;
  services.nginx.httpConfig = ''
  	  # server {
      #   listen 8888;
      #   location /hi/ {
      #     return 200 "Hello, world!";
      #   }
      # }

    	server {
        listen 8500;
        server_name localhost;
        index index.php;
        root /home/jono/src/cypht;
#        root ./;
        client_max_body_size 60M;
        location / {
          try_files $uri /index.php$is_args$args;
        }
        location ~ \.php {
          try_files $uri =404;
          fastcgi_split_path_info ^(.+\.php)(/.+)$;
          # include fastcgi_params;
          # include fcgi.conf;
          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          fastcgi_param SCRIPT_NAME $fastcgi_script_name;
          fastcgi_index index.php;
          fastcgi_pass 127.0.0.1:9000;
        }
      }
  '';


  # services.phpfpm.pools.${app} = {
  #   user = app;
  #   settings = {
  #     # "listen.owner" = config.services.nginx.user;
  #     "pm" = "dynamic";
  #     "pm.max_children" = 32;
  #     "pm.max_requests" = 500;
  #     "pm.start_servers" = 2;
  #     "pm.min_spare_servers" = 2;
  #     "pm.max_spare_servers" = 5;
  #     "php_admin_value[error_log]" = "stderr";
  #     "php_admin_flag[log_errors]" = true;
  #     "catch_workers_output" = true;
  #   };
  #   phpEnv."PATH" = lib.makeBinPath [ pkgs.php81 ];
  # };
  # # services.nginx = {
  # #   enable = true;
  # #   virtualHosts.${domain}.locations."/" = {
  # #     root = dataDir;
  # #     extraConfig = ''
  # #       fastcgi_split_path_info ^(.+\.php)(/.+)$;
  # #       fastcgi_pass unix:${config.services.phpfpm.pools.${app}.socket};
  # #       include ${pkgs.nginx}/conf/fastcgi.conf;
  # #     '';
  # #    };
  # # };
  # users.users.${app} = {
  #   isSystemUser = true;
  #   createHome = true;
  #   home = dataDir;
  #   group  = app;
  # };
  # users.groups.${app} = {};


# databases
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;

    ensureUsers = [{
        name = "cypht";
        password = "cypht_password";
        ensurePermissions = {
          "*.*" = "ALL PRIVILEGES";
        };
      }];

    initialDatabases = [{
        name = "cypht";
      }];

  };

  packages = [
    (pkgs.php81.buildEnv {
      extensions = ({ enabled, all }: enabled ++ (with all; [
        xdebug
        gd
        xmlwriter
        tokenizer
        session
        fileinfo
        dom
        pdo
        pdo_mysql
      ]));
      extraConfig = ''
        xdebug.mode=debug
      '';
    })

    pkgs.php81Packages.composer

    pkgs.freetype
    pkgs.libpng
    pkgs.libjpeg
    pkgs.libxml2

    pkgs.sqlite
    pkgs.phpunit

    # pkgs.fcgi # for testing that php-fpm is working
    # $ SCRIPT_NAME=/phpinfo.php SCRIPT_FILENAME=/phpinfo.php REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:8000

  ];

}
