setup_tinc_base() {
if [ ! -d /etc/tinc/ffsbb/.git ]; then
  mkdir -p /etc/tinc
  git clone git+ssh://git@github.com/freifunk-stuttgart/tinc-ffsbb /etc/tinc/ffsbb
fi
if [ ! -e /etc/tinc/ffsbb/tinc.conf ]; then
    ln -s $TINCBASE/tinc.conf.sample /etc/tinc/ffsbb/tinc.conf
fi
if [ ! -e /etc/tinc/ffsbb/subnet-up ]; then
    ln -s $TINCBASE/subnet-up.sample /etc/tinc/ffsbb/subnet-up
fi
if [ ! -e /etc/tinc/ffsbb/subnet-down ]; then
    ln -s $TINCBASE/subnet-down.sample /etc/tinc/ffsbb/subnet-down
fi
}
setup_tinc_config() {
  ensureline "PMTUDiscovery = yes" /etc/tinc/ffsbb/hosts/$HOSTNAME
  ensureline "Digest = sha256" /etc/tinc/ffsbb/hosts/$HOSTNAME
  ensureline "ClampMSS = yes" /etc/tinc/ffsbb/hosts/$HOSTNAME
  ensureline "Address = $HOSTNAME.freifunk-stuttgart.de" /etc/tinc/ffsbb/hosts/$HOSTNAME
  ensureline "Port = 119${GWLID}" /etc/tinc/ffsbb/hosts/$HOSTNAME
  if [ ! -e /etc/tinc/ffsbb/conf.d/$HOSTNAME ]; then
    echo ConnectTo = $HOSTNAME > /etc/tinc/ffsbb/conf.d/$HOSTNAME
    ( cd /etc/tinc/ffsbb && git add conf.d/$HOSTNAME )
  fi
}
setup_tinc_key() {
  if [ ! -e /etc/tinc/rsa_key.priv ]; then
    echo | tincd -K 4096
  fi
  if [ ! -e /etc/tinc/ffsbb/rsa_key.priv ]; then
    cp /etc/tinc/rsa_key.priv /etc/tinc/ffsbb/
  fi
  if ! grep -q "BEGIN RSA PUBLIC KEY" /etc/tinc/ffsbb/hosts/$HOSTNAME; then
    cat /etc/tinc/rsa_key.pub >> /etc/tinc/ffsbb/hosts/$HOSTNAME
  fi
}
setup_tinc_git_push() {
if [ x$TINC_BB == x1 ]; then
  git add hosts/$HOSTNAME
  git commit -m "hosts/$HOSTNAME" -a || true
  git push
fi
}
setup_tinc_interface() {
cat <<EOF >/etc/network/interfaces.d/ffsbb
allow-hotplug ffsbb
auto ffsbb
iface ffsbb inet static
    tinc-net ffsbb
    tinc-mlock yes
    tinc-pidfile /var/run/tinc.ffsbb.pid
    address 10.191.255.$(($GWID*10+$GWSUBID))
    netmask 255.255.255.0
    broadcast 10.191.255.255
    post-up         /sbin/ip rule add iif \$IFACE table stuttgart priority 7000 || true
    pre-down        /sbin/ip rule del iif \$IFACE table stuttgart priority 7000 || true
    post-up         /sbin/ip route add 10.191.255.0/24 dev \$IFACE table stuttgart || true
    post-down       /sbin/ip route del 10.191.255.0/24 dev \$IFACE table stuttgart || true

EOF
}
setup_tinc_segments() {
  OLDDIR=$(pwd)
  mkdir -p /root/git
  cd /root/git
  if [ ! -d /root/git/tinc ]; then
    git clone git@github.com:freifunk-stuttgart/tinc.git
    cd tinc
  else
    cd /root/git/tinc && git pull
  fi
  if [ ! -e /etc/tinc/rsa_key.priv ]; then
    echo | tincd -K 4096
  fi

  for net in ffsl2s00 ffsl2s01 ffsl2s02 ffsl2s03 ffsl2s04; do
    ensureline "PMTUDiscovery = yes" /root/git/tinc/$net/hosts/$HOSTNAME
    ensureline "Digest = sha256" /root/git/tinc/$net/hosts/$HOSTNAME
    ensureline "ClampMSS = yes" /root/git/tinc/$net/hosts/$HOSTNAME
    ensureline "Address = $HOSTNAME.freifunk-stuttgart.de" /root/git/tinc/$net/hosts/$HOSTNAME
    ensureline "Port = 12${GWID}${GWLSUBID}" /root/git/tinc/$net/hosts/$HOSTNAME
    if ! grep -q "BEGIN RSA PUBLIC KEY" /root/git/tinc/$net/hosts/$HOSTNAME; then
      cat /etc/tinc/rsa_key.pub >> /root/git/tinc/$net/hosts/$HOSTNAME
    fi
    mkdir -p /root/git/tinc/$net/conf.d
    if [ ! -e /root/git/tinc/$net/conf.d/$HOSTNAME ]; then
      echo ConnectTo = $HOSTNAME > /root/git/tinc/$net/conf.d/$HOSTNAME
    fi
    git add $net/hosts/$HOSTNAME $net/conf.d
  done
  git commit -m $HOSTNAME -a || true
  git push
  for seg in $(seq 0 $SEGMENTS); do
    net=$(printf "ffsl2s%02i" $seg)
cat << EOF > /etc/network/interfaces.d/$net
auto $net
iface $net inet manual
	tinc-net $net
	tinc-mlock 1
	tinc-pidfile /var/run/tinc.$net
	hwaddress	02:00:37:$(printf "%02i" $seg):$GWLID:$GWLSUBID
        pre-up          /sbin/modprobe batman_adv || true
        post-up         /sbin/ip link set $net address 02:00:37:$(printf "%02i" $seg):$GWLID:$GWLSUBID up || true
        post-up         /sbin/ip link set dev $net up || true
        post-up         /usr/sbin/batctl -m bat$(printf "%02i" $seg) if add $net || true

EOF
  done
  cd $OLDPWD

  mkdir -p /usr/local/bin
cat <<'EOF' >/usr/local/bin/tinc-segments
#/bin/bash
cd /root/git/tinc
git pull
for net in ffsl2s00 ffsl2s01 ffsl2s02 ffsl2s03 ffsl2s04; do
  if [ ! -d /etc/tinc/$net ]; then
    mkdir /etc/tinc/$net
  fi
  rsync -rlHpogDtSvx --delete \
    --exclude=rsa_key.priv \
    --exclude=tinc.conf \
    --exclude=subnet-up \
    --exclude=subnet-down \
    --exclude=host-up \
    --exclude=host-down \
    /root/git/tinc/$net/. \
    /etc/tinc/$net/
done
killall -HUP tincd
EOF
chmod +x /usr/local/bin/tinc-segments
/usr/local/bin/tinc-segments
for net in ffsl2s00 ffsl2s01 ffsl2s02 ffsl2s03 ffsl2s04; do
    if [ ! -e /etc/tinc/$net/rsa_key.priv ]; then
        cp /etc/tinc/rsa_key.priv /etc/tinc/$net/
    fi
    if [ ! -e /etc/tinc/$net/tinc.conf ]; then
        ln -s /etc/tinc/$net/tinc.conf.sample /etc/tinc/$net/tinc.conf
    fi
done
}
