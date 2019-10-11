{ stdenv, fetchgit, python37Packages, pkgs, zeromq }:

python37Packages.buildPythonApplication rec {
  pname = "batsky";
  version = "0.1.0";
  
  src = fetchgit {
    url = /home/auguste/dev/batsky;
    # echo controller
    #sha256 = "00jbsb140b1662akzzrlm3pd8g3jnjmf1276rxzl6k7x788hh0m5";
    #rev = "c216ea3ea3d10e244c651dfaad7649f56d7c9e7f";
    # fast2
    sha256 = "17lakcbdfpwi6d8648cb7x6hmm0vylry2336zb901fl04h7d5l75";
    rev = "d18cac7666fdea9d07383fca2097dc06c6c079b5";
    
  };
  #src = fetchFromGitHub {
  #  owner = "oar-team";
  #  repo = "batsky";
  #  rev = "";
  #  sha256 = "";
  #};

  propagatedBuildInputs = with python37Packages; [
    click
    pyinotify
    pyzmq
    clustershell
    sortedcontainers
  ];

  # Tests do not pass
  doCheck = false;

  meta = with stdenv.lib; {
    description = "";
    homepage    = https://github.com/oar-team/batsky;
    platforms   = platforms.unix;
    licence     = licenses.gpl2;
    longDescription = ''
    '';
  };
}
