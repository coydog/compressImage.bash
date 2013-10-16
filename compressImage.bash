#!/bin/bash
#
# read image off hard drive, take a checksum, compress data
# and write to shared network drive. When we're through, 
# decompress and take checksum for integrity check (may need
# to make this an entirely separate step since it is slow).
#
# USAGE: compressImage.bash <devicename> <destination dir>
#
# TODO: locking (can use mkdir or whatever) to prevent accidental
# double invocation.
# TODO: also try with huge blocksize and big input test file for
# performance testing. Perhaps that will be more parallelisable,
# since I/O buffering should be faster than compression/
# cryptographic checksums.  - maybe not, tho
# 
# TODO: paranoid mode, take checksum of device at end. Also print
#   fdisk or parted output to a dated file. 
#
# For best results, some preparation is strongly recommended. If
# the filesystem supports defragmentation, do this first using its
# OS's native tools. After defragmentation (if applicable), a 
# freespace wipe should be performed to ensure optimal compression.
# For example, in linux, something like 
#
#		mount -t auto /dev/sda /mnt
#		cd /mnt
#		sudo cat /dev/zero >> zero.bin ; rm zero.bin
#		cd ; umount /dev/sda
#
# will do the trick. On FAT filesystems, this may need to be done with 
# multiple files due to file size limitations; eg
#
#	cat /dev/zero >> zero1.bin ; sudo cat /dev/zero >> zero2.bin; cat 
#		/dev/zero >> zero3.bin
#
#	rm zero*.bin
#
# The precise number of "zero" files needed depends on the exact 
# filesystem type and amount of free space on the device.
#
# If you get mysterious checksum mismatches while backing up a linux drive
# under an ultra-modern Linux distro, a likely culprit is automatic swap
# partition usage. These newer distros will automagically mount any swap
# partitions they find in the machine to optimise performance. try 
#
#	man swapon
#	man swapoff
#
# for more information.

PIPE="ChecksumStream";
DEVICE=$1;
DESTINATION=$2;
#HOSTNAME=
DATE=`date --rfc-3339=date`;
IMAGE="${DESTINATION}/${DATE}.img.bz";

# for debugging, let's list our variables:
echo "PIPE: $PIPE";
echo "DEVICE: $DEVICE";
echo "DESTINATION: $DESTINATION";
echo "DATE: $DATE";
echo "IMAGE: $IMAGE";

# create named pipe (FIFO). Better to use mknod p instead of 
# mkfifo for compatibility? No.
echo "making FIFO: $PIPE";
mkfifo $PIPE;

# start listening at the FIFO for the checksum stream.
echo "forking md5sum to take device checksum from $PIPE";
md5sum $PIPE > "$DESTINATION/checksum.$DATE.DEVICE.md5" & 

# do the dirty work
#TODO: come up with a good blocksize
echo "Doing the dirty work, calling dd";
dd bs=2048 if=$DEVICE | tee $PIPE | bzip2 > "$IMAGE";

# cleanup
echo "cleanup: deleting FIFO $PIPE";
rm "$PIPE";

echo "image compressed and copied; taking image checksum";
bzcat "$IMAGE" | md5sum > "$DESTINATION/checksum.$DATE.IMAGE.md5";
echo "All done, don't forget to compare checksums in destination directory"
