setup_bird() {
  if grep -q "router id 10.191.255.$GWID;" /etc/bird/bird.conf; then
    sed -i 's/^router id .*/router id 10.191.255.'$(($GWID*10+$GWSUBID))';/' /etc/bird/bird.conf
  fi
  if grep -q "router id 10.191.255.$GWID;" /etc/bird/bird6.conf; then
    sed -i 's/^router id .*/router id 10.191.255.'$(($GWID*10+$GWSUBID))';/' /etc/bird/bird6.conf
  fi
  systemctl enable bird
  systemctl enable bird6
}
