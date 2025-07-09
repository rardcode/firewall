# NftFwl
Linux firewall based on nftables.

By default NftFwl enables the following rules for ipv4/ipv6:
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
NftFwl is ready for Fail2Ban, Libvirt & Docker services.

- For **Docker**, unfortunately at this time Docker does not have any native support for nftables.\
There is an issue on Github: https://github.com/moby/moby/issues/49634\ where *...The goal here is to add native support for nftables...*\

So there are 2 choices:
1. (suggested) - Do nothing. Docker continue to use iptables;
2. Manage rules with NftFwl. For do this you have to disable iptables rules auto-creator adding:
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
Every time the NftFwl is restarted, libvirtd services are automatically rebooted & iptables/nftables rules created.

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
mkdir /etc/nftfwl.d
cd /opt
git clone https://github.com/rardcode/nftfwl.git
ln -s /opt/nftfwl/nftfwl.service /etc/systemd/system/
ln -s /opt/nftfwl/nftfwl /usr/local/bin/
cd /opt/nftfwl
cp customRules.sh /etc/nftfwl.d/
```

**NOTE**: In Debian set iptables-nft in manual mode:
```
update-alternatives --config iptables
```
Select 2 -> `/usr/sbin/iptables-nft` in `manual mode`

Enable & start:
```
systemctl enable nftfwl --now
```
Start it!
```
nftfwl start
```
Others options:`restart|stop|show|edit|rules|log`
- show = `nft --handle list ruleset`
- edit = edit the `/usr/local/nftfwl`
- rules = edit `customRules.sh`
- log = tail -f `<logfile>`

#### Log Debian
Redirect the log into `/var/log/nftables.log` file:
```
echo "if \$msg contains 'DROP' then /var/log/nftables.log
& stop" > /etc/rsyslog.d/nftables.conf
```
Restart service:
```
systemctl restart rsyslog
```
Add `/var/log/nftables.log` in `/etc/logrotate.d/rsyslog`

#### Log Manjaro
Install and enable **syslog-ng**:
```
pacman --noconfirm -S syslog-ng && systemctl enable syslog-ng@default --now
```
Abilitare il log di nfttables decommentando nel file /etc/syslog-ng/syslog-ng.conf:
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
#### Log OpenSUSE
In OpenSUSE, install `rsyslog`. After this, logs are in /var/log/firewall.

## USAGE
### FIRST usage
Put needed vars and rules in `/etc/nftfwl.d/customRules.sh` file;

If you need a routing firewall, declare all needed interfaces (ETH[0], ETH[1], etc..).\
**NOTE: ETH[0] will have to be WAN interface.**
Ex.
```
ETH[0]="eth1"     # WAN
ETH[1]="eth0"     # LAN1
ETH[2]="eth0.20"  # LAN2
[...]
```
### Add personal rules
As written at the beginning of this guide, BY DEFAULT traffic between interfaces is NOT enabled.\
In `/etc/nftfwl.d/customRules.sh` you can see some examples rules.

**Interfaces & subnets**\
YOU DON'T NEED TO SETUP ANY ADDRESS, SUBNET: **NftFwl MAKE IT FOR YOU!**\
Ex:\
subnet for **ETH[1]** will be env **LAN_ETH[1]**\
subnet for **ETH[2]** will be env **LAN_ETH[2]**

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

### LAN[x]toWanDENY & to LAN[x]toWAN files in `/etc/nftfwl.d`.
In ex. `LAN1toWAN.txt`, you can put mac-address or IP of device you want to ALLOW full access to internet.\
In ex. `LAN1toWAN-DENY.txt`, you can put mac-address or IP of device you want to BLOCK full access to internet.\
**NOTE**: this file override `customRules.sh`

### Docker preserve original IP
If you have chosen to manage the Dockers rules with NftFwl, for allow external access (ex. port 80) to a docker, you have to:
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
