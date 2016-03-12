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
    ln -s $TINCBASE/subnet-down.conf.sample /etc/tinc/ffsbb/subnet-down
fi
}
setup_tinc_config() {
  ensureline "PMTUDiscovery = yes" /etc/tinc/ffsbb/hosts/$HOSTNAME
  ensureline "Digest = sha256" /etc/tinc/ffsbb/hosts/$HOSTNAME
  ensureline "ClampMSS = yes" /etc/tinc/ffsbb/hosts/$HOSTNAME
  ensureline "Address = $HOSTNAME.freifunk-stuttgart.de" /etc/tinc/ffsbb/hosts/$HOSTNAME
  ensureline "Port = 119${HOSTNAME##gw}" /etc/tinc/ffsbb/hosts/$HOSTNAME
}
setup_tinc_key() {
  if [ ! -e /etc/tinc/ffsbb/rsa_key.priv ]; then
    tincd -n ffsbb -K 4096
  fi
}
setup_tinc_git_push() {
if [ x$TINC_BB == x1 ]; then
  git add hosts/$HOSTNAME
  git commit -m "hosts/$HOSTNAME"
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
    address 10.191.255.$(sed 's/gw0*//' <<<$HOSTNAME)/24    # Z.B. 10.191.255.10
    netmask 255.255.255.0
    broadcast 10.191.255.255
    post-up         /sbin/ip rule add iif \$IFACE table stuttgart priority 7000 || true
    pre-down        /sbin/ip rule del iif \$IFACE table stuttgart priority 7000 || true
    post-up         /sbin/ip route add 10.191.255.0/24 dev \$IFACE table stuttgart || true
    post-down       /sbin/ip route del 10.191.255.0/24 dev \$IFACE table stuttgart || true

EOF
}
