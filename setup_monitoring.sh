setup_monitoring() {
mkdir -p /etc/check_mk
[ ! -e /etc/check_mk/mrpe.cfg ] && touch /etc/check_mk/mrpe.cfg
sed -i '/^ffs-gw-dhcpsrv/d; /^ffs-vpn_batman/d' /etc/check_mk/mrpe.cfg
ensureline "ffs-bird /etc/check_mk/ffs/ffs-bird" /etc/check_mk/mrpe.cfg
ensureline "ffs-bird6 /etc/check_mk/ffs/ffs-bird6" /etc/check_mk/mrpe.cfg
for seg in $(seq 0 $SEGMENTS); do
  ensureline "fastd-$(printf "%02i" $seg) /etc/check_mk/ffs/ffs-check-fastdpeers --fastdsocket=/var/run/fastd/fastd-vpn$(printf "%02i" $seg).sock" /etc/check_mk/mrpe.cfg
  ensureline "alfred-$(printf "%02i" $seg) /etc/check_mk/ffs/ffs-check-alfred --interface $(printf "%02i" $seg)" /etc/check_mk/mrpe.cfg
done
}
cat <<'EOF' >/usr/local/bin/gw-watchdog
#!/bin/bash

( LC_ALL=C

error () {
        echo "ERROR $*"
}

[ -e /etc/default/freifunk ] && . /etc/default/freifunk

# check ffsbb-tinc
# pid of tinc
TINC_PID=$(ps x | awk '$5 ~ /tincd$/ && /-n ffsbb/ {print $1}')
if [ 'x'"$TINC_PID" == 'x' ]; then
        # no tinc, restart
        error "tinc ffsbb down, restart"
        /sbin/ifdown --force ffsbb
        /sbin/ifup ffsbb
fi
if ! host www.freifunk-stuttgart.de 127.0.0.1 > /dev/null 2>&1; then
	killall rndc
	killall -9 named
	/usr/sbin/service bind9 restart
fi
# check interfaces
# 'auto'-interfaces must be present
INTERFACES="$INTERFACES $(egrep -h '^(auto|allow-hotplug)' /etc/network/interfaces.d/* /etc/network/interfaces | sed 's/^\(auto\|allow-hotplug\)[ \t]*//')"
for iface in $INTERFACES; do
        case $iface in
                vpn*|bb*)
                        # fastd muss laufen
                        if ! systemctl status fastd@$iface >/dev/null; then
                                error "/sbin/ifdown --force $iface"
                                /sbin/ifdown --force $iface
                                error "systemctl start fastd@$iface"
                                systemctl start fastd@$iface
                        fi
                        # batman muss das Interface haben
                        BATIF=bat$(sed 's/\(vpn\|bb\|ip6\)//g' <<<$iface)
                        if ! /usr/sbin/batctl -m $BATIF if | grep -q "$iface:"; then
                                error "/usr/sbin/batctl -m $BATIF if add $iface"
                                /usr/sbin/batctl -m $BATIF if add $iface
                        fi
                        ;;
        esac
        if ! ip l l dev $iface | egrep -q 'state (UP|UNKNOWN)'; then
                /sbin/ifdown --force $iface
                /sbin/ifup $iface
        fi
done
if ! pgrep named > /dev/null; then
	service bind9 restart
fi
if ! host www.freifunk-stuttgart.de 127.0.0.1 > /dev/null 2>&1; then
	killall rndc
	killall -9 named
	/usr/sbin/service bind9 restart
fi
) 2>&1 | logger --tag "$0"
EOF
chmod +x /usr/local/bin/gw-watchdog
ensureline "* * * * * root /usr/local/bin/gw-watchdog" /etc/cron.d/gw-watchdog
apt-get -y install munin-node jq
ensureline "allow ^10\.191\.255\.241$" /etc/munin/munin-node.conf
ensureline "allow ^10\.191\.255\.242$" /etc/munin/munin-node.conf
ensureline "allow ^10\.191\.255\.243$" /etc/munin/munin-node.conf
cat <<'EOF' >/etc/munin/plugin-conf.d/freifunk
[fastdall]
user root
EOF
wget http://gw08.albi.info/dl/status.pl -O/usr/local/bin/status.pl; chmod +x /usr/local/bin/status.pl
wget http://gw08.albi.info/dl/dhcp-clients -O/usr/share/munin/plugins/dhcp-clients; chmod +x /usr/share/munin/plugins/dhcp-clients
wget http://gw08.albi.info/dl/fastdall -O/usr/share/munin/plugins/fastdall; chmod +x /usr/share/munin/plugins/fastdall
[ ! -e /etc/munin/plugins/dhcp-clients ] && ln -s /usr/share/munin/plugins/dhcp-clients /etc/munin/plugins/dhcp-clients
[ ! -e /usr/share/munin/plugins/fastdall ] && ln -s /usr/share/munin/plugins/fastdall /etc/munin/plugins/fastdall
service munin-node restart
