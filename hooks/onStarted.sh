#!/bin/sh
# Point pkg_add at a live package mirror for the running release.
#
# Two problems with the image's default /etc/pkg_install.conf:
#   - it ends with a 9.0 fallback, so when the preferred hosts miss a
#     package, pkg_add silently installs one built for NetBSD 9.0
#     (linked against libraries this release does not ship);
#   - cdn.NetBSD.org and ftp.NetBSD.org are the same infrastructure
#     behind a CDN, and they have been down together (2026-08-30).
#
# Probe the mirrors in order and set the first one that answers as the
# package source, keeping the others as same-release fallbacks.  Never
# fail the VM start: if nothing answers, leave the file alone.

arch=$(uname -p)
rel=$(uname -r)

candidates="https://cdn.NetBSD.org https://ftp.NetBSD.org http://ftp.fr.NetBSD.org http://ftp.jaist.ac.jp https://ftp.allbsd.org"

good=""
for base in $candidates; do
  if ftp -o /dev/null -q 15 "$base/pub/pkgsrc/packages/NetBSD/$arch/$rel/" >/dev/null 2>&1; then
    good="$base"
    break
  fi
done

if [ -z "$good" ]; then
  echo "onStarted: no NetBSD package mirror answered; keeping the default /etc/pkg_install.conf" >&2
  exit 0
fi

pkgpath="$good/pub/pkgsrc/packages/NetBSD/$arch/$rel/All"
for base in $candidates; do
  [ "$base" = "$good" ] && continue
  pkgpath="$pkgpath;$base/pub/pkgsrc/packages/NetBSD/$arch/$rel/All"
done

echo "PKG_PATH=$pkgpath" > /etc/pkg_install.conf
echo "onStarted: package source set to $good (release $rel, $arch)"
exit 0
