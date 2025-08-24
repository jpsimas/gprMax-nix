{ pkgs ? import <nixpkgs> {} }:

let
  # Build gprMax with the desired options
  gprMax = pkgs.callPackage ./gprMax.nix {
    enableCuda = true;
    enableMpi = true;
    enableNative = true;
  };

  # Python environment with all gprMax dependencies
  pythonWithDeps = pkgs.python3.withPackages (ps: with ps; [
    colorama
    cython
    h5py
    jupyter
    matplotlib
    numpy
    psutil
    scipy
    terminaltables
    tqdm
    # Optional GPU dependencies
    # pycuda    # Uncomment for CUDA
    # pyopencl  # Uncomment for OpenCL
    gprMax
  ]);

in pkgs.mkShell {
  name = "gprMax-dev-shell";

  # The built gprMax package and Python with dependencies
  packages = [
    pythonWithDeps
    pkgs.gcc

  ];

  # Build inputs for development
  buildInputs = [
    pkgs.zlib
    pkgs.stdenv.cc.cc.lib
  ] ++ (with pkgs; [
    # GPU development tools (optional)
    ocl-icd
    opencl-headers
  ]);

  # Environment variables
  shellHook = ''
    echo "gprMax development shell"
    echo "gprMax package: ${gprMax}"
    echo "Python with dependencies: ${pythonWithDeps}"
    
    # Add gprMax to Python path
    export PYTHONPATH=${gprMax}/${pythonWithDeps.sitePackages}:$PYTHONPATH
    
    # Set compiler flags
    export NIX_CFLAGS_COMPILE="-fopenmp $NIX_CFLAGS_COMPILE"
    export NIX_LDFLAGS="-fopenmp $NIX_LDFLAGS"
    
    # Set library paths
    export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH"
    
    # Test commands
    echo ""
    echo "Available commands:"
    echo "  python -c \"import gprMax; print('gprMax imported successfully')\""
    echo "  python -m gprMax --help"
    echo ""
  '';

  # Enable core dumps and better debugging
  hardeningDisable = [ "all" ];
}

