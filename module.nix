{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.paneru-minimap;
in
{
  options.programs.paneru-minimap.enable = lib.mkEnableOption "paneru strip minimap";

  # The package needs the Darwin SDK. Keep the call inside the guard so a
  # Linux home can import this module and leave it off.
  config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isDarwin) {
    launchd.agents.paneru-minimap = {
      enable = true;
      config = {
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        ProgramArguments = [
          "${pkgs.callPackage ./package.nix { }}/Contents/MacOS/paneru-minimap"
        ];
        EnvironmentVariables.PATH = "${config.home.homeDirectory}/.nix-profile/bin:/usr/bin:/usr/sbin:/bin:/sbin";
      };
    };
  };
}
