#!/bin/sh
VELOREN_DIR=$1
SERVICE_DIR=/etc/systemd/system

cat <<-EOF >>"$SERVICE_DIR/veloren-server.service"
  [Unit]
  Description=Veloren Server
  After=network.target
  StartLimitIntervalSec=0
    
  [Service]
  Type=simple
  WorkingDirectory=$VELOREN_DIR
  ExecStart=$VELOREN_DIR/veloren-server-cli

  [Install]
  WantedBy=multi-user.target
EOF

cat <<-EOF >>"$SERVICE_DIR/veloren-server.timer"
  [Unit]
  Description=Run update_veloren_server periodically

  [Timer]
  Unit=oneshot-update-veloren.service
  OnCalendar=*:0/15

  [Install]
  WantedBy=timers.target
EOF

cat <<-EOF >>"$SERVICE_DIR/oneshot-update-veloren.service"
  [Unit]
  Description=One shot update Veloren server service

  [Service]
  Type=oneshot
  ExecStart=/usr/bin/update_veloren_server

  [Install]
  WantedBy=multi-user.target
EOF
