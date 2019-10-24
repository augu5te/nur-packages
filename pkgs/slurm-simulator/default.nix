{ stdenv, fetchFromGitHub, pkgconfig, libtool, curl
, python, munge, perl, pam, openssl, zlib
, ncurses, libmysqlclient, lua, hwloc, numactl
, readline, freeipmi, libssh2, lz4, autoconf, automake, gtk2
}:

stdenv.mkDerivation rec {
  pname = "slurm-simulator";
  version = "bsc_simulator_v14";

  # N.B. We use github release tags instead of https://www.schedmd.com/downloads.php
  # because the latter does not keep older releases.
  src = fetchFromGitHub {
    owner = "BSC-RM";
    repo = "slurm_simulator";
    
    # bsc_simulator_v14
    rev = "91d0b7145a15b071eff26b8d4b95a23c008a4550"; #
    sha256 = "0rhq4cbmppd79bvasyvd59ki0s6r5d8iqm2xpmgc045qvgjlmabk";
    
    # bsc_simulator_v17
    # rev = "cdef8c5cdfe0ba3e548e01e6d8e52ac2fb82bcfd"; #
    # sha256 = "1c05rqvdd39y3zbrv4y4adrfvcl18s00avfj4j49ap9xp6z83138";
  };

  outputs = [ "out" "dev" ];

  # nixos test fails to start slurmd with 'undefined symbol: slurm_job_preempt_mode'
  # https://groups.google.com/forum/#!topic/slurm-devel/QHOajQ84_Es
  # this doesn't fix tests completely at least makes slurmd to launch
  hardeningDisable = [ "bindnow" ];

  nativeBuildInputs = [ pkgconfig libtool ];
  buildInputs = [
    curl python munge perl pam openssl zlib
      libmysqlclient ncurses lz4 
      lua hwloc numactl readline #];
  autoconf automake gtk2];
 
  preBuild = ''
    makeFlagsArray+=("CFLAGS=-DSLURM_SIMULATOR -g0 -O2 -D NDEBUG=1 -DNUMA_VERSION1_COMPATIBILITY -pthread -lrt")
  '';

  #makeFlags = ''CFLAGS="-D SLURM_SIMULATOR -g0 -O3 -D NDEBUG=1"'';
  #makeFlags = "CFLAGS=-DSLURM_SIMULATOR";
  configureFlags = with stdenv.lib;
    [ #"--with-hwloc=${hwloc.dev}"
      "--with-lz4=${lz4.dev}"
      "--with-ssl=${openssl.dev}"
      "--with-zlib=${zlib}"
      "--sysconfdir=/etc/slurm"
      "--enable-front-end"
      "--disable-debug"
      "--enable-simulator" 
    ];

  preConfigure = ''
    patchShebangs ./doc/html/shtml2html.py
    patchShebangs ./doc/man/man2html.py
    ./autogen.sh
  '';

  postInstall = ''
    rm -f $out/lib/*.la $out/lib/slurm/*.la
  '';

  enableParallelBuilding = true;

  meta = with stdenv.lib; {
    homepage = http://www.schedmd.com/;
    description = "Simple Linux Utility for Resource Management";
    platforms = platforms.linux;
    license = licenses.gpl2;
    maintainers = with maintainers; [ jagajaga markuskowa ];
  };
}
