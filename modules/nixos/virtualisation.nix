{ pkgs, lib, ... }:

{
  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        swtpm.enable = true;
      };
    };
  };

  programs.virt-manager.enable = true;

  users.users.seevser.extraGroups = lib.mkAfter [ "libvirtd" "kvm" ];
}
