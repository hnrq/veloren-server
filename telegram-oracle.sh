#!/bin/sh
KEY_PATH="usr/.telegram-oracle-key"
MESSAGE_SENDER_PATH="usr/bin/telegram-oracle-report"
SERVICE_STATUS_PATH="usr/bin/telegram-service-status"
SERVICE_NAME="telegram-oracle.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

check_privileges() {
	if [ "$(id -u)" != 0 ]; then
		printf "\e[31m\e[1mThis script needs to be run as root for creating systemd services.\e[0m\n"
		exit
	fi
}

create_keys() {
	printf "Creating Telegram API key file at %s..." "$KEY_PATH"
	mkdir -p "$(dirname "$KEY_PATH")"
	printf "API_KEY=%s\nCHAT_ID=%s\n" "$API_KEY" "$CHAT_ID" >"$KEY_PATH"
	printf "\e[32m\e[1mDone\e[0m\n"
}

create_message_sender() {
	printf "Creating Telegram message sender script..."

	mkdir -p "$(dirname "$SERVICE_STATUS_PATH")"

	cat <<-EOF >"$MESSAGE_SENDER_PATH"
		#!/bin/sh
		source $KEY_PATH
		URL="https://api.telegram.org/bot\$API_KEY/sendMessage"
		curl -s -d "chat_id=\$CHAT_ID&disable_web_page_preview=1&text=\$1" \$URL >/dev/null
	EOF

	chmod +x "$MESSAGE_SENDER_PATH"

	printf "\e[32m\e[1mDone\e[0m\n"
}

create_service_status() {
	printf "Creating Service status reporter script..."

	mkdir -p "$(dirname "$SERVICE_STATUS_PATH")"

	cat <<-EOF >"$SERVICE_STATUS_PATH"
		#!/bin/sh
		UNIT=\$1
		$MESSAGE_SENDER_PATH "\u26A0\uFE0F Unit failed \$UNIT \u26A0\uFE0F $(systemctl status "\$UNIT")"
	EOF

	chmod +x "$SERVICE_STATUS_PATH"

	printf "\e[32m\e[1mDone\e[0m\n"
}

create_oracle_service() {
	cat <<-"EOF" >"$SERVICE_PATH"
		[Unit]
		Description=Unit Status Telegram Service
		After=network.target

		[Service]
		Type=simple
		ExecStart=$HOME/bin/unit-status-telegram %I
	EOF

	systemctl enable "$SERVICE_NAME"
	systemctl start "$SERVICE_NAME"
}

remove_keys() {
	rm "$KEY_PATH"
}

remove_scripts() {
	rm "$MESSAGE_SENDER_PATH"
	rm "$SERVICE_STATUS_PATH"
}

disable_services() {
	systemctl stop "$SERVICE_NAME"
	systemctl disable "$SERVICE_NAME"

	rm "$SERVICE_PATH"
}

install() {
	create_keys
	create_message_sender
	create_unit_status

	printf "\n\e[32m\e[1mSuccessfully installed Telegram oracle.\e[0m"
}

purge() {
	remove_keys
	remove_scripts
	disable_services
}

printf "This is the setup for the server oracle, a tool that sends a message on Telegram if anything goes wrong with your server. If you don't have already, create a bot using @botfather on Telegram.\n\n"

sed -i '/^StartLimitIntervalSec=0/a OnFailure=unit-status-telegram@%n.service' "$HOME/.config/systemd/user/veloren-server.service"
