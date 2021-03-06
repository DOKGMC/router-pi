#!/bin/bash

# configs
upstream=wlan0
phy=wlan1

cat <<EOF > /etc/hostapd/hostapd.conf
interface=$phy
driver=nl80211
ssid=Free Wifi
channel=6
bssid=DD:3E:A8:A4:A2:8F
#macaddr_acl=0
#auth_algs=1
#ignore_broadcast_ssid=0
#wpa=2
#wpa_passpharse=4n0np4ssw0rd
#wpa_key_mgmt=WPA-PSK
#wpa_pairwise=TKIP
#rsn_pairwise=CCMP
EOF

# iptables rules
cat <<EOF > iptablescaptive
iptables -t nat -A POSTROUTING -o $upstream -j MASQUERADE
iptables -A FORWARD -i $phy -o $upstream -j ACCEPT
EOF

iptables-converter -s iptablesrules > /etc/iptables.rules
rm iptablesrules

# dnsmasq configs
cat <<EOF > /etc/dnsmasq.conf
log-facility=/var/log/dnsmasq.log
interface=$phy
listen-address=10.0.0.1
bind-interfaces
bogus-priv
dhcp-range=10.0.0.100,10.0.0.250,12h
dhcp-option=3,10.0.0.1
dhcp-option=6,10.0.0.1
#no-resolv
log-queries
EOF

# boot configs
cat <<EOF > /etc/rc.local
#!/bin/bash
ifconfig $phy 10.0.0.1/24 up
iptables-restore < /etc/iptables.rules
echo '1' > /proc/sys/net/ipv4/ip_forward
#tcpdump -s0 -i $phy -C 50 -w capture-$(date +%a-%d%m%y-%H%M-%S).pcap
EOF

# Create new interfaces file
cat <<EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

# Remove if you don't want static IP
allow-hotplug $phy
iface $phy inet static  
    address 10.0.0.1
    netmask 255.255.255.0
    network 10.0.0.0
    broadcast 10.0.0.255
#   wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
EOF

echo "Turning of power saving for $phy"
iwconfig $phy power off

# Tell DHCPD to ignore wireless int. Handle with hostapd
DENY="denyinterfaces $phy"
if grep -Fxq "$DENY" /etc/dhcpcd.conf
then
    echo "Denyinterfaces already found in dhcpd.conf"
else
    echo $DENY >> /etc/dhcpcd.conf
    service dhcpcd restart
    ifdown $phy; ifup $phy
fi

reboot
