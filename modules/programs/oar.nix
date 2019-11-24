{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.programs.oar;
in {
  options.programs.oar = {
    enable = mkEnableOption "oar";


    
  };
  config = mkIf cfg.enable {
    security.wrappers.oarstat = {
      source = "${pkgs.nur.repos.augu5te.oar}/bin/oarstat3";
      owner = "root";
      group = "root";
      setuid = true;
      permissions = "u+rx,g+x,o+x";
    };
  };
}
