{
  description = "vereis.com";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    git-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      git-hooks,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs.lib) optional optionals;

        beamPackages = pkgs.beam.packages.erlang_28;
        elixir = beamPackages.elixir_1_19;

        pre-commit-check = git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            treefmt = {
              enable = true;
              package = pkgs.writeShellApplication {
                name = "treefmt";
                runtimeInputs = [
                  pkgs.treefmt
                  pkgs.nixfmt
                  pkgs.shfmt
                ];
                text = ''
                  exec treefmt "$@"
                '';
              };
            };

            deadnix = {
              enable = true;
              settings = {
                edit = false;
              };
            };

            statix = {
              enable = true;
              settings = {
                format = "stderr";
              };
            };

            shellcheck = {
              enable = true;
              package = pkgs.shellcheck;
              excludes = [ ".envrc" ];
            };

            convco = {
              enable = true;
              package = pkgs.convco;
            };

            validate-branch-commits = {
              enable = true;
              name = "validate-branch-commits";
              entry = "${pkgs.writeShellScript "validate-branch-commits" ''
                if [ -n "''${IN_NIX_SHELL:-}" ] || [ -z "''${NIX_BUILD_TOP:-}" ]; then
                  set -euo pipefail
                  BASE_BRANCH="''${BASE_BRANCH:-main}"
                  COMMITS=$(git log --format="%H" "origin/$BASE_BRANCH..HEAD" 2>/dev/null || git log --format="%H" HEAD)
                  if [ -z "$COMMITS" ]; then
                    exit 0
                  fi
                  FAILED=0
                  while IFS= read -r commit; do
                    MSG=$(git log --format=%B -n 1 "$commit")
                    if ! echo "$MSG" | ${pkgs.convco}/bin/convco check --from-stdin >/dev/null 2>&1; then
                      echo "Invalid commit message in $commit:"
                      echo "$MSG"
                      FAILED=1
                    fi
                  done <<<"$COMMITS"
                  if [ $FAILED -eq 1 ]; then
                    echo ""
                    echo "Tip: Use 'git rebase -i origin/$BASE_BRANCH' to fix commit messages"
                    exit 1
                  fi
                else
                  exit 0
                fi
              ''}";
              pass_filenames = false;
            };

            mix-lint = {
              enable = true;
              name = "mix-lint";
              entry = "${pkgs.writeShellScript "mix-lint" ''
                if [ -n "''${IN_NIX_SHELL:-}" ] || [ -z "''${NIX_BUILD_TOP:-}" ]; then
                  cd "$(git rev-parse --show-toplevel)/api"
                  export MIX_HOME="''${MIX_HOME:-$PWD/../.nix-mix}"
                  export HEX_HOME="''${HEX_HOME:-$PWD/../.nix-hex}"
                  ${elixir}/bin/mix lint
                else
                  exit 0
                fi
              ''}";
              files = "\\.(ex|exs)$";
              pass_filenames = false;
            };

            mix-test = {
              enable = true;
              name = "mix-test";
              entry = "${pkgs.writeShellScript "mix-test" ''
                if [ -n "''${IN_NIX_SHELL:-}" ] || [ -z "''${NIX_BUILD_TOP:-}" ]; then
                  cd "$(git rev-parse --show-toplevel)/api"
                  export MIX_HOME="''${MIX_HOME:-$PWD/../.nix-mix}"
                  export HEX_HOME="''${HEX_HOME:-$PWD/../.nix-hex}"
                  ${elixir}/bin/mix test --color
                else
                  exit 0
                fi
              ''}";
              files = "\\.(ex|exs)$";
              pass_filenames = false;
            };
          };
        };
      in
      {
        checks = {
          pre-commit = pre-commit-check;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            elixir
            beamPackages.erlang
            pkgs.nodejs_22
            pkgs.sqlite
            pkgs.sqlite-utils
            pkgs.git
            pkgs.gnumake
            pkgs.convco
            pkgs.treefmt
            pkgs.shellcheck
            pkgs.nixfmt
            pkgs.nodePackages.prettier
            pkgs.shfmt
          ]
          ++ optional pkgs.stdenv.isLinux pkgs.inotify-tools
          ++ optional pkgs.stdenv.isDarwin pkgs.terminal-notifier
          ++ optionals pkgs.stdenv.isDarwin (
            with pkgs.darwin.apple_sdk.frameworks;
            [
              CoreFoundation
              CoreServices
            ]
          );

          shellHook = ''
            export LANG=en_US.UTF-8
            export LC_ALL=en_US.UTF-8
            export ERL_AFLAGS="-kernel shell_history enabled";
            export MIX_HOME=$PWD/.nix-mix
            export HEX_HOME=$PWD/.nix-hex
            export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
            mkdir -p $MIX_HOME $HEX_HOME

            ${pre-commit-check.shellHook}
          '';
        };
      }
    );
}
