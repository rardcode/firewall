
# ETH[0]="eth1"     # WAN
# ETH[1]="eth0"     # LAN1
# ETH[2]="eth0.20"  # LAN2

## SOME EXAMPLE RULES ##
# nft -e add rule inet table_filter INPUT_CUSTOM ip saddr 45.125.0.0/16 drop # drop inbound connections
# nft -e add rule inet table_filter INPUT_CUSTOM tcp dport {135, 136, 137, 138, 139, 445} drop # Windows shits
# nft -e add rule inet table_filter INPUT_CUSTOM udp dport {135, 136, 137, 138, 139, 445} drop # Windows shits
# nft -e add rule inet table_filter INPUT_CUSTOM tcp dport 222 accept
#
# nft -e add rule inet table_filter INPUT_FROM_LAN1 ip saddr 192.168.88.131 udp dport 53 accept # accept dns query from dns server
# nft -e add rule inet table_filter INPUT_FROM_LAN1 tcp dport 25 accept # postfix
# nft -e add rule inet table_filter INPUT_FROM_LAN2 tcp dport 25 accept # postfix
#
# nft -e add rule inet table_filter OUTPUT_CUSTOM ip saddr 45.125.0.0/16 drop # drop outbound connections
#
# nft -e add rule inet table_filter WAN_FROM_LAN1 udp dport 53 drop # drop external DNS
# nft -e add rule inet table_filter WAN_FROM_LAN1 ether saddr 9a:11:a4:c2:bc:3f tcp dport 8080 accept # radio KissKiss per gianlu-cel
# nft -e add rule inet table_filter WAN_FROM_LAN1 ip daddr 18.158.152.184 tcp dport 19001 accept # webcam
# nft -e add rule inet table_filter WAN_FROM_LAN1 tcp dport { 80,443,143,993,465,587 } accept # http, https, imaps, smtps
# nft -e add rule inet table_filter WAN_FROM_LAN2 accept
#
# nft -e add rule inet table_filter FORWARD_CUSTOM iif ${ETH[2]} ip saddr ${LAN_ETH[2]} oif ${ETH[1]} ip daddr 192.168.88.131 udp dport 53 accept
# nft -e add rule inet table_filter FORWARD_CUSTOM iif ${ETH[1]} ip saddr ${LAN_ETH[1]} oif ${ETH[2]} ip daddr ${LAN_ETH[2]} accept
#
# nft -e add rule ip table_nat PREROUTING_CUSTOM iif ${ETH[0]} tcp dport 443 dnat 192.168.30.129:443
# nft -e add rule inet table_filter FORWARD_CUSTOM iif ${ETH[0]} oif ${ETH[2]} ip daddr 192.168.30.129 tcp dport 443 accept
##
 ##### ----- DOCKER ALLOW Real-IP traffic ----- ####
 ###################################################
 ## docker with port 1:1
# nft -e add rule ip table_nat DOCKER iifname != docker0 tcp dport 12899 dnat to 10.2.1.1 # qbt
 ## docker with external port different from internal
# nft -e add rule ip table_nat DOCKER iifname != docker0 tcp dport 9321 dnat to 10.1.1.1:3000
 ## docker with external port different from internal & traffic permitted only from specified networks or ip
# nft -e add rule ip table_nat DOCKER iifname != docker0 ip saddr 192.168.88.129/26 tcp dport 9321 dnat to 10.1.1.1:3000
##
