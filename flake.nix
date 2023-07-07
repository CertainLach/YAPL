{
  description = "Auth service";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };
      in rec {
        devShell = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            (perl.withPackages (p:
              with p; [
                IPCRun
                StringUtil
              ]))
          ];
        };
      }
    );
}
