with (import <nixpkgs> {});
mkShell {
  buildInputs = [ bash curl wget gnupg coreutils which shellcheck ];
  shellHook = ''
    echo "Entering get-flox legacy nix-shell"
    echo "Use: nix develop or nix-shell"
  '';
}
