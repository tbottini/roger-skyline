#!/bin/sh

read -p "login : " login
read -p "etage : " etage
read -p "sship : 10.1$etage." sship

sed "s/etage=1/etage=$etage/g" ./reinit.sh

export LANGUAGE=fr_FR.UTF-8 > ~/.bashrc
export LANG=fr_FR.UTF-8 >> ~/.bashrc
export LC_ALL=fr_FR.UTF-8 >> ~/.bashrc
source ~/.bashrc

echo "Send Key To" 10.1$etage.$sship
ssh-copy-id -i ~/.ssh/id_rsa.pub $login@10.1$etage.$sship > /dev/null 2>&1
scp -q ./script/start.sh $login@10.1$etage.$sship:~/
scp -q ./script/cr_check.sh $login@10.1$etage.$sship:~/
scp -q ./ressources/snake.html $login@10.1$etage.$sship:~/
scp -q ./ressources/jail.local $login@10.1$etage.$sship:~/
cat ~/.ssh/id_rsa.pub >> ~/.ssh/known_hosts

echo "Root"
ssh 10.1$etage.$sship -t "su root -c \"sh /home/tbottini/start.sh\""
