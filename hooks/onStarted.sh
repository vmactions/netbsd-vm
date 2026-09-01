#!/bin/sh
# Point pkg_add at live package mirrors for the running release.
#
# Two problems with the image's default /etc/pkg_install.conf:
#   - it ends with a 9.0 fallback, so when the preferred hosts miss a
#     package, pkg_add silently installs one built for NetBSD 9.0
#     (linked against libraries this release does not ship);
#   - cdn.NetBSD.org and ftp.NetBSD.org are the same infrastructure
#     behind a CDN, and they have been down together (2026-08-30).
#
# Probe every mirror and write ONLY the ones that answer, in order.
# Dead entries must not be kept as fallbacks: pkg_add walks the whole
# PKG_PATH list for every package it installs, and each dead https
# host costs minutes of TLS timeouts per package -- a 20-minute
# prepare step died exactly that way.  Never fail the VM start: if
# nothing answers, leave the file alone.
#
# ASK EACH MIRROR FOR THE NEWEST QUARTERLY IT ACTUALLY HAS, rather than
# using the rolling <release>/ alias.  Those aliases are unreliable, and
# on riscv64 they are what broke this action (netbsd-vm run 33459640344,
# 12 red legs).  Measured 2026-09-01 for riscv64/11.0:
#
#   mirror              <rel>/     <rel>_2026Q2/
#   cdn.NetBSD.org      302        200
#   ftp.NetBSD.org      302        200
#   ftp.fr.NetBSD.org   404        200
#   ftp.jaist.ac.jp     403        200
#   ftp.allbsd.org      200        404   <- only survivor, a 2025 tree
#
# So every good mirror failed the probe and PKG_PATH ended up holding
# only allbsd's stale set: rsync 3.4.1 where the image ships 3.4.4 (so
# `pkg_add rsync` refused with "A different version ... is already
# installed"), and a dependency set that could not satisfy curl
# ("no pkg found for 'libidn2>=2.3.3nb1'"), which failed the prepare
# step and with it the job.  The real 2026Q2 tree has 21562 packages
# including the matching rsync; the alias tree had 13264.  x86_64 was
# unaffected only because its alias still answers 200 there.
#
# netbsd-builder learned the same lesson in 2026-08 and its
# hooks/vm_postBuild.sh already bakes PKG_PATH this way -- listings do
# not lie about which directories exist, aliases do.  The alias is kept
# only as a per-mirror fallback, so a mirror that publishes just the
# alias (allbsd) still contributes instead of being dropped.

arch=$(uname -p)
rel=$(uname -r)

candidates="https://cdn.NetBSD.org https://ftp.NetBSD.org http://ftp.fr.NetBSD.org http://ftp.jaist.ac.jp https://ftp.allbsd.org"

# Newest "<rel>_YYYYQn" directory this mirror actually lists, else empty.
# base ftp(1) speaks plain http/https on every release this action runs.
newest_quarterly() {
  ftp -o - -q 20 "$1/pub/pkgsrc/packages/NetBSD/$arch/" 2>/dev/null \
    | grep -oE "${rel}_[0-9][0-9][0-9][0-9]Q[0-9]" \
    | sort \
    | tail -n 1
}

pkgpath=""
used=""
for base in $candidates; do
  dir=$(newest_quarterly "$base")
  [ -n "$dir" ] || dir="$rel"          # no quarterly listed; try the alias
  url="$base/pub/pkgsrc/packages/NetBSD/$arch/$dir"
  ftp -o /dev/null -q 15 "$url/" >/dev/null 2>&1 || continue
  if [ -z "$pkgpath" ]; then
    pkgpath="$url/All"
  else
    pkgpath="$pkgpath;$url/All"
  fi
  used="$used $base($dir)"
done

if [ -z "$pkgpath" ]; then
  echo "onStarted: no NetBSD package mirror answered; keeping the default /etc/pkg_install.conf" >&2
  exit 0
fi

echo "PKG_PATH=$pkgpath" > /etc/pkg_install.conf
echo "onStarted: live package mirrors:$used (release $rel, $arch)"
exit 0
