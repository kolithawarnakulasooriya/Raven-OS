#!/bin/sh
set -eu

cd "$(dirname "$0")"

# A previous live-build process must not be running while state is repaired.
if pgrep -f '/usr/lib/live/build/lb_(build|bootstrap|chroot|binary)|[ /]debootstrap ' >/dev/null 2>&1; then
    echo "A live-build/debootstrap process is still running; not changing build state." >&2
    exit 1
fi

sudo rm -f .lock

if [ ! -x chroot/usr/bin/env ]
then
    # The bootstrap log showed a single intermittent Wget TLS failure while
    # downloading this valid Noble package. Seed the signed-index checksum-
    # verified package into live-build's bootstrap cache, then discard only the
    # incomplete chroot and bootstrap stage state.
    package=iputils-ping_3%3a20240117-1build1_amd64.deb
    url=http://archive.ubuntu.com/ubuntu/pool/main/i/iputils/iputils-ping_20240117-1build1_amd64.deb
    expected_md5=0dcbad63466d04646a3b5ed16d199ebe
    download="$(mktemp)"
    trap 'rm -f "$download"' EXIT INT TERM
    curl -4 -fL --retry 5 --retry-delay 2 --connect-timeout 20 \
        --max-time 180 -o "$download" "$url"
    actual_md5="$(md5sum "$download" | cut -d' ' -f1)"
    if [ "$actual_md5" != "$expected_md5" ]
    then
        echo "Checksum mismatch for iputils-ping: $actual_md5" >&2
        exit 1
    fi
    sudo rm -rf chroot
    sudo rm -f .build/bootstrap .build/bootstrap_*
    sudo install -d -m 0755 cache/packages.bootstrap
    sudo install -m 0644 "$download" "cache/packages.bootstrap/$package"
    rm -f "$download"
    trap - EXIT INT TERM
else
    # Preserve a completed bootstrap while repairing only failed later stages.
    sudo rm -f \
        chroot/root/packages.chroot \
        chroot/root/packages.chroot.cfg \
        .build/chroot_linux-image \
        .build/chroot_package-lists.install \
        .build/chroot_install-packages.install

    # lb_chroot_dpkg cleanup from this legacy live-build can remove dpkg's real
    # start-stop-daemon while undoing its temporary diversion. Restore the exact
    # package-owned file from the preserved Noble bootstrap archive, validating
    # it against the chroot package database before any chroot package action.
    if [ ! -x chroot/usr/sbin/start-stop-daemon ]
    then
        dpkg_archive=cache/packages.bootstrap/dpkg_1.22.6ubuntu6_amd64.deb
        expected_md5="$(
            awk '$2 == "usr/sbin/start-stop-daemon" { print $1 }' \
                chroot/var/lib/dpkg/info/dpkg.md5sums
        )"
        restore_dir="$(mktemp -d)"
        trap 'rm -rf "$restore_dir"' EXIT INT TERM
        dpkg-deb -x "$dpkg_archive" "$restore_dir"
        actual_md5="$(md5sum "$restore_dir/usr/sbin/start-stop-daemon" | cut -d' ' -f1)"
        if [ -z "$expected_md5" ] || [ "$actual_md5" != "$expected_md5" ]
        then
            echo "Refusing to restore unverified start-stop-daemon" >&2
            exit 1
        fi
        sudo install -m 0755 "$restore_dir/usr/sbin/start-stop-daemon" \
            chroot/usr/sbin/start-stop-daemon
        rm -rf "$restore_dir"
        trap - EXIT INT TERM
    fi

    # Repair the current completed chroot. The same hook runs automatically
    # during future clean builds.
    sudo mount -t devpts -o gid=5,mode=620 devpts-live chroot/dev/pts
    trap 'sudo umount chroot/dev/pts 2>/dev/null || true' EXIT INT TERM
    sudo install -m 0755 config/hooks/010-syslinux-compat.chroot \
        chroot/tmp/010-syslinux-compat.chroot
    sudo chroot chroot /tmp/010-syslinux-compat.chroot
    sudo rm -f chroot/tmp/010-syslinux-compat.chroot
    sudo umount chroot/dev/pts
    trap - EXIT INT TERM

    # Re-run the failed binary stages. In particular, binary_iso must regenerate
    # binary.sh after the chroot hook installs syslinux-utils/isohybrid.
    sudo rm -rf binary/isolinux
    sudo rm -f .build/binary_syslinux .build/binary_hooks .build/binary_iso
fi

# Resume from the valid stage boundary. Append so the new run remains
# distinguishable from the failure being repaired.
printf '\n===== resume %s =====\n' "$(date -Is)" | tee -a raven-build.log
sudo lb build 2>&1 | tee -a raven-build.log
