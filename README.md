# IPSec IKEv2 vpn server on Docker

This is a Dockerfile/image which always compiles the latest version of Strongswan from source. To keep things simple you don't need to run additional scripts, certificate generation and user creation occurs at container startup.

## Quick start

Issue the dokcer run command below. The Certificate and certificate password will be mounted under `credentials` directory. The default username is `vpn` and the password same as the certificate password.   

```
docker run \
    --name ipsec-vpn-server \
    --restart=always \
    -v $PWD/credentials:/certs/user-cert
    -p 500:500/udp \
    -p 4500:4500/udp \
    -d --privileged \
    szecsig/ipsec-vpn-server
```