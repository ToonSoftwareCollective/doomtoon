#!/bin/sh
# DoomToon setup, run on the original Toon 2 software (a copy of ReToon's
# setup script, vendor-app/retoon/retoon.sh, cut down to the Toon 2).
#
# Started by the DoomToon app through the "tsc" helper (which runs <app>.sh
# of an app as root when the app writes "external-doomtoon" to
# /tmp/tsc.command), or by hand:
#
#   doomtoon.sh check      say what is there and what is missing
#   doomtoon.sh install    put everything in place and restart into DoomToon
#
# Without an argument it does what /tmp/doomtoon.request asks for.
# Progress goes to /tmp/doomtoon.status (JSON, read by the app) and to
# /var/log/doomtoon.log. Set DOOMTOON_NO_REBOOT=1 to stop before the restart.
#
# What "in place" means:
#   p3 (recovery)    doom2-zImage, doom2.dtb, doom2-initrd.cpio.gz.u-boot,
#                    next to the vendor recovery files (and ReToon's, if any)
#   p4 /mnt/data     doom-os/rootfs.squashfs, doom-os/boot.scr,
#                    doom-os/config/wpa_supplicant.conf (the networks of this
#                    system, so WiFi works at once),
#                    doom-os/firmware/brcm/: the WiFi and Bluetooth chip's
#                    firmware, copied from this system (it is not ours to
#                    hand out, so no DoomToon image contains it)
#   p1 (boot)        boot.scr - what makes the next start go to DoomToon,
#                    once: DoomToon removes it again as the first thing it
#                    does, so the start after that is this system again.
# Nothing else is written: not the vendor root (p2), not p5, not the U-Boot
# settings, not ReToon's toon-os folder.
#
# Which files make up DoomToon, with their checksums: files.sha256 inside the
# archive doomtoon-toon2.tar.gz, next to this script (or in /mnt/data/doom-os/),
# or else files-toon2.sha256 of the newest DoomToon release, from the address
# in "images.url" next to this script. Files that are already there with the
# right checksum are kept; the others are unpacked from that archive, or
# downloaded and unpacked while they come in (as ReToon's setup does).

APP=$(cd "$(dirname "$0")" && pwd)
STATUS=/tmp/doomtoon.status
LOG=/var/log/doomtoon.log
OS=/mnt/data/doom-os
P3=/tmp/doomtoon-p3
P1=/tmp/doomtoon-p1
VENDOR_WIFI=/etc/network/wpa_supplicant.wlan0.conf
STEPS=6

ACTION=${1:-$(cat /tmp/doomtoon.request 2>/dev/null)}
rm -f /tmp/doomtoon.request
[ -n "$ACTION" ] || ACTION=check

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> $LOG; }

# One at a time (see retoon.sh): a check that finds another run busy goes
# away quietly; an install waits for a check to finish.
LOCK=/tmp/doomtoon.lock
while ! mkdir $LOCK 2>/dev/null; do
	pid=$(cat $LOCK/pid 2>/dev/null)
	if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
		rm -rf $LOCK
		continue
	fi
	if [ "$ACTION" != install ] || [ "$(cat $LOCK/action 2>/dev/null)" != check ]; then
		log "$ACTION asked for while $(cat $LOCK/action 2>/dev/null) is busy: left out"
		exit 0
	fi
	sleep 1
done
echo $$ > $LOCK/pid
echo "$ACTION" > $LOCK/action
trap 'rm -rf $LOCK' EXIT
status() {	# state, step, text
	log "$1: $3"
	printf '{"state":"%s","step":%s,"steps":%s,"text":"%s"}\n' "$1" "$2" $STEPS "$3" > $STATUS.tmp
	mv $STATUS.tmp $STATUS
}
cleanup() {
	umount $P3 2>/dev/null
	umount $P1 2>/dev/null
}
fail() {
	cleanup
	rm -rf "$OS/download"
	status error 0 "$1"
	exit 1
}

# Where a file belongs
home_of() {
	case "$1" in
	rootfs.squashfs|boot.scr) echo "$OS/$1" ;;
	*) echo "$P3/$1" ;;
	esac
}
sum_of() { sed -n "s/^\([0-9a-f]\{64\}\)  $1\$/\1/p" "$SUMS"; }
good() {	# path, name
	[ -f "$1" ] && [ "$(sha256sum "$1" | cut -d ' ' -f 1)" = "$(sum_of "$2")" ]
}
kb_free() { df -k "$1" | tail -n 1 | awk '{print $4}'; }

# Only on the original software of a Toon 2: its kernel is 4.9, DoomToon's
# and ReToon's are newer. Anything else and this script writes nothing.
grep -q 'i.MX6 SoloX' /proc/device-tree/model 2>/dev/null ||
	fail "DoomToon needs a Toon 2."
case "$(uname -r)" in
4.9.*) ;;
*) fail "This is not the Toon's own software (kernel $(uname -r)); nothing was changed." ;;
esac
asked=$(cat /tmp/doomtoon.board 2>/dev/null)
[ -z "$asked" ] || [ "$asked" = toon2 ] || fail "DoomToon needs a Toon 2."

ARCHIVE=$APP/doomtoon-toon2.tar.gz
[ -s "$ARCHIVE" ] || ARCHIVE=$OS/doomtoon-toon2.tar.gz
images=$(head -n 1 "$APP/images.url" 2>/dev/null | tr -d '\r\n')
SUMS=/tmp/doomtoon-files.sha256
rm -f $SUMS
if [ -s "$ARCHIVE" ]; then
	inner=$(tar -tzf "$ARCHIVE" 2>> $LOG | grep '/files.sha256$' | head -n 1)
	[ -n "$inner" ] && tar -xzOf "$ARCHIVE" "$inner" > $SUMS 2>> $LOG
	TOP=${inner%%/*}
elif [ -n "$images" ]; then
	ARCHIVE=""
	curl -fsSL --connect-timeout 20 --retry 2 -o $SUMS "${images%/}/files-toon2.sha256" >> $LOG 2>&1 ||
		fail "Cannot reach the DoomToon download. Is the Toon connected to the internet?"
elif [ -s "$OS/files.sha256" ]; then
	cp "$OS/files.sha256" $SUMS	# installed before; the archive is gone
fi
# only plain file names: they become paths below
FILES=$(sed -n 's/^[0-9a-f]\{64\}  \([A-Za-z0-9._-]*\)$/\1/p' "$SUMS" 2>/dev/null)
[ -n "$FILES" ] || fail "The DoomToon files are missing (doomtoon-toon2.tar.gz). Install the app again."

mount | grep -q ' /mnt/data ' || fail "The data partition is not there."
mkdir -p $P3 $P1
umount $P3 2>/dev/null
mount -o ro /dev/mmcblk3p3 $P3 2>/dev/null || fail "The third partition cannot be read."

missing=""
for f in $FILES; do
	good "$(home_of $f)" $f || missing="$missing $f"
done

if [ "$ACTION" = check ]; then
	cleanup
	if [ -z "$missing" ]; then
		status ready 0 "Ready. Press the button."
	elif [ -s "$ARCHIVE" ] || [ -n "$images" ]; then
		status needed 0 "First time: the button puts DoomToon in place (about half a minute), then Doom starts."
	else
		status error 0 "DoomToon files are missing and the app has no archive with them. Install the app again."
	fi
	exit 0
fi
[ "$ACTION" = install ] || fail "Unknown request: $ACTION"

# 1. room: unpacked files go to doom-os/download first, then to their place
status working 1 "Checking the room on the Toon"
if [ -n "$missing" ] && [ -z "$ARCHIVE" ]; then
	# downloading: the sizes are not known before, count on the whole image
	free4=$(kb_free /mnt/data); free3=$(kb_free $P3)
	[ "$free4" -gt 60000 ] || fail "Not enough room on the data partition (60000 kB needed, ${free4} kB free)."
	[ "$free3" -gt 20000 ] || fail "Not enough room on the third partition (20000 kB needed, ${free3} kB free)."
elif [ -n "$missing" ]; then
	[ -s "$ARCHIVE" ] || fail "Files are missing and the app has no archive with them. Install the app again."
	# sizes from the archive listing (kB); room on p3 counts what the
	# files of the same name there now take
	need4=1024; need3=1024
	for f in $missing; do
		bytes=$(tar -tzvf "$ARCHIVE" "$TOP/$f" 2>/dev/null | awk '{print $3}' | head -n 1)
		kb=$(( (${bytes:-0} + 1023) / 1024 ))
		[ "$kb" -gt 0 ] || fail "The DoomToon archive is damaged. Install the app again."
		need4=$((need4 + kb))
		case "$(home_of $f)" in
		$P3/*)
			need3=$((need3 + kb))
			[ -f "$P3/$f" ] && need3=$((need3 - $(du -k "$P3/$f" | cut -f 1)))
			;;
		esac
	done
	free4=$(kb_free /mnt/data)
	[ "$free4" -gt "$need4" ] ||
		fail "Not enough room on the data partition (${need4} kB needed, ${free4} kB free)."
	free3=$(kb_free $P3)
	[ "$free3" -gt "$need3" ] ||
		fail "Not enough room on the third partition (${need3} kB needed, ${free3} kB free)."
	log "room: p4 needs $need4 of $free4 kB, p3 needs $need3 of $free3 kB"
fi

# 2. unpack what is missing, each file checked against its checksum
mkdir -p $OS/download $OS/config $OS/firmware
chmod 700 $OS/config
if [ -n "$missing" ] && [ -z "$ARCHIVE" ]; then
	# straight from the download into the files: the archive itself is
	# never stored
	status working 2 "Downloading DoomToon (25 MB)"
	mkdir -p $OS/download/unpack
	curl -fsSL --connect-timeout 20 --retry 3 "${images%/}/doomtoon-toon2.tar.gz" 2>> $LOG |
		tar -xzf - -C $OS/download/unpack 2>> $LOG
	for f in $missing; do
		got=$(ls $OS/download/unpack/*/$f 2>/dev/null | head -n 1)
		[ -n "$got" ] && mv "$got" "$OS/download/$f"
		good "$OS/download/$f" $f ||
			fail "Could not download DoomToon (or it arrived damaged). Is the Toon connected to the internet?"
	done
	rm -rf $OS/download/unpack
	missing_unpack=""
else
	missing_unpack=$missing
fi
n=0
for f in $missing_unpack; do
	n=$((n + 1))
	status working 2 "Unpacking $f ($n of $(echo $missing_unpack | wc -w))"
	tar -xzOf "$ARCHIVE" "$TOP/$f" > "$OS/download/$f" 2>> $LOG ||
		fail "Could not unpack $f. Install the app again."
	good "$OS/download/$f" $f || fail "$f in the DoomToon archive is damaged. Install the app again."
done

# 3. the system on the data partition, kernel and start-up files on p3
status working 3 "Putting DoomToon in place"
for f in $missing; do
	case "$(home_of $f)" in
	$OS/*) mv "$OS/download/$f" "$OS/$f" || fail "Cannot write to the data partition." ;;
	esac
done
need_p3=""
for f in $missing; do
	case "$(home_of $f)" in $P3/*) need_p3="$need_p3 $f" ;; esac
done
if [ -n "$need_p3" ]; then
	mount -o remount,rw $P3 || fail "The third partition cannot be written."
	for f in $need_p3; do
		cp "$OS/download/$f" "$P3/$f.new" && sync && mv "$P3/$f.new" "$P3/$f" ||
			{ rm -f "$P3/$f.new"; fail "Cannot write $f to the third partition."; }
		good "$P3/$f" $f || fail "$f on the third partition is damaged. Press the button again."
	done
	sync
fi
umount $P3
rm -rf $OS/download
cp $SUMS $OS/files.sha256

# 4. WiFi: DoomToon uses the networks this Toon knows (for SSH; Doom does not
#    need it). Only the networks and the country: a ctrl_interface line makes
#    the wpa_supplicant there refuse the file. Taken again at every install,
#    so a changed network is followed. The passwords are never shown or logged.
status working 4 "Taking over the WiFi settings"
if [ -s $VENDOR_WIFI ]; then
	{
		grep -m 1 '^[ \t]*country=' $VENDOR_WIFI
		sed -n '/^[ \t]*network[ \t]*=[ \t]*{/,/^[ \t]*}/p' $VENDOR_WIFI
	} > $OS/config/wpa_supplicant.conf.new
	chmod 600 $OS/config/wpa_supplicant.conf.new
	if grep -q 'ssid=' $OS/config/wpa_supplicant.conf.new; then
		mv $OS/config/wpa_supplicant.conf.new $OS/config/wpa_supplicant.conf
	else
		rm -f $OS/config/wpa_supplicant.conf.new
		log "no WiFi network set on this Toon; DoomToon runs without WiFi"
	fi
else
	log "no WiFi settings on this Toon; DoomToon runs without WiFi"
fi

# 5. the radio chip's firmware, as this Toon has it (Bluetooth needs it)
status working 5 "Copying the WiFi and Bluetooth firmware"
FW=$OS/firmware/brcm
mkdir -p $FW
for f in brcmfmac43430-sdio.bin brcmfmac43430-sdio.clm_blob brcmfmac43430-sdio.txt; do
	if [ -s /lib/firmware/brcm/$f ]; then
		cp /lib/firmware/brcm/$f $FW/$f.new && mv $FW/$f.new $FW/$f || fail "Cannot write to the data partition."
	fi
done
hcd=$(ls /etc/firmware/BCM43430A1*.hcd /lib/firmware/brcm/BCM43430A1*.hcd 2>/dev/null | head -n 1)
if [ -n "$hcd" ]; then
	cp "$hcd" $FW/BCM43430A1.hcd.new && mv $FW/BCM43430A1.hcd.new $FW/BCM43430A1.hcd ||
		fail "Cannot write to the data partition."
else
	fail "The Bluetooth firmware of this Toon (BCM43430A1.hcd) is not where it should be."
fi
[ -s $FW/brcmfmac43430-sdio.bin ] && [ -s $FW/brcmfmac43430-sdio.txt ] ||
	log "no WiFi firmware found on this system; DoomToon runs without WiFi"
sync

# 6. the boot script: the next start (only that one) goes to DoomToon
status working 6 "Preparing the restart"
good $OS/boot.scr boot.scr || fail "The boot script is damaged."
mount -t vfat /dev/mmcblk3p1 $P1 || fail "The boot partition cannot be written."
[ -e $P1/boot.scr ] && log "p1 had a boot.scr already ($(sha256sum $P1/boot.scr | cut -c 1-16)); replaced"
cp $OS/boot.scr $P1/boot.new && sync && mv $P1/boot.new $P1/boot.scr ||
	{ rm -f $P1/boot.new; fail "Cannot write the boot script."; }
sync
umount $P1

if [ -n "$DOOMTOON_NO_REBOOT" ]; then
	status ready $STEPS "Everything is in place. (Test run: no restart; p1 has DoomToon's boot.scr now.)"
	exit 0
fi
status restarting $STEPS "Restarting into DoomToon..."
sleep 3
/sbin/reboot
