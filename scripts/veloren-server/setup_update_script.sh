#!/bin/sh
VELOREN_INSTALL_DIR=$1
SCRIPT_DIR=$2

cat <<-'EOF' >"$SCRIPT_DIR"
  #!/bin/bash
  REMOTE_VER="$(curl -s 'https://download.veloren.net/version/linux/aarch64/weekly')"
  FORCE_UPDATE="false"
  FILENAME="veloren-aarch64"
EOF

cat <<-EOF >>"$SCRIPT_DIR"
  INSTALL_DIR=$VELOREN_INSTALL_DIR
EOF

cat <<-'EOF' >>"$SCRIPT_DIR"

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
      echo -e "\e[32m\e[1mYour server is up-to-date :)\e[0m"
  else
      echo $REMOTE_VER > $INSTALL_DIR/version

      (cd $INSTALL_DIR && curl -L -o $FILENAME --connect-timeout 30 --max-time 30 --retry 300 --retry-delay 5 'https://download.veloren.net/latest/linux/aarch64/weekly')
      (cd $INSTALL_DIR && unzip -qo $FILENAME)
      (cd $INSTALL_DIR && rm -rf $FILENAME)

      systemctl restart veloren-server.service

      echo -e "\e[32m\e[1mSuccessfully updated server to latest version ($REMOTE_VER)\e[0m"
  fi
EOF
