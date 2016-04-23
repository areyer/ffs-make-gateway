setup_alfred_startup() {
cat <<EOF
***********************************************************************
FIXME: sauberes init-Skript in alfred-Paket bauen
#***********************************************************************
EOF

  cat <<'EOF' >/etc/systemd/system/alfred.service
[Unit]
Description=A.L.F.R.E.D
After=network.target
ConditionPathExists=/usr/sbin/alfred

[Service]
# EnvironmentFile=/etc/default/alfred
ExecStart=/usr/sbin/alfred -u /var/run/alfred.sock -i br00,br01,br02,br03,br04 -b none --master
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
Alias=alfred.service
EOF
cat <<'EOF' >/etc/systemd/system/batadv-vis@.service
[Unit]
Description=batadv-vis
After=alfred@%I.service
ConditionPathExists=/usr/sbin/batadv-vis

[Service]
ExecStart=/usr/sbin/batadv-vis -i bat%I -u /var/run/alfred.sock -s
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
Alias=batadv-vis@%I.service
EOF
sed -i 's/alfred-vpn/batadv-vis@/' /etc/network/interfaces.d/ffs-seg*
systemctl daemon-reload
echo Alfred disabled
# systemctl enable alfred.service
}
