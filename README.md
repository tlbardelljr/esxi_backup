# ESXi bash Backup script from remote
ESXi Backup Script

# Whats this do?
&nbsp; Backup directory needs to be on ESXi host.<br>
&nbsp; If you want to be on a NAS then setup a datastore on ESXi host for the NAS<br>


# You need ssh keys installed on ESXi host from linux computer that will run this script. Run commands below as root. Run this script as root.
&nbsp;On a Linux box, create a key pair without passphrase:<br>
&nbsp;&nbsp;&nbsp;ssh-keygen -N "" -f id_esxi<br><br>
&nbsp;This creates two files - id_esxi and id_esxi.pub.<br>
&nbsp;Append the public key to /etc/ssh/keys-root/authorized_keys on your ESXi box from Linux:<br>
&nbsp;&nbsp;&nbsp;cat id_esxi.pub | ssh root@HOSTNAME_OR_IP_ADDRESS 'cat >>/etc/ssh/keys-root/authorized_keys'<br><br>
&nbsp;To test, you can ssh into your ESXi box by just using the private key:<br>
&nbsp;&nbsp;&nbsp;ssh -i id_esxi root@HOSTNAME_OR_IP_ADDRESS<br>


# Tested On
Debian 12<br>
Ubuntu 22.04<br>


# Installation


```
wget https://raw.githubusercontent.com/tlbardelljr/gnome-like-win11/main/gnome-like-win11.sh
```

```
chmod +x ./gnome-like-win11.sh
```

```
./gnome-like-win11.sh
```
