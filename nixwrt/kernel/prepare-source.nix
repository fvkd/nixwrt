{  stdenv
 , buildPackages
 , callPackage
 , socFamily ? null
 , ledeSrc
 , kernelSrc
 , patchutils
 , socFiles
 , socPatches
 , version
} :
let versionScalar = v :
      let nth = n : builtins.elemAt v n;
      in (nth 2) + ((nth 1) * 1000) + ((nth 0) * 1000000);
    versionExceeds = a : b : (versionScalar a) > (versionScalar b) ;
    inherit lib; in
stdenv.mkDerivation rec {
    name = "kernel-source";
    phases = [ "unpackPhase" "patchFromLede" "patchPhase" "buildPhase" "installPhase" ];
    src = kernelSrc;
    nativeBuildInputs = [ patchutils ];

    patchFromLede = let
      majmin = "${toString (builtins.elemAt version 0)}.${toString (builtins.elemAt version 1)}";
    in ''
      q_apply() {
        if test -d $1 ; then find $1 -type f | sort | xargs  -n1 patch -N -p1 -i  ;fi
      }
      cp -dRv ${ledeSrc}/target/linux/generic/files/* .
      ${lib.concatMapStringsSep "\n" (x: "cp -dRv ${x} .") socFiles}
      q_apply ${ledeSrc}/target/linux/generic/backport-${majmin}/
      q_apply ${ledeSrc}/target/linux/generic/pending-${majmin}/
      q_apply ${ledeSrc}/target/linux/generic/hack-${majmin}/
      ${lib.concatMapStringsSep "\n" (x: "q_apply ${x}") socPatches}
      chmod -R +w .
    '';

    patches = [ ./kernel-ath79-wdt-at-boot.patch
                ./kernel-lzma-command.patch
                ./kexec_copy_from_user_return.patch
              ]
    ++ lib.optional (! versionExceeds version [4 10 0]) ./kernel-memmap-param.patch
    ++ lib.optional (socFamily == "ath79") ./552-ahb_of.patch
    ++ lib.optionals (socFamily == "ramips") [
      (callPackage ./rt2x00.nix { inherit ledeSrc; })
      ./ralink_appended_raw_dtb.patch
    ];

    patchFlags = [ "-p1" ];
    buildPhase = ''
      substituteInPlace scripts/ld-version.sh --replace /usr/bin/awk ${buildPackages.pkgs.gawk}/bin/awk
      substituteInPlace Makefile --replace /bin/pwd ${buildPackages.pkgs.coreutils}/bin/pwd
    '';

    installPhase = ''
      cp -a . $out
    '';

  }
