#!/bin/sh
cp -v assets/veloren-server/update-veloren /usr/bin/update-veloren

cp -v assets/veloren-server/*.{service,timer,socket} /etc/systemd/system 2>/dev/null

read -e -p "Provide a server name:" -i "production" SERVER_NAME

read -p "Do you wish to install Telegram Oracle (Y/n)? " yn
case $yn in
[Nn]*) ;;
*)
  (
    cd assets/telegram-msg
    ./setup-telegram-msg
  )
  sed -i '/^StartLimitIntervalSec=0/a OnFailure=unit-status-telegram@%n.service' /etc/systemd/system/"veloren@$SERVER_NAME.service"
  ;;
esac

systemctl enable "veloren@$SERVER_NAME.service"
systemctl start "veloren@$SERVER_NAME.service"

systemctl enable "veloren@$SERVER_NAME.socket"
systemctl start "veloren@$SERVER_NAME.socket"

systemctl enable "veloren@$SERVER_NAME.timer"
systemctl start "veloren@$SERVER_NAME.timer"
