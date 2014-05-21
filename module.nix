{ config, pkgs, ... }:
let
  inherit (pkgs.lib) mkOption mkIf types;
  cfg = config.services.cgroups_api;
in {
  options = {
    services.cgroups_api = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = "Enable the RESTful cgroups web service";
      };

      package = mkOption {
        default = pkgs.callPackage ./default.nix { };
        type = types.package;
        description = "The built cgroups package";
      };

      spawn_fcgi = mkOption {
        default = pkgs.callPackage ./spawn-fcgi.nix { }; # XXX: rework after #2695
        type = types.package;
        description = "The built spawn-fcgi to use";
      };

      socket = mkOption {
        type = types.path;
        description = "Path  to  the  Unix  domain socket to bind to";
      };

      socketUser = mkOption {
        description = "Change user of the Unix domain socket";
      };

      socketGroup = mkOption {
        description = "Change group of the Unix domain socket";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.cgroups_api = {
      description = "RESTful interface to cgroups";
      before = [ "nginx.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "forking";
        ExecStart = "${cfg.spawn_fcgi}/bin/spawn-fcgi -s ${cfg.socket} -U ${cfg.socketUser} -G ${cfg.socketGroup} -- ${cfg.package}/bin/cgroups";
        Restart = "on-abort";
      };
    };
  };
}
