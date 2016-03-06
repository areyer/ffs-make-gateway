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
