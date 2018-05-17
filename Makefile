t?=malta
default: tftproot
RSYNC_PASSWORD=$(shell sudo cat /var/lib/backupwrt/rsync)
export RSYNC_PASSWORD

tftproot:
	nix-build -I nixpkgs=../nixpkgs-for-nixwrt/ backuphost.nix -A $@ \
	 --argstr targetBoard $(t) -o $(t) --show-trace 
	rsync -caAi $(t)/* /tftp/

bin:
	nix-build -I nixpkgs=../nixpkgs-for-nixwrt/ backuphost.nix -A firmwareImage \
	 --argstr targetBoard $(t) -o firmware.bin --show-trace 
	rsync -caAiL firmware.bin /tftp/


qemu: tftproot
	nix-shell  -p qemu --run "qemu-system-mips  -M malta -m 128 -virtfs local,path=`pwd`,mount_tag=host0,security_model=passthrough,id=host0 -nographic -kernel malta/kernel.image  -append 'root=/dev/sr0 console=ttyS0 init=/bin/init' -blockdev driver=file,node-name=squashed,read-only=on,filename=malta/rootfs.image -blockdev driver=raw,node-name=rootfs,file=squashed,read-only=on -device ide-cd,drive=rootfs -nographic -netdev user,id=u0 -device e1000,netdev=u0"
