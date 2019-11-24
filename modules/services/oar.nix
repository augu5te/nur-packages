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

oarTools = pkgs.stdenv.mkDerivation {
  name = "oar_tools";
  phases          = [ "installPhase" ];
  buildInputs     = [  ];
  installPhase = ''
      mkdir -p $out/bin

      #oarsh
      substitute ${cfg.package}/tools/oarsh/oarsh.in $out/bin/oarsh \
          --replace /bin/bash ${pkgs.stdenv.shell} \
          --replace "%%OARHOMEDIR%%"  ${cfg.oarHomeDir} \
          --replace "%%XAUTHCMDPATH%%" /run/current-system/sw/bin/xauth \
          --replace /usr/bin/ssh /run/current-system/sw/bin/ssh
      chmod 755 $out/bin/oarsh    
      
      #oarsh_shell
      substitute ${cfg.package}/tools/oarsh/oarsh_shell.in $out/bin/oarsh_shell \
          --replace /bin/bash ${pkgs.stdenv.shell} \
          --replace "%%OARDIR%%" /run/wrappers/bin \
          --replace "%%XAUTHCMDPATH%%" /run/current-system/sw/bin/xauth \
          --replace "$OARDIR/oardodo/oardodo" /run/wrappers/bin/oardodo \
          --replace "%%OARCONFDIR%%" /etc/oar
      chmod 755 $out/bin/oarsh_shell

      #oardodo
      substitute ${cfg.package}/tools/oardodo.c.in oardodo.c\
         --replace "%%OARDIR%%" /run/wrappers/bin \
         --replace "%%OARCONFDIR%%" /etc/oar \
         --replace "%%XAUTHCMDPATH%%" /run/current-system/sw/bin/xauth \
         --replace "%%OAROWNER%%" oar

      $CC -Wall -O2 oardodo.c -o $out/oardodo_toWrap
      
      #oardo -> cli
      gen_oardo () {
        substitute ${cfg.package}/tools/oardo.c.in oardo.c\
           --replace TT/usr/local/oar/oarsub ${pkgs.nur.repos.augu5te.oar}/bin/$1 \
           --replace "%%OARDIR%%" /run/wrappers/bin \
           --replace "%%OARCONFDIR%%" /etc/oar \
           --replace "%%XAUTHCMDPATH%%" /run/current-system/sw/bin/xauth \
           --replace "%%OAROWNER%%" oar \
           --replace "%%OARDOPATH%%"  /run/wrappers/bin:/run/current-system/sw/bin

        $CC -Wall -O2 oardo.c -o $out/$2
      }

      
      # generate cli
      
      a=(oarsub3 oarstat3 oardel3 oarnode3)
      b=(oarsub oarstat oardel oarnode)

      for (( i=0; i<''${#a[@]}; i++ ))
      do
        echo generate ''${b[i]}
        gen_oardo ''${a[i]} ''${b[i]}
      done

    '';
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
      
      oarHomeDir = mkOption {
          type = types.str;
          default = "/var/lib/oar";
          description = "Home for oar user ";
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

    # add package
    environment.systemPackages =  [ oarTools pkgs.xorg.xauth ];
    
    # oardodo
    security.wrappers.oardodo = {
      source = "${oarTools}/oardodo_toWrap";
      owner = "root";
      group = "root";
      setuid = true;
      permissions = "u+rx,g+x,o+x";
    };

    security.wrappers.oarsub = {
      source = "${oarTools}/oarsub";
      owner = "root";
      group = "root";
      setuid = true;
      permissions = "u+rx,g+x,o+x";
    };

    security.wrappers.oarstat = {
      source = "${pkgs.nur.repos.augu5te.oar}/bin/oarstat3";
      owner = "root";
      group = "root";
      setuid = true;
      permissions = "u+rx,g+x,o+x";
    };

    # oar user declaration
    users.users.oar = mkIf ( cfg.client.enable || cfg.node.enable || cfg.server.enable )  {
      description = "OAR user";
      home = cfg.oarHomeDir;
      #shell = pkgs.bashInteractive;
      shell = "${oarTools}/bin/oarsh_shell";
      group = "oar";
      #openssh.authorizedKeys.keys = [ cfg.oarPublicKey ];
      uid = 745;
      # openssh
    };
    users.groups.oar.gid = mkIf ( cfg.client.enable || cfg.node.enable || cfg.server.enable) 735;

    systemd.services.oar-user-init = {
      wantedBy = [ "network.target" ];      
      before = [ "network.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p ${cfg.oarHomeDir}
        echo "[ -f ${cfg.oarHomeDir}/.bash_oar ] && . ${cfg.oarHomeDir}/.bash_oar" > ${cfg.oarHomeDir}/.bashrc
        echo "[ -f ${cfg.oarHomeDir}/.bash_oar ] && . ${cfg.oarHomeDir}/.bash_oar" > ${cfg.oarHomeDir}/.bash_profile
        cat <<EOF > ${cfg.oarHomeDir}/.bash_oar
        #
        # OAR bash environnement file for the oar user
        #
        # /!\ This file is automatically created at update installation/upgrade. 
        #     Do not modify this file.
        #      
        bash_oar() {
          # Prevent to be executed twice or more
          [ -n "$OAR_BASHRC" ] && return
          export PATH="/run/wrappers/bin/:/run/current-system/sw/bin:$PATH"
          OAR_BASHRC=yes
        }
      
        bash_oar
        EOF
      '';
    };

    # TODO CHANGE environment.etc...
    systemd.services.oar-conf-init = {
      wantedBy = [ "network.target" ];
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

    ##############
    # Node Section
    systemd.services.oar-node =  mkIf (cfg.node.enable) {
      description = "OAR's SSH Daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target"];
      stopIfChanged = false;
      path = [ pkgs.openssh ];
      preStart = ''
        # Make sure we don't write to stdout, since in case of
        # socket activation, it goes to the remote side (#19589).
        exec >&2
        if ! [ -f "/etc/oar/oar_ssh_host_rsa_key" ]; then
          ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -N "" -f /etc/oar/oar_ssh_host_rsa_key
        fi   
      '';
      serviceConfig = {
        ExecStart = " ${pkgs.openssh}/bin/sshd -f /srv/sshd.conf";
        KillMode = "process";
        Restart = "always";
        Type = "simple";
      };
    };

    
    ################
    # Server Section
    systemd.services.oar-server =  mkIf (cfg.server.enable) {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target"];
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
            -f ${cfg.package}/setup/database/pg_structure.sql\
            -h localhost ${cfg.database.dbname}
          touch /var/lib/oar/db-created
        fi
        '';
      serviceConfig.Type = "oneshot";
    };   
  };
}


















