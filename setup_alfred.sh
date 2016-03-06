setup_alfred_startup() {
cat <<EOF
***********************************************************************
FIXME: sauberes init-Skript in alfred-Paket bauen
#***********************************************************************
EOF

if [ ! -e /etc/systemd/system/alfred@.service ]; then
  cat <<'EOF' >/etc/systemd/system/alfred@.service
[Unit]
Description=A.L.F.R.E.D
After=network.target
ConditionPathExists=/usr/sbin/alfred

[Service]
EnvironmentFile=/etc/default/alfred
ExecStart=/usr/sbin/alfred -u /var/run/alfred-%I.sock -i %I -b %I --master
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
Alias=alfred.service
EOF
systemctl daemon-reload
fi
}
