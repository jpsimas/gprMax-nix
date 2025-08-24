{ pkgs ? import <nixpkgs> {} }:

let
  gprmax = import ./gprMax.nix { inherit pkgs; };
in

{
  gprMax = gprmax;
}
  
