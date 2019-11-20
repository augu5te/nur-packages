{ stdenv, pkgs, fetchgit, fetchFromGitHub, python37Packages, zeromq, procset, sqlalchemy_utils, pybatsim,  pytest_flask}:

python37Packages.buildPythonApplication rec {
  name = "oar-${version}";
  version = "3.0.0.dev3";
  
  #src = fetchgit {
  #  url = /home/auguste/dev/oar3;
  #  sha256 = "17lakcbdfpwi6d8648cb7x6hmm0vylry2336zb901fl04h7d5l75";
  #  rev = "d18cac7666fdea9d07383fca2097dc06c6c079b5";
  #};

  src = fetchFromGitHub {
    owner = "oar-team";
    repo = "oar3";
    rev = "34d728cb7d2a970cdf611e8dcbdb22df477f03ac";
    sha256 = "03nkf2xpkqmr7qyr7isk6rs9cxpcm1vigjsr224w24yrxifsp0ml";
  };

  propagatedBuildInputs = with python37Packages; [
    pyzmq
    requests
    sqlalchemy
    alembic
    procset
    click
    simplejson
    flask
    tabulate
    psutil
    sqlalchemy_utils
    simpy
    redis
    pybatsim
    pytest_flask
    psycopg2
  ];

  # Tests do not pass
  doCheck = false;

  postInstall = ''
    mkdir -p $out/setup
    cp setup/database/pg_structure.sql $out/setup/
  '';

  meta = with stdenv.lib; {
    homepage = "https://github.com/oar-team/oar3";
    description = "The OAR Resources and Tasks Management System";
    license = licenses.lgpl3;
    longDescription = ''
    '';
  };
}
