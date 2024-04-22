+++
title = "PXE Boot Talos Linux"
author = ["Franta Bartik"]
lastmod = 2024-04-22T15:38:28-04:00
draft = false
+++

This assumes you are using an OPNSense firewall/router.
Procedure taken from [the OPNSense forum](https://forum.opnsense.org/index.php?PHPSESSID=56j44inj9mdmeblhnbmcatnvkk&topic=25003.0) and [syslinux Arch wiki page](https://wiki.archlinux.org/title/syslinux).
Use this for smaller ISOs (100 MB or less), if you don't want to wait for a long time at each boot.
I'm sure a better and more efficient way to boot Talos over network works with `syslinux`, but this is my first try that has worked. I still need to streamline it for booting it automatically without a prompt.


## OPNSense setup {#opnsense-setup}

1.  Install `os-tftp` package. Start TFTP server and bind it to an IP. In the WebGUI, it's in **Services &gt; TFTP.**
2.  SSH into OPNSense and create directory `/usr/local/tftp` (will need sudo privileges).
3.  Create directory `pxelinux.cfg` and a file `pxelinux.cfg/default.`
    ```pxe
    DEFAULT vesamenu.c32
    PROMPT 0
    MENU TITLE PXE Boot Menu (Main)

    LABEL linux
       MENU LABEL Linux
       KERNEL vesamenu.c32
       APPEND pxelinux.cfg/linux
    ```
4.  Create file `pxelinux.cfg/linux`.
    (NOTE: I wanted to boot Talos Linux, so I put the `.iso` in the `/usr/local/tftp` directory.)
    ```pxe
    MENU TITLE PXE Boot Menu (Linux)

    LABEL main-menu
       MENU LABEL Main Menu
       KERNEL vesamenu.c32
       APPEND pxelinux.cfg/default
    LABEL talos-iso
       MENU LABEL Boot Talos 1.7 ISO (PXE)
       KERNEL memdisk
       INITRD ../talos.iso
       APPEND iso
    ```
    `memdisk` is what allows booting ISOs.
5.  For OPNSense 24.x (which is based on FreeBSD 13), you'll need to manually download the syslinux binary.
    1.  `cd` to `/tmp`
    2.  Download the binary:
        ```sh
        wget https://pkg.freebsd.org/FreeBSD:13:amd64/latest/All/syslinux-6.03_1.pkg
        ```
    3.  Extract it:
        ```sh
        sudo tar -C /tmp/syslinux -xvf syslinux-6.03_1.pkg
        ```
    4.  Move the necessary files to `/usr/local/tftp` directory:
        ```sh
        sudo cp /tmp/syslinux/usr/local/share/syslinux/bios/core/lpxelinux.0 /usr/local/tftp/pxelinux.0
        sudo cp /tmp/syslinux/usr/local/share/syslinux/bios/com32/elflink/ldlinux/ldlinux.c32 /usr/local/tftp/
        sudo cp /tmp/syslinux/usr/local/share/syslinux/bios/com32/menu/vesamenu.c32 /usr/local/tftp/
        sudo cp /tmp/syslinux/usr/local/share/syslinux/bios/com32/lib/libcom32.c32 /usr/local/tftp/
        sudo cp /tmp/syslinux/usr/local/share/syslinux/bios/com32/libutil/libutil.c32 /usr/local/tftp/
        sudo cp /tmp/syslinux/usr/local/share/syslinux/bios/com32/modules/pxechn.c32 /usr/local/tftp/
        sudo cp /tmp/syslinux/usr/local/share/syslinux/bios/memdisk/memdisk /usr/local/tftp/
        ```
6.  In the same subnet as you bound the TFTP to, set up the DHCP settings. You will need the TFTP server address and the bootfile (`pxelinux.0` for syslinux).
