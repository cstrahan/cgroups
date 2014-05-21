{ config, pkgs, ... }:

# Stitch it all together and give it a spin.

let
  nginx = config.services.nginx.package;
  socket = config.services.cgroups_api.socket;
  port = 80;
  fastcgiParams = pkgs.writeText "fastcgi_params" ''
    fastcgi_param  QUERY_STRING       $query_string;
    fastcgi_param  REQUEST_METHOD     $request_method;
    fastcgi_param  CONTENT_TYPE       $content_type;
    fastcgi_param  CONTENT_LENGTH     $content_length;
    fastcgi_param  PATH_INFO          $fastcgi_script_name;
    fastcgi_param  SERVER_PROTOCOL    $server_protocol;
    fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
    fastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;
    fastcgi_param  REMOTE_ADDR        $remote_addr;
    fastcgi_param  SERVER_ADDR        $server_addr;
    fastcgi_param  SERVER_PORT        $server_port;
    fastcgi_param  SERVER_NAME        $server_name;
 '';
in {
  imports = [
    ./module.nix
  ];

  services.cgroups_api = {
    enable = true;
    socket = "/tmp/cgroups.sock";
    socketUser   = config.services.nginx.user;
    socketGroup  = config.services.nginx.group;
  };

  services.nginx = {
    enable = true;

    httpConfig = ''
      include       ${nginx}/conf/mime.types;
      default_type  application/octet-stream;
      access_log    access.log;
      sendfile      on;

      server {
        listen       ${toString port};
        server_name  localhost;
        location / {
          fastcgi_pass   unix:${socket};
          include        ${fastcgiParams};
        }
      }
    '';
  };
}
