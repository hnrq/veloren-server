#!/bin/sh
VELOREN_INSTALL_DIR="/usr/veloren-server"           # this is where the server files will be installed
UPDATE_SCRIPT_PATH="/usr/bin/update-veloren-server" # this is where the update script will be installed
SERVICE_DIR="/etc/systemd/system"                   # this is where the systemd services will be added
SERVICE_NAME="veloren-server"                       # this is the systemd service name

check_privileges() {
	if [ "$(id -u)" != 0 ]; then
		printf "\e[31m\e[1mThis script needs to be run as root.\e[0m\n"
		exit
	fi
}

check_dependencies() {
	DEPENDENCIES="unzip"
	DEPENDENCIES_MISSING=0
	for DEPENDENCY in ${DEPENDENCIES}; do
		if ! command -v "${DEPENDENCY}" >/dev/null 2>&1; then
			printf "\e[31m\e[1mDependency %s could not be found\e[0m\n" "$DEPENDENCY"
			DEPENDENCIES_MISSING=1
		fi
	done

	if [ $DEPENDENCIES_MISSING = 1 ]; then
		printf "\e[31m\e[1mSome dependencies need to be installed before running\e[0m\n"
		exit
	fi
}

create_update_script() {
	printf "\nCreating update script at %s..." "$UPDATE_SCRIPT_PATH"

	mkdir -p "$(dirname "$UPDATE_SCRIPT_PATH")"

	cat <<-'EOF' >"$UPDATE_SCRIPT_PATH"
		#!/bin/bash
		FORCE_UPDATE="false"
		ARCHITECTURE="$(uname -m)"
		FILENAME="veloren-$ARCHITECTURE"
		REMOTE_VER="$(curl -s "https://download.veloren.net/version/linux/$ARCHITECTURE/weekly")"
	EOF

	{
		cat <<-EOF
			VELOREN_INSTALL_DIR=$VELOREN_INSTALL_DIR
			SERVICE_NAME=$SERVICE_NAME
		EOF
		cat <<-'EOF'

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

			if [[ $REMOTE_VER = "$(cat $VELOREN_INSTALL_DIR/version 2>/dev/null)" && $FORCE_UPDATE == "false" ]]; then
					printf "\n\e[32m\e[1mYour server is up-to-date!\e[0m\n"
			else
					printf "\nDownloading Veloren server version %s...\n" "$REMOTE_VER"
					curl -#L -o "$VELOREN_INSTALL_DIR/$FILENAME" --connect-timeout 30 --max-time 30 --retry 300 --retry-delay 5 "https://download.veloren.net/latest/linux/$ARCHITECTURE/weekly"
					unzip -qo "$VELOREN_INSTALL_DIR/$FILENAME" -d "$VELOREN_INSTALL_DIR" && rm $VELOREN_INSTALL_DIR/$FILENAME

					# Restart System
					if [[ $(systemctl list-units --all -t service --full --no-legend "$SERVICE_NAME.service" | sed 's/^\s*//g' | cut -f1 -d' ') == $SERVICE_NAME.service ]]; then
						systemctl restart "$SERVICE_NAME.service"
					fi

					printf "\e[32m\e[1mSuccessfully downloaded latest version (%s)\e[0m\n" "$REMOTE_VER"
					printf "%s" "$REMOTE_VER" > "$VELOREN_INSTALL_DIR/version"
			fi
		EOF
	} >>"$UPDATE_SCRIPT_PATH"

	chmod +x "$UPDATE_SCRIPT_PATH"
	$UPDATE_SCRIPT_PATH # run the script once to download the server files
}

create_systemd_services() {
	printf "Creating systemd service files..."

	cat <<-EOF >"$SERVICE_DIR/$SERVICE_NAME.socket"
		[Unit]
		BindsTo=$SERVICE_NAME.service

		[Socket]
		ListenFIFO=%t/$SERVICE_NAME.stdin
		Service=$SERVICE_NAME.service
		RemoveOnStop=true
		SocketMode=0600
	EOF

	cat <<-EOF >"$SERVICE_DIR/$SERVICE_NAME.service"
		[Unit]
		Description=Veloren Server
		After=network.target

		[Service]
		Type=simple
		WorkingDirectory=$VELOREN_INSTALL_DIR
		ExecStart=/bin/sh -c "$VELOREN_INSTALL_DIR/veloren-server-cli"
		ExecStop=/bin/sh -c "echo 'shutdown graceful 60' >/run/$SERVICE_NAME.stdin"

		Sockets=$SERVICE_NAME.socket
		StandardInput=socket
		StandardOutput=journal
		StandardError=journal

		Restart=on-failure
		RestartSec=60s

		# this is necessary to keep systemd from killing the process before it exits after ExecStop is called
		KillSignal=SIGCONT

		[Install]
		WantedBy=multi-user.target
	EOF

	cat <<-EOF >"$SERVICE_DIR/$SERVICE_NAME.timer"
		[Unit]
		Description=Run update-veloren-server periodically

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

	printf "\e[32m\e[1mDone\e[0m\n"
}

enable_systemd_services() {
	printf "Enabling systemd services..."
	systemctl enable "$SERVICE_NAME.service"
	systemctl start "$SERVICE_NAME.service"

	systemctl enable "$SERVICE_NAME.timer"
	systemctl start "$SERVICE_NAME.timer"
	systemctl daemon-reload
	printf "\e[32m\e[1mDone\e[0m\n"
}

disable_services() {
	echo "shutdown immediate" >"/run/$SERVICE_NAME.stdin"
	systemctl stop "$SERVICE_NAME.service"
	systemctl stop "$SERVICE_NAME.timer"
	systemctl stop "oneshot-update-$SERVICE_NAME.service"
	systemctl disable "$SERVICE_NAME.service"
	systemctl disable "$SERVICE_NAME.timer"
	systemctl disable "oneshot-update-$SERVICE_NAME.service"

	find "$SERVICE_DIR" -type f -name "*$SERVICE_NAME*" -delete
}

remove_update_script() {
	rm "$UPDATE_SCRIPT_PATH"
}

remove_server_files() {
	rm -rf "$VELOREN_INSTALL_DIR"
}

purge() {
	disable_services
	remove_update_script
	remove_server_files

	printf "\e[32m\e[1mSuccessfully purged Veloren server.\e[0m\n"
}

install() {
	printf "This is the Systemd Veloren server setup script. It will install the Veloren server and configure it to run as a daemon service.\n"

	check_dependencies
	create_update_script
	create_systemd_services
	enable_systemd_services

	printf "\e[32m\e[1mSuccessfully installed Veloren server at %s.\e[0m\n" "$VELOREN_INSTALL_DIR"
}

check_privileges

if [ "$1" = --purge ]; then
	purge
else
	install
fi
