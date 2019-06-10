options: nixpkgs: self: super:
with nixpkgs;
let bg = cmd: args: "/bin/start-stop-daemon -o -b -m -p /run/${cmd}.pid -x ${klogforward}/bin/${cmd} -S -- ${args}";
in 
lib.attrsets.recursiveUpdate super {
  packages = super.packages ++ [ pkgs.klogforward pkgs.tcpdump ];
  busybox.applets = super.busybox.applets ++ [ "start-stop-daemon" ];
  busybox.config = super.busybox.config // {
    "START_STOP_DAEMON" = "y";
    "FEATURE_START_STOP_DAEMON_FANCY" = "y";
  };
  
  services.klogforward = {
    start = bg "klogforward" "/dev/kmsg ${options.loghost} 514";
  };
  services.klogcollect = {
    start = bg "klogcollect" "/dev/log /dev/kmsg";
  };
}
