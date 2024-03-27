+++
title = "Proxmox Console Redirect with systemd-boot bootloader"
author = ["Franta Bartik"]
draft = false
+++

## How to setup Proxmox to redirect console {#how-to-setup-proxmox-to-redirect-console}

This is an example that works on my Dell Poweredge R630 and will probably work on many other servers (provided they use the same serial settings, like baud rate 115200).


### Prerequisites {#prerequisites}

1.  Your server is using `systemd-boot` (and not GRUB).
    -   This is easy to check in the OS, like this:

<!--listend-->

```sh
$ efibootmgr -v
BootCurrent: 000A
BootOrder: 000A,0008,0007,0009,0005
[SNIP]
Boot0007* EFI DVD/CDROM 1       PciRoot(0x0)/Pci(0x1f,0x2)/Sata(5,0,0)
Boot0008* Linux Boot Manager    HD(2,GPT,<SNIP>)/File(\EFI\systemd\systemd-bootx64.efi)
Boot0009* Integrated NIC 1 Port 1 Partition 1   VenHw(<SNIP>)
Boot000A* Linux Boot Manager    HD(2,GPT,<SNIP>)/File(\EFI\systemd\systemd-bootx64.efi)
```

You can see that the system is using the `\EFI\systemd\systemd-bootx64.efi` file to boot the system. My system is using UEFI but it should not matter for this setup, Legacy BIOS should work as well.


### Procedure {#procedure}

1.  Find the file to edit for `systemd-boot` options. On Proxmox, it's in `/etc/kernel/cmdline`.
2.  Insert `console=ttyS0,115200n8` into the file, keeping it a one-line if you already have options in there. My example:

<!--listend-->

```systemd-boot
root=ZFS=rpool/ROOT/pve-1 boot=zfs console=ttyS0,115200n8
```

1.  Update the bootloader settings. You will need root privilege for this.
    ```sh
    $ proxmox-boot-tool refresh
    ```
2.  Reboot the system.


### Result {#result}

You can see if this has worked by opening the serial console on the server. On Dell servers you can `ssh` into the iDRAC and run this command:

```sh
/admin1-> console com2
```

After the reboot and the kernel selection screen, you should see your OS boot and get you to the login prompt.
