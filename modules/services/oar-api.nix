{ config, lib, pkgs, ... }:
with lib;
let
  python = pkgs.python3Packages.python;
  gunicorn = pkgs.python3Packages.gunicorn;
  flask = pkgs.python3Packages.flask;
  werkzeug = pkgs.python3Packages.werkzeug;
  cfg = config.services.oar-api;
  test_flask = pkgs.writeText "test.py" ''
    from flask import Flask, escape, request
    #from werkzeug.contrib.fixers import ProxyFix
    import os
    
    app = Flask(__name__)
    #app.wsgi_app = ProxyFix(app.wsgi_app)

    @app.route('/')
    def hello():
      #name = request.args.get("name", "World")
      name = str(request.environ) 
      return f'Hello, {escape(name)}!'
    '';

in
{
  meta.maintainers = [ maintainers.augu5te ];

  options = {
    services.oar-api = {
      enable = mkEnableOption "OAR Rest API";
    };
  };
  
  config = mkIf cfg.enable {
    systemd.services.oar-api = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      restartIfChanged = true;
      
      environment = let
        penv = python.buildEnv.override {
        extraLibs = [ flask werkzeug ];
      };
    in {
        PYTHONPATH= "${penv}/${python.sitePackages}/";
      };
  
      serviceConfig = {
        Type = "simple";
        ExecStart = ''env FLASK_APP=${test_flask} ${python}/bin/python -m flask run '';        
      };
    };  
  };
}
