## Veloren RPi Server Creator

This is a tool for setting up a Systemd veloren server w/ a single command on a RPi (aarch64). Sudo is
needed since it creates three new services:

- `veloren@.service`: Responsible for starting the server itself
- `oneshot-veloren@.service`: oneshot service that triggers an update-check
- `veloren@.timer`: Triggers `oneshot-veloren@.service` every 15 minutes

I moved the service restart to `update-veloren` because it will only download the update and
restart `veloren@.service` if the hashes are different.

```sh
git clone https://github.com/hnrq/vlrn-rpi.git
cd vlrn-rpi
sudo ./setup_server
```
