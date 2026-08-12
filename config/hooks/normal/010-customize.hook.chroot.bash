#!/bin/sh
set -eu

systemctl enable NetworkManager.service
systemctl set-default graphical.target

update-desktop-database || true
update-icon-caches /usr/share/icons/* || true