{ pkgs ? import <nixpkgs> {}
, enableCuda ? pkgs.config.cudaSupport or false
, enableMpi ? true
, enableNative ? false
}:

let
  mpi = pkgs.openmpi;
  
in pkgs.python3Packages.buildPythonPackage rec {
  pname = "gprMax";
  version = "3.1.7";

  src = pkgs.fetchFromGitHub {
    owner = "gprMax";
    repo = "gprMax";
    rev = "v.${version}";
    hash = "sha256-6pcNaf/B9p3pz6iCXzWB24kDnrNDaAL17wMCqodsU5o=";
  };

  nativeBuildInputs = [
    pkgs.python3Packages.cython
    pkgs.pkg-config
  ] ++ (pkgs.lib.optional enableCuda pkgs.cudatoolkit)
    ++ (pkgs.lib.optional enableMpi mpi);

  buildInputs = with pkgs.python3Packages; [
    colorama
    h5py
    matplotlib
    numpy
    psutil
    scipy
    terminaltables
    tqdm
  ] ++ (with pkgs; [
    stdenv.cc.cc.lib
    zlib
  ]) ++ (pkgs.lib.optional enableCuda pkgs.cudatoolkit)
    ++ (pkgs.lib.optional enableMpi mpi)
    ++ (pkgs.lib.optional enableCuda pycuda)
    ++ (pkgs.lib.optional enableMpi mpi4py);

  # Set compiler flags with optional CUDA and MPI
  preConfigure = ''
    # Base OpenMP flags
    export NIX_CFLAGS_COMPILE="-fopenmp $NIX_CFLAGS_COMPILE"
    export NIX_LDFLAGS="-lgomp $NIX_LDFLAGS"
    
    # Let gprMax handle architecture-specific optimization internally
    ${pkgs.lib.optionalString enableNative ''
      echo "Native optimization enabled - gprMax will handle architecture-specific flags"
    ''}
    
    # Add CUDA support if enabled
    ${pkgs.lib.optionalString enableCuda ''
      export NIX_CFLAGS_COMPILE="-I${pkgs.cudatoolkit}/include $NIX_CFLAGS_COMPILE"
      export NIX_LDFLAGS="-L${pkgs.cudatoolkit}/lib -L${pkgs.cudatoolkit}/lib64 $NIX_LDFLAGS"
      export CUDA_HOME=${pkgs.cudatoolkit}
      export CUDA_PATH=${pkgs.cudatoolkit}
    ''}
    
    # Add MPI support if enabled - manually add MPI flags instead of using mpicc
    ${pkgs.lib.optionalString enableMpi ''
      export NIX_CFLAGS_COMPILE="-I${mpi}/include $NIX_CFLAGS_COMPILE"
      export NIX_LDFLAGS="-L${mpi}/lib -lmpi $NIX_LDFLAGS"
      export MPI_HOME=${mpi}
      # Set these for gprMax's build system to detect MPI
      export MPI_INCLUDE_DIR=${mpi}/include
      export MPI_LIB_DIR=${mpi}/lib
    ''}
  '';

  # Environment variables for runtime
  preFixup = ''
    ${pkgs.lib.optionalString enableCuda ''
      addToSearchPath LD_LIBRARY_PATH "${pkgs.cudatoolkit}/lib"
      addToSearchPath LD_LIBRARY_PATH "${pkgs.cudatoolkit}/lib64"
    ''}
    ${pkgs.lib.optionalString enableMpi ''
      addToSearchPath LD_LIBRARY_PATH "${mpi}/lib"
    ''}
  '';

  # Add MPI and CUDA to Python path if enabled
  pythonPath = []
    ++ (pkgs.lib.optional enableCuda pkgs.python3Packages.pycuda)
    ++ (pkgs.lib.optional enableMpi pkgs.python3Packages.mpi4py);

  doCheck = false;

  meta = with pkgs.lib; {
    description = "Electromagnetic Modelling Software based on the Finite-Difference Time-Domain (FDTD) method";
    homepage = "http://www.gprmax.com";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ your-name-here ];
    platforms = platforms.unix;
  };
}
