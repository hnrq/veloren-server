#!/bin/sh
VELOREN_INSTALL_DIR="/usr/veloren-server"           # this is where the server files will be installed
UPDATE_SCRIPT_PATH="/usr/bin/update_veloren_server" # this is where the update script will be installed
SERVICE_DIR="/etc/systemd/system"                   # this is where the systemd services will be added
SERVICE_NAME="veloren-server"                       # this is the systemd service name

check_privileges() {
	if [ "$(id -u)" != 0 ]; then
		printf "\e[31m\e[1mThis script needs to be run as root for creating systemd services.\e[0m\n"
		exit
	fi
}

setup_update_script() {
	printf "\nCreating update script at %s..." "$UPDATE_SCRIPT_PATH"

	mkdir -p "$(dirname "$UPDATE_SCRIPT_PATH")"

	cat <<-'EOF' >"$UPDATE_SCRIPT_PATH"
		#!/bin/bash
		REMOTE_VER="$(curl -s 'https://download.veloren.net/version/linux/aarch64/weekly')"
		FORCE_UPDATE="false"
		FILENAME="veloren-aarch64"
	EOF

	cat <<-EOF >>"$UPDATE_SCRIPT_PATH"
		VELOREN_INSTALL_DIR=$VELOREN_INSTALL_DIR
	EOF

	cat <<-'EOF' >>"$UPDATE_SCRIPT_PATH"

		mkdir -p $VELOREN_INSTALL_DIR
		touch $VELOREN_INSTALL_DIR/version

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

		if [[ $REMOTE_VER = "$(cat $VELOREN_INSTALL_DIR/version)" && $FORCE_UPDATE == "false" ]]; then
				print -e "\n\e[32m\e[1mYour server is up-to-date!\e[0m"
		else
				printf "\nDownloading Veloren server version %s...\n" "$REMOTE_VER"
				curl -#L -o "$VELOREN_INSTALL_DIR/$FILENAME" --connect-timeout 30 --max-time 30 --retry 300 --retry-delay 5 'https://download.veloren.net/latest/linux/aarch64/weekly'
				unzip -qo "$VELOREN_INSTALL_DIR/$FILENAME" -d "$VELOREN_INSTALL_DIR" && rm $VELOREN_INSTALL_DIR/$FILENAME

				# Restart System
				if [[ $(systemctl list-units --all -t service --full --no-legend "$SERVICE_NAME@$USER.service" | sed 's/^\s*//g' | cut -f1 -d' ') == $SERVICE_NAME@$USER.service ]]; then
					systemctl restart "$SERVICE_NAME@$USER.service"
				fi

				printf "\e[32m\e[1mSuccessfully downloaded latest version (%s)\e[0m" "$REMOTE_VER"
				printf "%s" "$REMOTE_VER" > "$VELOREN_INSTALL_DIR/version"
		fi
	EOF
	chmod +x "$UPDATE_SCRIPT_PATH"
	$UPDATE_SCRIPT_PATH -f # run the script once to download the server files
}

setup_systemd_services() {
	printf "\nCreating systemd service files..."

	cat <<-EOF >"$SERVICE_DIR/$SERVICE_NAME.service"
		[Unit]
		Description=Veloren Server
		After=network.target
		StartLimitIntervalSec=0

		[Service]
		Type=simple
		WorkingDirectory=$VELOREN_INSTALL_DIR
		ExecStart=$VELOREN_INSTALL_DIR/veloren-server-cli

		[Install]
		WantedBy=multi-user.target
	EOF

	cat <<-EOF >"$SERVICE_DIR/$SERVICE_NAME.timer"
		[Unit]
		Description=Run update_veloren_server periodically

		[Timer]
		Unit="oneshot-update-$SERVICE_NAME.service"
		OnCalendar=*:0/15

		[Install]
		WantedBy=timers.target
	EOF

	cat <<-EOF >"$SERVICE_DIR/oneshot-update-$SERVICE_NAME.service"
		[Unit]
		Description=One shot update Veloren server service

		[Service]
		Type=oneshot
		ExecStart=$UPDATE_SCRIPT_PATH

		[Install]
		WantedBy=multi-user.target
	EOF

	printf "\e[32m\e[1mDone\e[0m"
}

enable_systemd_services() {
	printf "\nEnabling systemd services..."
	systemctl enable "$SERVICE_NAME.service"
	systemctl start "$SERVICE_NAME.service"

	systemctl enable "$SERVICE_NAME.timer"
	systemctl start "$SERVICE_NAME.timer"
	printf "\e[32m\e[1mDone\e[0m"
}

check_privileges

printf "This is the ARM Veloren server setup script. It will install the Veloren server and configure it to run as a service."

setup_update_script
setup_systemd_services
enable_systemd_services

printf "Successfully installed Veloren server at %s." "$VELOREN_INSTALL_DIR"
