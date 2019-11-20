{ config, lib, pkgs, ... }:

# TODO DB_PASSWORD=$(head -n1 ${cfg.database.passwordFile})
# TODO Assert on password prescence
# TODO db password is visible during db creation

with lib;

let
  cfg = config.services.oar;
  pgSuperUser = config.services.postgresql.superUser;

  configFile = pkgs.writeTextDir "oar.conf"
    ''
      
    '';

  etcOar = pkgs.symlinkJoin {
    name = "etc-oar";
    paths = [ configFile ] ++ cfg.extraConfigPaths;
  };

in

{

  ###### interface

  meta.maintainers = [ maintainers.augu5te ];

  options = {
    services.oar = {

      package = mkOption {
        type = types.package;
        default = pkgs.nur.repos.augu5te.oar;
        defaultText = "pkgs.nur.repos.augu5te.oar";
      };
      database = {
        username = mkOption {
          type = types.str;
          default = "oar";
          description = "Username for the postgresql connection";
        };
        host = mkOption {
          type = types.str;
          default = "localhost";
          description = ''
            Host of the postgresql server. 
          '';
        };

        passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/keys/oar-dbpassword";
        description = ''
          A file containing the password corresponding to
          <option>database.user</option>.
        '';
        };
        
        dbname = mkOption {
          type = types.str;
          default = "oar";
          description = "Name of the postgresql database";
        };
      };

      extraConfig = mkOption {
        default = "";
        type = types.lines;
        description = ''
          Extra configuration options that will be added verbatim at
          the end of the slurm configuration file.
        '';
      };
      
      extraConfigPaths = mkOption {
        type = with types; listOf path;
        default = [];
        description = ''
          Add extra nix store
          paths that should be merged into same directory as
          <literal>oar.conf</literal>.
        '';
      };

      client = {
        enable = mkEnableOption "OAR client";
      };
      
      node = {
        enable = mkEnableOption "OAR node";
      };
      
      server = {
        enable = mkEnableOption "OAR server";
      };
      dbserver = {
        enable = mkEnableOption "OAR database";
      };
    };
  };
  ###### implementation
  
  config =  mkIf ( cfg.client.enable ||
                   cfg.node.enable ||
                   cfg.server.enable ||
                   cfg.dbserver.enable ) {

    # oar user declaration
    
    users.users.oar = mkIf ( cfg.node.enable || cfg.server.enable )  {
      description = "OAR user";
      group = "oar";
      uid = 745;
    };
    users.groups.oar.gid = mkIf ( cfg.node.enable || cfg.server.enable) 735;

    
    systemd.services.oar-conf-init = {
      wantedBy = [ "network.target" ];
      #partOf = [ "activemq.service" ];
      before = [ "network.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /etc/oar
        cat <<EOF > /etc/oar/oar.conf
        #
        # Database type ("mysql" or "Pg")
        DB_TYPE="Pg"

        # DataBase hostname
        DB_HOSTNAME="localhost"
        
        # DataBase port
        DB_PORT="5432"
        
        # Database base name
        DB_BASE_NAME="oar"
        
        # DataBase user name
        DB_BASE_LOGIN="oar"
        
        # DataBase user password
        DB_BASE_PASSWD="oar"
        
        # DataBase read only user name
        DB_BASE_LOGIN_RO="oar_ro"
        
        # DataBase read only user password
        DB_BASE_PASSWD_RO="oar_ro"
        
        # OAR server hostname
        SERVER_HOSTNAME="server"

        # OAR server port
        SERVER_PORT="6666"
        
        # when the user does not specify a -l option then oar use this
        OARSUB_DEFAULT_RESOURCES="/resource_id=1"


        EOF
      '';
    };

    ################
    # Server section
    systemd.services.oar-server =  mkIf (cfg.server.enable) {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      description = "OAR server's main processes";
      restartIfChanged = false;
      environment.OARDIR = "${cfg.package}/bin";
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/oar3-almighty";
        KillMode = "process";
        Restart = "on-failure";
      };
    };  
    
    ##################
    # Database section 
    
    services.postgresql = mkIf cfg.dbserver.enable {
      enable = true;
      enableTCPIP = true;
    };

    #networking.firewall.allowedTCPPorts = mkIf cfg.dbserver.enable [5432];
        
    systemd.services.oardb-init = mkIf (cfg.dbserver.enable) {
      #pgSuperUser = config.services.postgresql.superUser;
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];
      description = "OARD DB initialization";
      path = [ config.services.postgresql.package ];

      wantedBy = [ "multi-user.target" ];
      # TODO DB_PASSWORD=$(head -n1 ${cfg.database.passwordFile})
      script = ''
        DB_PASSWORD=oar 
        mkdir -p /var/lib/oar
        if [ ! -f /var/lib/oar/db-created ]; then
          ${pkgs.sudo}/bin/sudo -u ${pgSuperUser} psql postgres -c "create role ${cfg.database.username} with login password '$DB_PASSWORD'";
          ${pkgs.sudo}/bin/sudo -u ${pgSuperUser} psql postgres -c "create database ${cfg.database.dbname} with owner ${cfg.database.username}";
              
          PGPASSWORD=$DB_PASSWORD ${pkgs.postgresql}/bin/psql -U ${cfg.database.username} \
            -f ${cfg.package}/setup/pg_structure.sql\
            -h localhost ${cfg.database.dbname}
          touch /var/lib/oar/db-created
        fi
        '';
      serviceConfig.Type = "oneshot";
    };   
  };
}


















