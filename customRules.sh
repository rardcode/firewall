
# WAN[1]="ens23,192.168.1.254,1"
# WAN[2]="ens24,192.168.2.254,2"
# WAN[3]="....

# LAN[1]="ens18"     # LAN
# LAN[2]="ens19"     # DMZ
# LAN[3]="ens20"     # IOT
# LAN[4]=".....

# FORCE="192.168.1.100,wan2"
# FORCE="192.168.1.101,wan2"

## INPUT
#########
### CUSTOM
# nft -e add rule inet table_filter INPUT_CUSTOM ip saddr 172.235.181.217 drop # 20250507
# nft -e add rule inet table_filter INPUT_CUSTOM tcp dport 22 accept # ssh
 ### LAN1
# nft -e add rule inet table_filter INPUT_FROM_LAN1 udp dport 123 accept # ntp
# nft -e add rule inet table_filter INPUT_FROM_LAN1 tcp dport 22 accept  # ssh
 ### LAN2
# nft -e add rule inet table_filter INPUT_FROM_LAN2 udp dport 123 accept # ntp
 ### LAN3
# nft -e add rule inet table_filter INPUT_FROM_LAN3 icmp type echo-request limit rate 2/second burst 5 packets accept # icmp echo request

 ## OUTPUT
 #########
# nft add rule inet table_filter OUTPUT_CUSTOM ip daddr 45.125.0.0/16 drop # description

## FORWARD
##########
### CUSTOM
# nft -e add rule inet table_filter FORWARD_CUSTOM iif ${LAN[1]} oif ${LAN[2]} accept # enable all traffic from LAN1 >> DMZ
# nft -e add rule inet table_filter FORWARD_CUSTOM iif ${LAN[1]} oif ${LAN[3]} accept # enable all traffic from LAN1 >> IOT

### LAN1
# nft -e add rule inet table_filter WAN_FROM_LAN1 accept

### LAN2
# nft -e add rule inet table_filter WAN_FROM_LAN2 accept

### LAN3
# nft -e add rule inet table_filter WAN_FROM_LAN3 accept

### DOUBLENAT
##### same machine (if docker, use docker real IP)
# nft -e add rule ip table_nat PREROUTING_CUSTOM iif ${LAN[1]} ip saddr ${LAN_LAN[1]} ip daddr "93.56.106.76" tcp dport 443 dnat "10.3.1.1"
##### other machine
# nft -e add rule ip table_nat PREROUTING_CUSTOM iif ${LAN[1]} ip saddr ${NET_LAN[1]} ip daddr "194.113.90.208" tcp dport 443 dnat "10.11.20.193"
# nft -e add rule ip table_nat POSTROUTING_CUSTOM oif ${LAN[1]} ip saddr ${NET_LAN[1]} ip daddr "10.11.20.193" tcp dport 443 snat "10.11.1.200"
# nft -e add rule ip table_nat PREROUTING_CUSTOM iif ${LAN[3]} ip saddr ${NET_LAN[3]} ip daddr "194.113.90.208" tcp dport 443 dnat "10.11.20.193"
# nft -e add rule ip table_nat POSTROUTING_CUSTOM oif ${LAN[3]} ip saddr ${NET_LAN[3]} ip daddr "10.11.20.193" tcp dport 443 snat "10.11.10.200"

### DNAT
# nft -e add rule ip table_nat PREROUTING_CUSTOM iif ${WAN[1]} tcp dport 443 dnat 10.11.20.193:443
# nft -e add rule inet table_filter FORWARD_CUSTOM iif ${WAN[1]} oif ${LAN[2]} ip daddr 10.11.20.193 tcp dport 443 accept

##### ----- DOCKER ALLOW Real-IP traffic ----- ####
###################################################
### docker with port 1:1
# nft -e add rule ip table_nat DOCKER iifname != docker0 tcp dport 12899 dnat to 10.2.1.1 # qbt
 ### docker with external port different from internal
# nft -e add rule ip table_nat DOCKER iifname != docker0 tcp dport 321  dnat to 10.1.1.1:22 # gitea

