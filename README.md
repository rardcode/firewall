# FireWall
Linux firewall based on nftables.

By default FireWall enables the following rules for ipv4/ipv6:
- For the INPUT chain:
  - Incoming traffic on the loopback interface;
  - Traffic for connections in ESTABLISHED & RELATED state;
  - Some basic rules like: broadcast, multicast, ping "Echo reply", ping "Destination Unreachable" and ping "Time Exceeded";
  - Incoming traffic from the internal dockers networks (only ipv4);
  - Incoming traffic from the internal libvirtd networks (only ipv4);
- For the OUTPUT chain:
  - Outgoing traffic on the loopback interface;
  - Traffic for connections in ESTABLISHED & RELATED state;
  - Some basic rules like broadcast, multicast, ping "Echo reply", ping "Destination Unreachable" and ping "Time Exceeded";
  - Traffic for connections in NEW state;
- For the FORWARD chain:
  - Some basic rules like broadcast, multicast, ping "Echo reply", ping "Destination Unreachable" and ping "Time Exceeded";
  - Forward traffic between dockers networks (only ipv4);
  - Forward traffic between libvirtd networks (only ipv4);
  - NOTE: BY DEFAULT it not enable traffic between interfaces, you have to add extra rules as explained below.
- Finally, for all chains:
  - Log & drop all connections that are not intercepted by the previous rules.

### Libvirt, Fail2ban & Docker
FireWall is ready for Fail2Ban, Libvirt & Docker services.

- For **Docker**, unfortunately at this time Docker does not have any native support for nftables.\
There is an issue on Github: https://github.com/moby/moby/issues/49634\ where *...The goal here is to add native support for nftables...*\

So there are 2 choices:
1. (suggested) - Do nothing. Docker continue to use iptables;
2. Manage rules with FireWall. For do this you have to disable iptables rules auto-creator adding:
```
{
  "iptables" : false,
  "ip6tables" : false
}

```
in `/etc/docker/daemon.json`.\
Restart service:
```
systemctl restart docker
```
- For **Libvirtd**, disable iptables & enable nftables in `/etc/libvirt/network.conf`:
```
[...]
firewall_backend = "nftables"
#firewall_backend = "iptables"
[...]
```

Restart service:
```
systemctl restart libvirtd
```
Every time the FireWall is restarted, libvirtd services are automatically rebooted & iptables/nftables rules created.

- For **Fail2ban** add `nftables.conf` in `/etc/fail2ban/jail.d` with:
```
[DEFAULT]
banaction = nftables-multiport
```
Restart service:
```
systemctl restart fail2ban
```

## INSTALLATION
Required packages: `ipcalc, conntrack`
```
mkdir /etc/firewall.d
cd /opt
git clone https://github.com/rardcode/firewall.git
ln -s /opt/firewall/firewall.service /etc/systemd/system/
ln -s /opt/firewall/failover.service /etc/systemd/system/
ln -s /opt/firewall/firewall /usr/local/bin/
ln -s /opt/firewall/failover /usr/local/bin/
ln -s /opt/firewall/checkwan /usr/local/bin/
cp /opt/firewall/customRules.sh /etc/firewall.d/
```

Enable & start:
```
systemctl enable firewall --now
```
Start it!
```
firewall start
```
Others options:`restart|stop|show|edit|rules|log`
- show = `nft --handle list ruleset`
- edit = edit the `/usr/local/firewall`
- rules = edit `customRules.sh`
- log = tail -f `<logfile>`

## Log
### Config
The Firewall script outputs logs to the screen when run manually and also sends them to syslog.
Install `rsyslog` & redirect the logs into `/var/log/firewall.log` file & `DROP` logs in `/var/log/firewall-drop.log`:
#### Debian / OpenSUSE
```
echo 'if ($msg contains 'DROP') then {
    action(type="omfile" file="/var/log/firewall-drop.log")
    stop
}

if ($programname == 'firewall' or $msg contains 'DROP') then {
    action(type="omfile" file="/var/log/firewall.log")
    stop
}' > /etc/rsyslog.d/firewall.conf
```
Restart service:
```
systemctl restart rsyslog
```
NOTE: if you want a single `firewall.log` you have to comment first if section in `/etc/rsyslog.d/firewall.conf`
#### Manjaro
Install and enable **syslog-ng**:
```
pacman --noconfirm -S syslog-ng && systemctl enable syslog-ng@default --now
```
Abilitare il log di iptables decommentando nel file /etc/syslog-ng/syslog-ng.conf:
da
```
log {
        source(s_local);
         #filter(f_iptables);
         #destination(d_iptables);
};
```
a
```
log {
        source(s_local);
         filter(f_iptables);
         destination(d_iptables);
};
```
### Rotate
```
echo "/var/log/firewall*.log
{
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
}" > /etc/logrotate.d/firewall
```

## USAGE
### FIRST usage
Put needed vars and rules in `/etc/firewall.d/customRules.sh` file:\
If you need a routing firewall, declare all needed interfaces: wan (WAN[1] whit interface,gateway,priority) & LAN[1], LAN[2], etc...\
Ex.
```
WAN[1]="eth0,192.168.1.254,1"     # WAN1
WAN[2]="eth1,192.168.2.254,2"     # WAN2
LAN[1]="eth2"     # LAN1
LAN[2]="eth3"     # LAN2
LAN[3]="eth4"     # LAN3
[...]
```

If you have more than 1 WAN, you can use FORCE env to force an internal ip to use a specied WAN (internal ip,wan1,2,3 in lowercase ):
```
[...]
FORCE="172.16.1.1,wan1"
[...]
```
### Add personal rules
As written at the beginning of this guide, BY DEFAULT traffic between interfaces is NOT enabled.\
In `/etc/firewall.d/customRules.sh` you can see some examples rules.

**Interfaces & subnets**\
YOU DON'T NEED TO SETUP ANY ADDRESS, SUBNET: **FireWall MAKE IT FOR YOU!**\
Ex:\
env subnet for **LAN[1]** will be **NET_LAN[1]**\
env subnet for **LAN[2]** will be **NET_LAN[2]**

**Chains**\
You can use script's self made chains as: **INPUT_CUSTOM**, **INPUT_FROM_LAN1**, **INPUT_FROM_LAN2** etc..\
For forward traffic you can use **FORWARD_CUSTOM** for all source and destination or...\
use **WAN_FROM_LAN1** where source is already set with **LAN1** interface and subnet.

Ex:\
Rule for enable ALL **LAN1** --> **WAN** traffic... you can use **WAN_FROM_LAN1** self-created chain:
```
nft -e add rule inet table_filter WAN_FROM_LAN1 accept
```
Rule for enable **LAN1** --> **LAN2** traffic... you have to use **FORWARD_CUSTOM** chain:
```
nft -e add rule inet table_filter FORWARD_CUSTOM iif ${ETH[1]} ip saddr ${LAN_ETH[1]} oif ${ETH[2]} ip daddr ${LAN_ETH[2]} accept
```

### LAN[x]toWanDENY & to LAN[x]toWAN files in `/etc/firewall.d`.
In ex. `LAN1toWAN.txt`, you can put mac-address or IP of device you want to ALLOW full access to internet.\
In ex. `LAN1toWAN-DENY.txt`, you can put mac-address or IP of device you want to BLOCK full access to internet.\
**NOTE**: this file override `customRules.sh`

### Docker preserve original IP
If you have chosen to manage the Dockers rules with FireWall, for allow external access (ex. port 80) to a docker, you have to:
1. create a PREROUTING rules:
```
nft -e add rule ip table_nat DOCKER iifname != "docker0" tcp dport 80 dnat to 10.1.1.1
```
2. assign a static ip to the container:
```
services:
  some-app:
    [...]
    networks:
      static-network:
        ipv4_address: 10.1.1.1

networks:
  static-network:
    ipam:
      config:
        - subnet: 10.1.0.0/16
```
Manage rules in the section `## ----- DOCKER ALLOW Real-IP traffic ----- ##` of the `customRules.sh` file.
