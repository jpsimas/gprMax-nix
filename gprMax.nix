{ pkgs ? import <nixpkgs> {}
# Enable MPI support
, enableMpi ? true
# Enable CUDA support. Needs NIXPKGS_ALLOW_UNFREE=1 to be set
, enableCuda ? pkgs.config.cudaSupport or false
# Enable march=native at compilation. Needs NIX_ENFORCE_NO_NATIVE=1 to be set
, enableNative ? false 
}:

pkgs.python3Packages.buildPythonPackage rec {
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
    ++ (pkgs.lib.optional enableMpi pkgs.openmpi);

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
    ++ (pkgs.lib.optional enableMpi pkgs.openmpi)
    ++ (pkgs.lib.optional enableCuda pkgs.python3Packages.cupy)  # CUDA Python bindings
    ++ (pkgs.lib.optional enableMpi pkgs.python3Packages.mpi4py);  # MPI Python bindings

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
    
    # Add MPI support if enabled
    ${pkgs.lib.optionalString enableMpi ''
      export CC=${pkgs.openmpi}/bin/mpicc
      export CXX=${pkgs.openmpi}/bin/mpic++
      export NIX_CFLAGS_COMPILE="-I${pkgs.openmpi}/include $NIX_CFLAGS_COMPILE"
      export NIX_LDFLAGS="-L${pkgs.openmpi}/lib $NIX_LDFLAGS"
      export MPI_HOME=${pkgs.openmpi}
    ''}
  '';

  # Setup.py arguments for optional features
  setupPyBuildFlags = [
    "--user"
  ] ++ (pkgs.lib.optional enableCuda "--with-cuda")
    ++ (pkgs.lib.optional enableMpi "--with-mpi")
    ++ (pkgs.lib.optional enableNative "--arch=native");

  # Environment variables for runtime
  preFixup = ''
    ${pkgs.lib.optionalString enableCuda ''
      addToSearchPath LD_LIBRARY_PATH "${pkgs.cudatoolkit}/lib"
      addToSearchPath LD_LIBRARY_PATH "${pkgs.cudatoolkit}/lib64"
    ''}
    ${pkgs.lib.optionalString enableMpi ''
      addToSearchPath LD_LIBRARY_PATH "${pkgs.openmpi}/lib"
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
  
