add_apt_repositories() {
  apt-get install apt-transport-https
  ensureline "deb http://ppa.launchpad.net/freifunk-mwu/freifunk-ppa/ubuntu trusty main" /etc/apt/sources.list.d/freifunk.list
  ensureline "deb-src http://ppa.launchpad.net/freifunk-mwu/freifunk-ppa/ubuntu trusty main" /etc/apt/sources.list.d/freifunk.list
  ensureline "deb http://repo.universe-factory.net/debian/ sid main" /etc/apt/sources.list.d/freifunk.list
  ensureline "deb http://debian.mirrors.ovh.net/debian/ jessie-backports main" /etc/apt/sources.list.d/jessie-backports.list
  if [ "x$OPT_FWLIHAS" == "x1" ]; then
    ensureline "deb http://ftp.lihas.de/debian/ stable main" /etc/apt/sources.list.d/lihas.list
  fi
}
add_apt_preference() {
  cat <<'EOF' >/etc/apt/preferences.d/alfred
Package: alfred
Pin:  release n=jessie-backports
Pin-Priority:  500
EOF
}
add_apt_keys() {
  apt-key adv --keyserver keyserver.ubuntu.com --recv 16EF3F64CB201D9C
  apt-key adv --keyserver keyserver.ubuntu.com --recv B976BD29286CC7A4
  if [ "x$OPT_FWLIHAS" == "x1" ]; then
    wget -O - http://ftp.lihas.de/debian/apt-key-lihas.gpg | apt-key add -
  fi
}
