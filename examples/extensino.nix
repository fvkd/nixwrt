{ psk ? "fishfinger"
, ssid ? "telent1"
, loghost ? "loghost"
, myKeys ? "ssh-rsa AAAAATESTFOOBAR dan@example.org"
, sshHostKey ? "----NOT A REAL RSA PRIVATE KEY---" }:
let nixwrt = (import <nixwrt>) { targetBoard = "mt300a"; }; in
with nixwrt.nixpkgs;
let
    baseConfiguration = {
      hostname = "extensino";
      interfaces = {        
        "eth0.1" = {
          # in normal use there's nothing here, but in development
          # it's hooked up to the build machine for tftp image download
          type = "vlan"; id = 1; parent = "eth0"; depends = []; # wan
        };
        "eth0.2" = {
          type = "vlan"; id = 2; parent = "eth0"; depends = []; # lan
        };
        "eth0" = { } ;
        "wlan0" = { };
        "br0" = {
          type = "bridge";
          members  = [ "eth0.2" "wlan0" ];
        };
        lo = { ipv4Address = "127.0.0.1/8"; };
      };
      etc = { };
      users = [
        {name="root"; uid=0; gid=0; gecos="Super User"; dir="/root";
         shell="/bin/sh"; authorizedKeys = (stdenv.lib.splitString "\n" myKeys);}
      ];
      packages = [ ];
      filesystems = {} ;
    };

    wantedModules = with nixwrt.modules;
      [(_ : _ : _ : baseConfiguration)
       nixwrt.device.hwModule
       (sshd { hostkey = sshHostKey ; })
       busybox
       kernelMtd
       (phram { offset = "0xa00000"; sizeMB = "5"; })
       (hostapd {
          config = { interface = "wlan0"; inherit ssid; hw_mode = "g"; channel = 11; };
          inherit psk;
        })
       (dhcpClient { interface = "br0"; resolvConfFile = "/run/resolv.conf";  })
       (switchconfig {
         name = "switch0";
         interface = "eth0";
         vlans = {
           "1" = "0 6t";           # wan (id 1 -> port 0)
           "2" = "1 6t";           # lan (id 2 -> ports 1-4)
         };
       })
       (syslog { inherit loghost ; })
       (ntpd { host = "pool.ntp.org"; })
    ];

    in {
      firmware = nixwrt.firmware (nixwrt.mergeModules wantedModules);

      # phramware generates an image which boots from the "fake" phram mtd
      # device - required if you want to boot from u-boot without
      # writing the image to flash first
      phramware = let m = wantedModules ++ [nixwrt.modules.forcePhram];
        in nixwrt.firmware (nixwrt.mergeModules m);
    }
