## Veloren RPi Server Creator
This is a tool for setting up a Systemd veloren server w/ a single command on a RPi (aarch64). Sudo is
needed since it creates three new services: 
 - `veloren-server.service`: Responsible for starting the server itself
 - `oneshot-update-veloren-server.service`: oneshot service that triggers an update-check
 - `veloren-server.timer`: Triggers `oneshot-update-veloren-server.service` every 15 minutes

I moved the service restart to `update_veloren_server` because it will only download the update and
restart `veloren-server.service` if the hashes are different.

```sh
git clone https://github.com/hnrq/vlrn-rpi.git
cd vlrn-rpi
sudo ./setup_server
```
