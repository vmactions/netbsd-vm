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
#
# LAST RESORT, for a mirror that lists NEITHER a quarterly NOR an alias
# for this release: the newest quarterly of the release's own branch
# ("<major>.0_YYYYQn").  Quarterlies are built only for a branch's .0
# release (9.0_*, 10.0_*, 11.0_*; there is no 9.4_* or 10.1_*), and the
# minor releases' aliases point into those trees: on ftp.fr.NetBSD.org
# and ftp.jaist.ac.jp, 9.4/ carries the same package set as 9.0_2026Q2,
# and pkg_add on a 9.4 guest warns that curl "was built for a platform:
# NetBSD/x86_64 9.0 (pkg) vs. NetBSD/x86_64 9.4 (this host)".  9.5
# needs this: no mirror lists a 9.5/ alias or any 9.5_* quarterly
# (checked 2026-09-26), so this hook wrote nothing and 9.5 ran on the
# image's baked PKG_PATH, whose only live entry was ftp.NetBSD.org's
# 9.0_2026Q1 (9.5 green in netbsd-vm run 35168524225, 2026-09-17).
# Then cdn/ftp.NetBSD.org dropped every 9.x package directory -- gone
# by 2026-09-25, moved to archive.NetBSD.org -- and all 18 9.5 legs of
# run 36190078117 died in prepare with "no pkg found for 'curl',
# sorry."  fr and jaist still carry 9.0_2026Q2 (about 26.9k packages
# on x86_64, 21.3k on aarch64, curl and rsync included).
# archive.NetBSD.org is no fallback: its listings answer, but package
# downloads answer HTTP 402 with a bot-check form (tested with curl).
# Own branch only -- another major's packages link libraries this
# release does not ship (the 9.0 fallback problem at the top).
#
# A LISTED alias that does not answer still drops the mirror, as it
# always did.  That mirror is having a bad moment, and its branch
# quarterly would put it back into PKG_PATH, where pkg_add queries
# every entry for every package: in run 36190078117's 9.4 sshfs leg the
# last entry, ftp.allbsd.org, was still asked for curl and each of its
# dependencies, and its two "Bad Gateway" answers took about a minute
# each.  Checked 2026-09-26 across every release/arch this action
# tests: only 9.5 (x86_64 and aarch64) reaches the branch fallback.

arch=$(uname -p)
rel=$(uname -r)
major=${rel%%.*}

candidates="https://cdn.NetBSD.org https://ftp.NetBSD.org http://ftp.fr.NetBSD.org http://ftp.jaist.ac.jp https://ftp.allbsd.org"

# Newest "<prefix>_YYYYQn" directory in the listing $1, else empty.
newest_quarterly() {
  printf '%s\n' "$1" \
    | grep -oE "${2}_[0-9][0-9][0-9][0-9]Q[0-9]" \
    | sort \
    | tail -n 1
}

# True when the listing $1 has an entry for the directory $2.
listed() {
  printf '%s\n' "$1" | grep -qE "[\">=]${2}/"
}

# base ftp(1) speaks plain http/https on every release this action runs.
answers() {
  ftp -o /dev/null -q 15 "$1/" >/dev/null 2>&1
}

pkgpath=""
used=""
for base in $candidates; do
  root="$base/pub/pkgsrc/packages/NetBSD/$arch"
  # "|| true": index.js runs this file under "set -eu", where a failed
  # command substitution in an assignment would end the whole hook.
  listing=$(ftp -o - -q 20 "$root/" 2>/dev/null || true)
  dir=$(newest_quarterly "$listing" "$rel")
  if [ -n "$dir" ]; then
    answers "$root/$dir" || continue
  elif answers "$root/$rel"; then
    dir="$rel"                         # no quarterly listed; the alias answers
  elif ! listed "$listing" "$rel"; then
    dir=$(newest_quarterly "$listing" "$major\.0")   # no alias at all (9.5)
    [ -n "$dir" ] && answers "$root/$dir" || continue
  else
    continue                           # a listed alias that did not answer
  fi
  if [ -z "$pkgpath" ]; then
    pkgpath="$root/$dir/All"
  else
    pkgpath="$pkgpath;$root/$dir/All"
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
