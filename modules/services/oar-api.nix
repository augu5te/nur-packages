{ config, lib, pkgs, ... }:
with lib;
let
  python = pkgs.python3Packages.python;
  gunicorn = pkgs.python3Packages.gunicorn;
  flask = pkgs.python3Packages.flask;
  cfg = config.services.oar-api;
  test_wsgi = pkgs.writeText "test.wsgi" ''
              import os
              from flask import Flask
              application = Flask(__name__)
              
              @application.route("/")
              def hello():
                 return str(os.environ)
                 #return str(os.environ.get('X_REMOTE_IDENT'))
               '';

  myapp = pkgs.writeTextDir "myapp.py" ''
    import os
    def app(environ, start_response):
        data = (str(os.environ)).encode('utf8')
        start_response("200 OK", [ ("Content-Type", "text/plain"), ("Content-Length", str(len(data)))])
        return iter([data])
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
        extraLibs = [ flask ];
      };
    in {
        PYTHONPATH= "${penv}/${python.sitePackages}/:${myapp}";
      };
       
      
      serviceConfig = {
        Type = "simple";
        ExecStart = ''${gunicorn}/bin/gunicorn myapp:app \
              -u nginx \
              -g nginx \
              --workers 3 --log-level=info \
              --bind=127.0.0.1:9000  \
              --pid /tmp/gunicorn.pid
            '';        
      };
    };  
  };
}
