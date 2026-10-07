{
  description = "Update flake.lock with a cooldown on third-party inputs";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
  let
    inherit (nixpkgs) lib;
    forAllSystems = lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
  in
  {
    # For flakes updated outside GitHub Actions: run `nix run github:yawkat/flake-cooldown` in the flake directory,
    # with COOLDOWN_DAYS and EXEMPT_OWNER in the environment as needed.
    packages = forAllSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.runCommand "flake-cooldown" {
          nativeBuildInputs = [ pkgs.makeWrapper ];
          buildInputs = [ pkgs.python3 ];
          meta.mainProgram = "flake-cooldown";
        } ''
          install -Dm755 ${./cooldown_update.py} $out/bin/flake-cooldown
          patchShebangs $out/bin
          # The nix already on PATH comes first: it is the one that knows the local nix.conf and lock file format.
          wrapProgram $out/bin/flake-cooldown \
            --prefix PATH : ${lib.makeBinPath [ pkgs.git ]} \
            --suffix PATH : ${lib.makeBinPath [ pkgs.nix ]}
        '';
      });

    checks = forAllSystems (system: { default = self.packages.${system}.default; });
  };
}
