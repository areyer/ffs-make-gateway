setup_batman_dkms() {
  apt-get -y install linux-headers-$(uname -r)
  # batman-adv-dkms haengt von linux-headers-generic ab, das gibt es auf Debian nicht
  if ! dpkg -l equivs >/dev/null 2>&1; then
    apt-get install equivs
  fi
  if ! dpkg -l linux-headers-generic | grep -qw $(uname -r); then
    TMPDIR=$(mktemp -d)
    equivs-control $TMPDIR/linux-headers-generic
    sed -i '
      s/^Package:.*/Package: linux-headers-generic/
      s/^# Version:.*/Version: '"$(uname -r)"'/
      /^Description/,$d
    ' $TMPDIR/linux-headers-generic
    cat <<EOF >>$TMPDIR/linux-headers-generic
Description: linux-headers-generic translation package
 linux-headers-generic translation package for batman-adv-dkms
EOF
    equivs-build $TMPDIR/linux-headers-generic
    dpkg -i linux-headers-generic_$(uname -r)_all.deb
    rm -rf "$TMPDIR"
  fi
}

setup_batman_names() {
  for gw in $(seq 1 $GWS); do
    ensureline "$(printf '02:00:0a:38:00:%02i gw%02i\n' $gw $gw)" /etc/bat-hosts
    for seg in $(seq 1 $SEGMENTS); do
      ensureline "$(printf '02:00:0a:38:%02i:%02i gw%02i-%i' $seg $gw $gw $seg)" /etc/bat-hosts
    done
  done
}
