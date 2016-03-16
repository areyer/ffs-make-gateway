setup_monitoring() {
sed -i '/^ffs-gw-dhcpsrv/d; /^ffs-vpn_batman/d' /etc/check_mk/mrpe.cfg
ensureline "ffs-bird /etc/check_mk/ffs/ffs-bird" /etc/check_mk/mrpe.cfg
ensureline "ffs-bird6 /etc/check_mk/ffs/ffs-bird6" /etc/check_mk/mrpe.cfg
for seg in $(seq 1 $SEGMENTS); do
  ensureline "fastd-$(printf "%02i" $seg) /etc/check_mk/ffs/ffs-check-fastdpeers --fastdsocket=/var/run/fastd/fastd-vpn$(printf "%02i" $seg).sock" /etc/check_mk/mrpe.cfg
  ensureline "alfred-$(printf "%02i" $seg) /etc/check_mk/ffs/ffs-check-alfred --interface bat$(printf "%02i" $seg)" /etc/check_mk/mrpe.cfg
done
}