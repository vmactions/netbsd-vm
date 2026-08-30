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

arch=$(uname -p)
rel=$(uname -r)

candidates="https://cdn.NetBSD.org https://ftp.NetBSD.org http://ftp.fr.NetBSD.org http://ftp.jaist.ac.jp https://ftp.allbsd.org"

alive=""
for base in $candidates; do
  if ftp -o /dev/null -q 15 "$base/pub/pkgsrc/packages/NetBSD/$arch/$rel/" >/dev/null 2>&1; then
    alive="$alive $base"
  fi
done

if [ -z "$alive" ]; then
  echo "onStarted: no NetBSD package mirror answered; keeping the default /etc/pkg_install.conf" >&2
  exit 0
fi

pkgpath=""
for base in $alive; do
  entry="$base/pub/pkgsrc/packages/NetBSD/$arch/$rel/All"
  if [ -z "$pkgpath" ]; then
    pkgpath="$entry"
  else
    pkgpath="$pkgpath;$entry"
  fi
done

echo "PKG_PATH=$pkgpath" > /etc/pkg_install.conf
echo "onStarted: live package mirrors:$alive (release $rel, $arch)"
exit 0
