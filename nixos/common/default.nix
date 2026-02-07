# A default configuration that applies to all servers.
# Common configuration across *all* the machines
{
  config,
  lib,
  options,
  ...
}:
{

  imports = [
    ../../shared/common/flake.nix
    ./detect-hostname-change.nix
    ./networking.nix
    ./nix.nix
    ./openssh.nix
    ./serial.nix
    ./sudo.nix
    ./update-diff.nix
    ../../shared/common/well-known-hosts.nix
    ./zfs.nix
  ];

  # Create users with https://github.com/nikstur/userborn rather than our perl script.
  # Don't enable if we detect impermanence, which is not compatible with it if default settings are used
  # https://github.com/nix-community/impermanence/pull/223
  services.userborn.enable = lib.mkIf (
    !(options.environment ? persistence)
  ) (lib.mkDefault true);

  # Guard against subuids/subgids which userborn does not support.
  # This is checked via assertion rather than mkIf to avoid an infinite
  # recursion: reading config.users.users in the mkIf condition creates a
  # cycle through nix.settings -> nix-required-mounts -> systemd.tmpfiles
  # -> userborn -> services.userborn.enable.
  # https://github.com/nikstur/userborn/issues/7
  assertions = [
    {
      assertion =
        config.services.userborn.enable
        -> !(lib.any (u: u.subUidRanges != [ ] || u.autoSubUidGidRange) (
          lib.attrValues config.users.users
        ));
      message = ''
        services.userborn.enable is true, but some users have subUidRanges
        or autoSubUidGidRange set. userborn does not support these features.
        Either set services.userborn.enable = false or remove the subUid/subGid
        configuration. See https://github.com/nikstur/userborn/issues/7
      '';
    }
  ];

  # Use systemd during boot as well except:
  # - systems with raids as this currently require manual configuration: https://github.com/NixOS/nixpkgs/issues/210210
  # - for containers we currently rely on the `stage-2` init script that sets up our /etc
  boot.initrd.systemd.enable = lib.mkDefault (!config.boot.swraid.enable && !config.boot.isContainer);

  # Don't install the /lib/ld-linux.so.2 stub. This saves one instance of nixpkgs.
  environment.ldso32 = null;

  # Ensure a clean & sparkling /tmp on fresh boots.
  boot.tmp.cleanOnBoot = lib.mkDefault true;
}
