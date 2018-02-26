#!/bin/sh

PUBLIC_IP=$(dig @resolver1.opendns.com -t A -4 myip.opendns.com +short)
CERT_PASSWD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
USER_PASSWD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)

sed -i.bak s/leftid=@moon.strongswan.org/leftid=$PUBLIC_IP/g /etc/ipsec.conf
sed -i.bak s/ip_address/$PUBLIC_IP/g /etc/ipsec.secrets

iptables -A INPUT -i lo -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir in  --proto esp -s 10.0.10.0/24 -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir out --proto esp -d 10.0.10.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.0.10.0/24 -o eth0 -m policy --pol ipsec --dir out -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.0.10.0/24 -o eth0 -j MASQUERADE
iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in -s 10.0.10.0/24 -o eth0 -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360

if [ -f "/etc/ipsec.d/certs/vpn-server-cert.pem" ]; then
   exec /usr/sbin/ipsec "$@"; echo "OK! Server certificate already exists, nothing to do..."; exit 1;
fi

sed -i.bak s/random_password/$USER_PASSWD/g /etc/ipsec.secrets
echo -e "Certificate password: $CERT_PASSWD\nUsername: vpn\nUser password: $USER_PASSWD" >> /certs/client-cert/passwords.txt

mkdir -p /certs
cd /certs
ipsec pki --gen --type rsa --size 4096 --outform pem > server-root-key.pem
ipsec pki --self --ca --lifetime 3550 --in server-root-key.pem --type rsa --dn "C=US, O=IPSec-VPN-Server, CN=$PUBLIC_IP" --outform pem > server-root-ca.pem
ipsec pki --gen --type rsa --size 4096 --outform pem > vpn-server-key.pem
ipsec pki --pub --in vpn-server-key.pem --type rsa | ipsec pki --issue --lifetime 1720 --cacert server-root-ca.pem --cakey server-root-key.pem --dn "C=US, O=IPSec-VPN-Server, CN=$PUBLIC_IP" --san $PUBLIC_IP --flag serverAuth --flag ikeIntermediate --outform pem > vpn-server-cert.pem
cp ./vpn-server-cert.pem /etc/ipsec.d/certs/vpn-server-cert.pem
cp ./vpn-server-key.pem /etc/ipsec.d/private/vpn-server-key.pem

mkdir -p /certs/client-cert
cd /certs/client-cert
openssl pkcs12 -in /certs/vpn-server-cert.pem -inkey /certs/vpn-server-key.pem -certfile /certs/server-root-ca.pem -passout pass:$CERT_PASSWD -export -out client-certificate.p12

exec /usr/sbin/ipsec "$@"

