{
  description = "get-flox development flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      mkShellFor = system: let pkgs = import nixpkgs { inherit system; }; in
        pkgs.mkShell {
          buildInputs = with pkgs; [ bash curl wget gnupg coreutils which shellcheck ];
          shellHook = ''
            echo "Entering get-flox dev shell on ${system}"
            echo "Run: ./install.sh --help (script is non-interactive)"
          '';
        };
    in
    {
      devShells = builtins.listToAttrs (map (system: {
        name = system;
        value = mkShellFor system;
      }) systems);
    };
}
