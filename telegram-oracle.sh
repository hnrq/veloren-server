#!/bin/sh
KEY_PATH="/etc/telegram/key"
MESSAGE_SENDER_PATH="/usr/bin/telegram-oracle-report"
SERVICE_STATUS_PATH="/usr/bin/telegram-service-status"
SERVICE_NAME="telegram-oracle.service"

setup_keys() {
	printf "\nCreating Telegram API key file..."
	read -r "Please enter the file path for saving your keys (default: $KEY_PATH): " KEY_PATH
	mkdir -p "$(dirname "$KEY_PATH")" && touch "$KEY_PATH"
	printf "API_KEY=%s\nCHAT_ID=%s\n" "$API_KEY" "$CHAT_ID" >"$KEY_PATH"
	printf "\e[32m\e[1mDone!\e[0m"
}

setup_message_sender() {
	printf "\nCreating Telegram message sender script..."

	cat <<-EOF >"$MESSAGE_SENDER_PATH"
		#!/bin/sh
		source $KEY_PATH
		URL="https://api.telegram.org/bot\$API_KEY/sendMessage"
		curl -s -d "chat_id=\$CHAT_ID&disable_web_page_preview=1&text=\$1" \$URL >/dev/null
	EOF

	chmod +x "$MESSAGE_SENDER_PATH"

	printf "\e[32m\e[1mDone!\e[0m"
}

setup_service_status() {
	cat <<-EOF >"$SERVICE_STATUS_PATH"
		#!/bin/sh
		UNIT=\$1
		$MESSAGE_SENDER_PATH "\u26A0\uFE0F Unit failed \$UNIT \u26A0\uFE0F $(systemctl status "\$UNIT")"
	EOF
}

setup_oracle_service() {
	cat <<-"EOF" >"/etc/systemd/system/$SERVICE_NAME"
		[Unit]
		Description=Unit Status Telegram Service
		After=network.target

		[Service]
		Type=simple
		ExecStart=/usr/bin/unit-status-telegram %I
	EOF

	systemctl enable "$SERVICE_NAME"
	systemctl start "$SERVICE_NAME"
}

printf "This is the setup for the server oracle, a tool that sends a message on Telegram if anything goes wrong with your server. If you don't have already, create a bot using @botfather on Telegram.\n\n"

setup_keys
setup_message_sender
setup_unit_status

sed -i '/^StartLimitIntervalSec=0/a OnFailure=unit-status-telegram@%n.service' /etc/systemd/system/veloren-server.service
