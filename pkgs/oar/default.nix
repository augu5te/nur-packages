{ stdenv, pkgs, fetchgit, fetchFromGitHub, python37Packages, zeromq, procset, sqlalchemy_utils, pybatsim,  pytest_flask}:

python37Packages.buildPythonPackage rec {
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
    rev = "72e13645377e72c5cca8324bd7e0a6f91ffe8777";
    sha256 = "05x0nkxfgb4i6k6gyrbwly35i2h36njqchrcbblqn67pgclj0cp1";
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
    cp -r setup $out
    cp -r oar/tools $out
  '';

  meta = with stdenv.lib; {
    homepage = "https://github.com/oar-team/oar3";
    description = "The OAR Resources and Tasks Management System";
    license = licenses.lgpl3;
    longDescription = ''
    '';
  };
}
