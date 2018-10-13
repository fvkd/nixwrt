{ targetBoard
, rsyncPassword ? "urbancookie"
, myKeys ? "ssh-rsa AAAAATESTFOOBAR dan@example.org"
, sshHostKey ? ./fake_ssh_host_key }:
let nixwrt = (import ./nixwrt/default.nix) { inherit targetBoard; }; in
with nixwrt.nixpkgs;
let
    baseConfiguration = {
      hostname = "arhcive";
      interfaces = {
        # this is set up for a GL.inet router, you'd have to edit it for another
        # target that has its LAN port somewhere else
        "eth0.2" = {
          type = "vlan"; id = 2; parent = "eth0"; depends = [];
        };
        "eth0" = { } ;
        lo = { ipv4Address = "127.0.0.1/8"; };
      };
      etc = {
#        "resolv.conf" = { content = ( stdenv.lib.readFile "/etc/resolv.conf" );};
      };
      users = [
        {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
         shell="/bin/sh"; authorizedKeys = (stdenv.lib.splitString "\n" myKeys);}
        {name="store"; uid=500; gid=500; gecos="Storage owner"; dir="/srv";
         shell="/dev/null"; authorizedKeys = [];}
      ];
      packages = [ pkgs.iproute ];
      filesystems = {} ;
    };

    kernelMtdOpts = nixpkgs: self: super:
      nixpkgs.lib.recursiveUpdate super {
        kernel.config."MTD_SPLIT" = "y";
        kernel.config."MTD_SPLIT_UIMAGE_FW" = "y";
        kernel.config."MTD_CMDLINE_PARTS" = "y";
        # partition layout comes from device tree, doesn't need to be specified here
      };
    wantedModules = with nixwrt.modules;
      [(_ : _ : _ : baseConfiguration)
       nixwrt.device.hwModule
       (kexec {})
       (rsyncd { password = rsyncPassword; })
       (sshd { hostkey = sshHostKey ; })
       busybox
       (usbdisk {
         label = "backup-disk";
         mountpoint = "/srv";
         fstype = "ext4";
         options = "rw";
       })
       kernelMtdOpts
       (switchconfig {
         name = "switch0";
         interface = "eth0";
         vlans = {"2" = "1 2 3 6t";  "3" = "0 6t"; };
        })
       (syslogd { loghost = "192.168.0.2"; })
       (ntpd { host = "pool.ntp.org"; })
       (dhcpClient { interface = "eth0.2"; })
    ];
    in {
      firmware = nixwrt.firmware (nixwrt.mergeModules wantedModules);
      phramware = let modules = wantedModules ++ [
        (nixwrt.modules.phram { offset="0xa00000"; sizeMB="5"; })
      ]; in  nixwrt.firmware (nixwrt.mergeModules modules);

      sysupgrade = (pkgs.callPackage ./nixwrt/sysupgrade/default.nix) {
        cmdline = appConfig.kernel.commandLine;

      };
    }
