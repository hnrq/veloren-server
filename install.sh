#!/bin/sh
VELOREN_INSTALL_DIR="/usr/veloren-server" # this is where the server files will be installed

check_privileges() {
  if [ "$(id -u)" != 0 ]; then
    echo "Please run as root"
    exit
  fi
}

setup_update_script() {
  SCRIPT_LOCATION="/usr/bin/update_veloren_server" # this is where the update script will be installed

  echo "Creating update script at $SCRIPT_LOCATION..."
  ./scripts/veloren-server/setup_update_script.sh $VELOREN_INSTALL_DIR $SCRIPT_LOCATION
  chmod +x $SCRIPT_LOCATION
  echo "Done!"

  echo "Running update script to install Veloren server..."
  $SCRIPT_LOCATION -f # run the script once to download the server files
  echo "Done!"
}

server_exists() {
  if [ -d "$VELOREN_INSTALL_DIR/veloren-server-cli" ]; then
    read -r "There is already a Veloren server installed at this location. Do you wish to overwrite it (y/N)? " yn
    case $yn in
    [Yy]*) ;;
    *) exit ;;
    esac
  fi
}

setup_systemd_services() {
  echo "Creating systemd service files..."
  ./scripts/veloren-server/setup_services.sh $VELOREN_INSTALL_DIR
  echo "Done!"
}

enable_systemd_services() {
  echo "Enabling systemd services..."
  systemctl enable veloren-server.service
  systemctl start veloren-server.service

  systemctl enable veloren-server.timer
  systemctl start veloren-server.timer
  echo "Done"
}

install_telegram_oracle() {
  read -r "Do you wish to install Telegram Oracle (Y/n)? " yn
  case $yn in
  [Nn]*) exit ;;
  *)
    (
      cd scripts/telegram-msg || exit
      ./setup-telegram-msg
    )
    sed -i '/^StartLimitIntervalSec=0/a OnFailure=unit-status-telegram@%n.service' /etc/systemd/system/veloren-server.service
    return
    ;;
  esac
}

check_privileges
echo "This is the ARM Veloren server setup script. It will install the Veloren server and configure it to run as a service."

read -r "Please enter the directory you want to install the server to (default: $VELOREN_INSTALL_DIR): " VELOREN_INSTALL_DIR
VELOREN_INSTALL_DIR=${VELOREN_INSTALL_DIR:-/usr/veloren-server}

server_exists "$VELOREN_INSTALL_DIR"
setup_update_script
setup_services
