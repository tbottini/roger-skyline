#!/bin/sh

read -p "etage : " etage

export DEBIAN_FRONTEND=noninteractive

echo "Update Upgrade"
apt-get update -qq -y > /dev/null 2>/var/log/deploiement_error.log
apt-get upgrade -qq -y > /dev/null 2>/var/log/deploiement_error.log

echo "Installation sudo & tbottini can su do"
apt-get install sudo -qq -y > /dev/null 2>>/var/log/deploiement_error.log
usermod -aG sudo tbottini > /dev/null 2>>/var/log/deploiement_error.log

echo "Ip Static 10.1$etage.42.45"
echo "source /etc/network/interfaces.d/*" > /etc/network/interfaces
echo "auto lo" >> /etc/network/interfaces
echo "iface lo inet loopback" >> /etc/network/interfaces
echo "auto enp0s3" >> /etc/network/interfaces
echo "iface enp0s3 inet static" >> /etc/network/interfaces
echo "	address 10.1$etage.42.45" >> /etc/network/interfaces
echo "	netmask 255.255.255.252" >> /etc/network/interfaces
echo "	gateway 10.1$etage.254.254" >> /etc/network/interfaces
/etc/init.d/networking restart > /dev/null 2>>/var/log/deploiement_error.log

echo "SSH Configuration Port 1000"
sed -ie "s/#Port 22/Port 1000/g" /etc/ssh/sshd_config
sed -ie "s/#PermitRootLogin prohibit-password/PermitRootLogin no/g" /etc/ssh/sshd_config
sed -ie "s/#PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
ifup enp0s3

echo "Set Firewall"
iptables -F
iptables -X
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dport 1,11,15,79,111,119,143,540,635,80,443,1000 -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT
iptables -A OUTPUT -p tcp -m multiport --sport 1,11,15,79,111,119,143,540,635,80,443,1000 -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD ACCEPT

iptables-save > /etc/iptables.up.rules
echo "#!/bin/sh" > /etc/network/if-pre-up.d/iptables
echo "	/sbin/iptables-restore < /etc/iptables.up.rules" >> /etc/network/if-pre-up.d/iptables
chmod +x /etc/network/if-pre-up.d/iptables

echo "Serveur Config"
apt-get install apache2 -y -qq > /dev/null 2>>/var/log/deploiement_error.log
cat /home/tbottini/snake.html > /var/www/html/index.html
rm /home/tbottini/snake.html
a2enmod ssl > /dev/null 2>>/var/log/deploiement_error.log
a2enmod rewrite > /dev/null 2>>/var/log/deploiement_error.log
mkdir /etc/apache2/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/apache2/ssl/apache.key \
	-out /etc/apache2/ssl/apache.crt -subj "/C=FR/ST=France/L=Paris" > /dev/null 2>>/var/log/deploiement_error.log
sed -ie "s/ssl\/certs\/ssl-cert-snakeoil.pem/apache2\/ssl\/apache.crt/g" /etc/apache2/sites-available/default-ssl.conf
sed -ie "s/ssl\/private\/ssl-cert-snakeoil.key/apache2\/ssl\/apache.key/g" /etc/apache2/sites-available/default-ssl.conf
sed -ie "/#\|^$/d" /etc/apache2/sites-available/default-ssl.conf
cat /etc/apache2/sites-available/default-ssl.conf >> /etc/apache2/sites-available/000-default.conf
/etc/init.d/apache2 restart > /dev/null 2>>/var/log/deploiement_error.log

echo "Installation & Configuration de Portsentry (Scanport)"
apt-get install portsentry -qq -y > /dev/null 2>>/var/log/deploiement_error.log
sed -ie "s/BLOCK_UDP=\"0\"/BLOCK_UDP=\"1\"/g" /etc/portsentry/portsentry.conf
sed -ie "s/KILL_ROUTE=\"\/sbin\/route/#KILL_ROUTE=\"\/sbin\/route/g" /etc/portsentry/portsentry.conf
sed -ie "s/BLOCK_TCP=\"0\"/BLOCK_TCP=\"1\"/g" /etc/portsentry/portsentry.conf
sed -ie "s/#KILL_ROUTE=\"\/sbin\/iptables/KILL_ROUTE=\"\/sbin\/iptables/g" /etc/portsentry/portsentry.conf
/etc/init.d/portsentry restart > /dev/null 2>>/var/log/deploiement_error.log

echo "Installation & Configuration de Fail2Ban (DOS)"
apt-get install fail2ban -qq -y > /dev/null 2>>/var/log/deploiement_error.log
mv /home/tbottini/jail.local /etc/fail2ban/
echo "[Definition]" > /etc/fail2ban/filter.d/http-get-dos.local
echo "failregex = ^<HOST> -.*\"(GET|POST).*" >> /etc/fail2ban/filter.d/http-get-dos.local
echo "ignoreregex =" >> /etc/fail2ban/filter.d/http-get-dos.local
/etc/init.d/fail2ban restart > /dev/null 2>>/var/log/deploiement_error.log

echo "Creation Script Update Package"
echo "#!/bin/sh" > /etc/update_pckg
echo "apt-get update -y >> /var/log/update_script.log" >> /etc/update_pckg
echo "apt-get upgrade -y >> /var/log/update_script.log" >> /etc/update_pckg
chmod +x /etc/update_pckg

echo "0 4 * * 1 /home/tbottini/update_pckg" > /var/crontab_tmp
echo "@reboot /home/tbottini/update_pckg" >> /var/crontab_tmp

echo "Creation Script Modif Crontab"
mv /home/tbottini/cr_check.sh /etc/
chmod +x /etc/cr_check.sh
echo "0 0 * * * /etc/cr_check.sh" >> /var/crontab_tmp
crontab /var/crontab_tmp
cat /etc/crontab > /var/cr_save
rm -rf /var/crontab_tmp

echo "Email Config"
apt-get install exim4 -y -qq > /dev/null 2>>/var/log/deploiement_error.log
sed -ie '$d' /etc/aliases
echo "root: root" >> /etc/aliases
echo "user1: debian@local.net" >> /etc/aliases
echo "root: debian@local.net" > /etc/email-addresses
echo "user1: debian@local.net" >> /etc/email-addresses

sed -ie "/--dport 22/d" /etc/iptables.up.rules
sed -ie "/--sport 22/d" /etc/iptables.up.rules

reboot
