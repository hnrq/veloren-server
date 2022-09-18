#!/bin/sh
VELOREN_INSTALL_DIR="/usr/veloren-server" # this is where the server files will be installed

check_privileges() {
	if [ "$(id -u)" != 0 ]; then
		printf "Please run as root"
		exit
	fi
}

setup_update_script() {
	SCRIPT_PATH="/usr/bin/update_veloren_server" # this is where the update script will be installed
	INSTALL_DIR=$1
	printf "\nCreating update script at %s..." "$SCRIPT_PATH"

	cat <<-'EOF' >"$SCRIPT_PATH"
		#!/bin/bash
		REMOTE_VER="$(curl -s 'https://download.veloren.net/version/linux/aarch64/weekly')"
		FORCE_UPDATE="false"
		FILENAME="veloren-aarch64"
	EOF

	cat <<-EOF >>"$SCRIPT_PATH"
		INSTALL_DIR=$INSTALL_DIR
	EOF

	cat <<-'EOF' >>"$SCRIPT_PATH"

		mkdir -p $INSTALL_DIR

		while test "$#" -gt 0; do
			case "$1" in
			-f|--force) 
						FORCE_UPDATE="true"
						shift
						;;
				*)
						break
						;;
			esac
		done

		if [[ $REMOTE_VER = "$(cat $INSTALL_DIR/version)" && $FORCE_UPDATE == "false" ]]; then
				print -e "\e[32m\e[1mYour server is up-to-date!\e[0m"
		else
				printf "Downloading latest Veloren server version..."
				curl -sSL -o "$INSTALL_DIR/$FILENAME" --connect-timeout 30 --max-time 30 --retry 300 --retry-delay 5 'https://download.veloren.net/latest/linux/aarch64/weekly'
				unzip -qo "$INSTALL_DIR/$FILENAME" && rm $INSTALL_DIR/$FILENAME

				systemctl restart veloren-server.service

				print -e "\e[32m\e[1mSuccessfully updated server to latest version (%s)\e[0m" "$REMOTE_VER"
				print "$REMOTE_VER" > "$INSTALL_DIR/version"
		fi
	EOF

	chmod +x $SCRIPT_PATH
	$SCRIPT_PATH -f # run the script once to download the server files
	printf "\e[32m\e[1mDone!\e[0m"
}

setup_systemd_services() {
	INSTALL_DIR=$1
	SERVICE_DIR=/etc/systemd/system

	printf "\nCreating systemd service files..."

	cat <<-EOF >"$SERVICE_DIR/veloren-server.service"
		[Unit]
		Description=Veloren Server
		After=network.target
		StartLimitIntervalSec=0

		[Service]
		Type=simple
		WorkingDirectory=$INSTALL_DIR
		ExecStart=$INSTALL_DIR/veloren-server-cli

		[Install]
		WantedBy=multi-user.target
	EOF

	cat <<-EOF >"$SERVICE_DIR/veloren-server.timer"
		[Unit]
		Description=Run update_veloren_server periodically

		[Timer]
		Unit=oneshot-update-veloren.service
		OnCalendar=*:0/15

		[Install]
		WantedBy=timers.target
	EOF

	cat <<-EOF >"$SERVICE_DIR/oneshot-update-veloren.service"
		[Unit]
		Description=One shot update Veloren server service

		[Service]
		Type=oneshot
		ExecStart=/usr/bin/update_veloren_server

		[Install]
		WantedBy=multi-user.target
	EOF

	printf "\e[32m\e[1mDone!\e[0m"
}

enable_systemd_services() {
	printf "\nEnabling systemd services..."
	systemctl enable veloren-server.service
	systemctl start veloren-server.service

	systemctl enable veloren-server.timer
	systemctl start veloren-server.timer
	printf "\e[32m\e[1mDone!\e[0m"
}

check_privileges
printf "This is the ARM Veloren server setup script. It will install the Veloren server and configure it to run as a service."

read -r "Please enter the directory you want to install the server to (default: $VELOREN_INSTALL_DIR): " VELOREN_INSTALL_DIR
VELOREN_INSTALL_DIR=${VELOREN_INSTALL_DIR:-/usr/veloren-server}

setup_update_script "$VELOREN_INSTALL_DIR"
setup_systemd_services "$VELOREN_INSTALL_DIR"
enable_systemd_services
