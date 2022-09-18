## ARM Veloren Server

This is a tool for setting up a Systemd veloren server w/ a single command on a RPi (aarch64). Sudo is needed since it creates three new services:

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

### Hosting at Oracle Cloud

One of the main benefits of using aarch64 machines is that they're way less expensive than
the x86 ones on cloud services. Oracle Cloud offers a 24GB RAM + 8 cores ARM machine on its free plan. This is how you host in it
