{
  description = "vereis.com";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs.lib) optional optionals;

        beamPackages = pkgs.beam.packages.erlang_28;
        elixir = beamPackages.elixir_1_19;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            elixir
            beamPackages.erlang
            pkgs.nodejs_22
            pkgs.sqlite
            pkgs.sqlite-utils
            pkgs.git
            pkgs.gnumake
          ] ++ optional pkgs.stdenv.isLinux pkgs.inotify-tools
            ++ optional pkgs.stdenv.isDarwin pkgs.terminal-notifier
            ++ optionals pkgs.stdenv.isDarwin (with pkgs.darwin.apple_sdk.frameworks; [
              CoreFoundation
              CoreServices
            ]);

          shellHook = ''
            export LANG=en_US.UTF-8
            export LC_ALL=en_US.UTF-8
            export ERL_AFLAGS="-kernel shell_history enabled";
            export MIX_HOME=$PWD/.nix-mix
            export HEX_HOME=$PWD/.nix-hex
            export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
            mkdir -p $MIX_HOME $HEX_HOME
          '';
        };
      }
    );
}
