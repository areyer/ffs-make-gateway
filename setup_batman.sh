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
      s/^# Maintainer:.*/Maintainer: ffs-make-gateway <freifunk@lihas.de>/
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
  apt-get -y install batman-adv-dkms
}

setup_batman_names() {
  for gw in $(seq 1 $GWS); do
  for subgw in $(seq 0 9); do
    ensureline "$(printf '02:00:38:00:%02i:%02i mgw%02ii%02i\n' $gw $subgw $gw $subgw)" /etc/bat-hosts
    ensureline "$(printf '02:00:37:00:%02i:%02i vgw%02ii%02i\n' $gw $subgw $gw $subgw)" /etc/bat-hosts
    for seg in $(seq 1 $SEGMENTS); do
      ensureline "$(printf '02:00:38:%02i:%02i:%02i mgw%02ii%02i-%i' $seg $gw $subgw $gw $subgw $seg)" /etc/bat-hosts
      ensureline "$(printf '02:00:37:%02i:%02i:%02i vgw%02ii%02i-%i' $seg $gw $subgw $gw $subgw $seg)" /etc/bat-hosts
    done
  done
  done
}
