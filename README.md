This is a tool for setting up a Systemd veloren server w/ a single command. Optionally, it is also possible to setup an oracle that sends you a message on Telegram if anything goes wrong with the server.

- [Installation](#installation)
  - [\[OPTIONAL\] Install Telegram Oracle](#optional-install-telegram-oracle)
  - [Uninstalling](#uninstalling)
    - [Uninstalling Telegram Oracle](#uninstalling-telegram-oracle)
  - [Why is sudo needed?](#why-is-sudo-needed)
- [Hosting at Oracle Cloud](#hosting-at-oracle-cloud)
  - [Create an account](#create-an-account)
  - [Creating an instance](#creating-an-instance)
  - [Installing the Server](#installing-the-server)
  - [Port>) forwarding](#port-forwarding)

## Installation

For installing the server, run:

```sh
curl -o- https://raw.githubusercontent.com/hnrq/veloren-server/main/setup.sh | sudo sh
```

### \[OPTIONAL\] Install Telegram Oracle

Telegram Oracle is a small utility to receive messages if anything goes wrong with your server. To install it, run:

```sh
curl -o- https://raw.githubusercontent.com/hnrq/veloren-server/main/telegram-oracle.sh | sudo sh
```

### Uninstalling

To uninstall the server, run:

```sh
curl -o- https://raw.githubusercontent.com/hnrq/veloren-server/main/setup.sh | sudo sh -- --purge
```

#### Uninstalling Telegram Oracle

```sh
curl -o- https://raw.githubusercontent.com/hnrq/veloren-server/main/telegram-oracle.sh  | sudo sh -- --purge
```

### Why is sudo needed?

Sudo is needed since three systemd services will be created when installing the server itself:

- `veloren-server.service`: Responsible for starting the server itself
- `oneshot-update-veloren-server.service`: oneshot service that triggers an update-check
- `veloren-server.timer`: Triggers `oneshot-update-veloren-server.service` every 15 minutes

The Telegram Oracle also creates `telegram-oracle.service`, which monitors `veloren-server.service`.

## Hosting at [Oracle Cloud](https://cloud.oracle.com)

One of the main benefits of using aarch64 is that it is way cheaper than x86. Oracle Cloud offers a 24GB RAM + 8 cores ARM machine for free. Follow this step-by-step tutorial for creating a Veloren server using this script at [Oracle Cloud](https://cloud.oracle.com).

### Create an account

You can create an Oracle Cloud account [here](https://signup.cloud.oracle.com/).

### Creating an instance

Head over to [https://cloud.oracle.com/compute/instances](https://cloud.oracle.com/compute/instances) and click on "Create Instance". Put any name you want, click on **edit** in the Image and Shape section and change it to the following:

![Image: Canonical Ubuntu 22.04, Shape: VM.Standard.A1.Flex, OCPU count: 2, Memory (GB): 8, Network bandwidth (Gbps): 2](/img/machine-shape.png)

In the "Add [SSH](https://en.wikipedia.org/wiki/Secure_Shell) keys" section, select "Generate a key pair for me". Download both the private and public key and copy both to `$HOME/.ssh`.

Hit the "Create" button and wait for the instance to be created.

### Installing the Server

To install the server, we need to [SSH](https://en.wikipedia.org/wiki/Secure_Shell) into it. To do that, we should find the machine IP. Head over to [https://cloud.oracle.com/compute/instances](https://cloud.oracle.com/compute/instances) again and go to your recently created instance page. Then, under "Instance information > Instance access", you'll find the instance Public IP address and a username. On a terminal, run:

```sh
ssh -i <path-to-your-ssh-key> <username>@<your-ip>
```

Once SSH'ed, [install the server](#installation).

### [Port](<https://en.wikipedia.org/wiki/Port_(computer_networking)>) forwarding

To make your server available to the external network, you need to open the port 14004, which is used by Veloren server. To do that, go to your instance details page again. Then click at your subnet, under "Instance Information > Primary VNIC". Find security lists and click at the Default Security List. Finally, add a new Ingress Rule with the following info:

- Source Type: CIDR
- Source CIDR: 0.0.0.0/0
- IP Protocol: TCP
- Source Port Range:<empty>
- Destination Port Range: 14004
- Description: Veloren

Save it. Now, SSH into your instance again and run those two commands:

```sh
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 14004 -j ACCEPT
sudo netfilter-persistent save
```
