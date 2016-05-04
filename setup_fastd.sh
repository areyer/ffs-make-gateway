setup_fastd() {
  if ! getent passwd fastd 2>/dev/null 1>&2; then
    adduser --system --no-create-home fastd
  fi

  cat <<'EOF' >/etc/systemd/system/fastd@.service
[Unit]
Description=Fast and Secure Tunnelling Daemon (connection %I)
After=network.target

[Service]
Type=notify
ExecStartPre=/bin/mkdir -p /var/run/fastd
ExecStartPre=/bin/chown fastd /var/run/fastd
ExecStartPre=/bin/rm -f /var/run/fastd/fastd-%I.sock
ExecStart=/usr/bin/fastd --syslog-level debug2 --syslog-ident fastd@%I -c /etc/fastd/%I/fastd.conf --pid-file /var/run/fastd/fastd-%I.pid --status-socket /var/run/fastd/fastd-%I.sock --user fastd
ExecStop=/sbin/kill $(cat /var/run/fastd/fastd-%I.pid)
ExecReload=/bin/kill -HUP $(cat /var/run/fastd/fastd-%I.pid)
ExecStop=/bin/kill $(cat /var/run/fastd/fastd-%I.pid)

[Install]
WantedBy=multi-user.target
EOF
}
setup_fastd_config() {
for i in $(seq 0 4); do
  VPNID=$(printf "%02i" $i)
  if [ $i -eq 0 ]; then
    VPNPORT=10037
  else
    VPNPORT=1004$i
  fi
  dir=/etc/fastd/vpn$VPNID
  mkdir -p $dir
  cat <<EOF >$dir/fastd.conf
log to syslog level warn;
interface "vpn$VPNID";
method "salsa2012+gmac";    # new method, between gateways for the moment (faster)
method "salsa2012+umac";  
$(for a in $EXT_IP_V4; do echo bind $a:$VPNPORT\;; done)
$(for a in $EXT_IPS_V6; do echo bind [$a]:$VPNPORT\;; done)

include "/etc/fastd/ffs-vpn/secret.conf";
mtu 1406; # 1492 - IPv4/IPv6 Header - fastd Header...
on verify "/root/freifunk/unclaimed.py";
status socket "/var/run/fastd/fastd-vpn$VPNID.sock";
include peers from "/etc/fastd/ffs-vpn/peers/vpn$VPNID/peers";
EOF
done
}
setup_fastd_bb() {
  mkdir -p /etc/fastd
  if [ ! -e /etc/fastd/fastdbb.key ]; then
    VPNBBKEY=$(fastd --generate-key --machine-readable)
    printf 'secret "%s";' $VPNBBKEY > /etc/fastd/fastdbb.key
  else
    VPNBBKEY=$(sed -n '/secret/{ s/.* "//; s/".*//; p}' /etc/fastd/fastdbb.key)
  fi
  for i in $(seq 0 $SEGMENTS); do
    seg=$(printf '%02i' $i)
    mkdir -p /etc/fastd/bb$seg
    cat <<-EOF >/etc/fastd/bb$seg/fastd.conf
	log to syslog level warn;
	interface "bb$seg";
	method "salsa2012+gmac";    # new method, between gateways for the moment (faster)
	method "salsa2012+umac";  
	bind $(printf '0.0.0.0:9%03i' $i);
	bind $(printf '[::]:9%03i' $i);
	include "/etc/fastd/fastdbb.key";
	mtu 1406; # 1492 - IPv4/IPv6 Header - fastd Header...
	on verify "/root/freifunk/unclaimed.py";
	status socket "/var/run/fastd/fastd-bb$seg";
	include peers from "/etc/fastd/ffs-vpn/peers/vpn$seg/bb";
EOF
    VPNBBPUB=$(fastd -c /etc/fastd/bb$seg/fastd.conf --show-key --machine-readable)
    if [ ! -e /root/git/peers-ffs/vpn$seg/bb/$HOSTNAME ] || ! grep $VPNBBPUB /root/git/peers-ffs/vpn$seg/bb/$HOSTNAME; then
      cat <<-EOF >/root/git/peers-ffs/vpn$seg/bb/${HOSTNAME}s$seg
	key "$VPNBBPUB";
	remote "${HOSTNAME}.freifunk-stuttgart.de" port $(printf '9%03i' $i);
EOF
    fi
    cat <<-EOF >/etc/network/interfaces.d/bb$seg
	allow-hotplug bb$seg
	iface bb$seg inet6 manual
		hwaddress 02:00:0a:37:00:${GWLID}
		pre-up		/sbin/modprobe batman_adv || true
	        pre-up          /sbin/ip link set \$IFACE address 02:00:37:$seg:$GWLID:$GWLSUBID up || true
	        post-up         /sbin/ip link set dev \$IFACE up || true
	        post-up         /usr/sbin/batctl -m bat$seg if add \$IFACE || true
EOF
  done
  (
    cd /root/git/peers-ffs
    if LC_ALL=C git status | egrep -q "($HOSTNAME|ahead)"; then
      git add .
      git commit -m "bb $HOSTNAME" -a
      git remote set-url origin git@github.com:freifunk-stuttgart/peers-ffs.git https://github.com/freifunk-stuttgart/peers-ffs
      git push
      git remote set-url origin https://github.com/freifunk-stuttgart/peers-ffs git@github.com:freifunk-stuttgart/peers-ffs.git
    fi
  )
}
setup_fastd_key() {
mkdir -p /etc/fastd/ffs-vpn/peers
if [ "$VPNKEY" == "Wird generiert" ] && [ ! -e /etc/fastd/ffs-vpn/secret.conf ]; then
  VPNKEY=$(fastd --generate-key --machine-readable)
  cat <<EOF >/etc/fastd/ffs-vpn/secret.conf
secret "$VPNKEY";
EOF
elif [ "$VPNKEY" != "Wird generiert" ]; then
  cat <<EOF >/etc/fastd/ffs-vpn/secret.conf
secret "$VPNKEY";
EOF
else
  VPNKEY=$(sed -n '/secret/{ s/.* "//; s/".*//; p}' /etc/fastd/ffs-vpn/secret.conf)
fi
}
setup_fastd_update() {
  cat <<'EOF' >/usr/local/bin/fastd-update
#!/bin/bash

export LC_ALL=C
cd /root/git/peers-ffs
git pull >/dev/null
rsync -rlHpogDtSv --exclude="peers/gw*" --exclude=".git" --delete --delete-excluded ./ /etc/fastd/ffs-vpn/peers/ 2>&1 |
sed -n '/^deleting vpn/{s/^deleting //; s/\/.*//; p}' |
sort -u |
sed 's#/.*##' | sort -u | while read vpninstance; do
  systemctl restart fastd@$vpninstance
done

# fastd Config reload
killall -HUP fastd
EOF
  chmod +x /usr/local/bin/fastd-update
  cat <<'EOF' >/etc/cron.d/fastd-update 
*/5 * * * * root /usr/local/bin/fastd-update
EOF
}
setup_fastd_status() {
cat <<'EOF' >/usr/local/bin/fastd-status
#!/usr/bin/perl
use strict;
use JSON::XS;
use DBI;
use Data::Dump qw(dump);
my $DBFILE="/var/lib/misc/fastd-stats.sqlite";
my $fastd_status_string = "";

use IO::Socket::UNIX qw( SOCK_STREAM );

$ARGV[0] or die("Usage: status.pl <socket>\n");

my $socket = IO::Socket::UNIX->new(
   Type => SOCK_STREAM,
   Peer => $ARGV[0],
) or die("Can't connect to server: $!\n");

foreach my $line (<$socket>) {
         $fastd_status_string .= $line;
}

my $dbh = DBI->connect("dbi:SQLite:dbname=$DBFILE","","");
$dbh->do("CREATE TABLE IF NOT EXISTS fastd_last_connected (pubkey TEXT PRIMARY KEY ON CONFLICT REPLACE, time integer)");
$dbh->do("CREATE TABLE IF NOT EXISTS fastd_mac (pubkey TEXT PRIMARY KEY ON CONFLICT REPLACE, mac TEXT)");
$dbh->do("CREATE TABLE IF NOT EXISTS fastd_name (pubkey TEXT PRIMARY KEY ON CONFLICT REPLACE, name TEXT)");
$dbh->do("CREATE TABLE IF NOT EXISTS fastd_gw (pubkey TEXT PRIMARY KEY ON CONFLICT REPLACE, gw TEXT)");
my $time = time();
my $sth_connected = $dbh->prepare("INSERT OR REPLACE INTO fastd_last_connected (pubkey,time) VALUES (?,?)");
my $sth_mac = $dbh->prepare("INSERT OR REPLACE INTO fastd_mac (pubkey,mac) VALUES (?,?)");
my $sth_get_mac = $dbh->prepare("SELECT * FROM fastd_mac WHERE pubkey=?");
my $sth_name = $dbh->prepare("INSERT OR REPLACE INTO fastd_name (pubkey,name) VALUES (?,?)");
my $sth_gw = $dbh->prepare("INSERT OR REPLACE INTO fastd_gw (pubkey,gw) VALUES (?,?)");

my @fastd_status = decode_json($fastd_status_string);
foreach my $peer ( keys (%{$fastd_status[0]{peers}})) {
        if (defined($fastd_status[0]{peers}{$peer}{connection})) {
                my $address = $fastd_status[0]{peers}{$peer}{address};
                $address =~s/:[^:]*$//;
                # print "$peer\t".$address."\t".$fastd_status[0]{peers}{$peer}{name}."\t".$fastd_status[0]{peers}{$peer}{connection}{mac_addresses}[0]."\n";
                $sth_connected->execute($peer,$time);
                $sth_mac->execute($peer,$fastd_status[0]{peers}{$peer}{connection}{mac_addresses}[0]);
        } else {
        }
        $sth_name->execute($peer,$fastd_status[0]{peers}{$peer}{name});
}
my $sth = $dbh->prepare("SELECT name,mac FROM fastd_name JOIN fastd_last_connected ON fastd_name.pubkey=fastd_last_connected.pubkey JOIN fastd_mac ON fastd_name.pubkey=fastd_mac.pubkey WHERE time<(SELECT MAX(fastd_last_connected.time) FROM fastd_last_connected)");
my ($mac, $name);
$sth->execute();
$sth->bind_columns(\$name,\$mac);
while ( $sth->fetch ) {
        print "$name\t$mac\n";
}
EOF
chmod +x /usr/local/bin/fastd-status
}
