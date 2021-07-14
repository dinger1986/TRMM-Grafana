#!/bin/bash

#### Just scripted up to work from @Yasd and @sebcashmag on Discord forum


#check if running on ubuntu 20.04, Debian or Raspbian
osname=$(lsb_release -si); osname=${osname^}
osname=$(echo "$osname" | tr  '[A-Z]' '[a-z]')
fullrel=$(lsb_release -sd)
codename=$(lsb_release -sc)
relno=$(lsb_release -sr | cut -d. -f1)
fullrelno=$(lsb_release -sr)

# Fallback if lsb_release -si returns anything else than Ubuntu, Debian or Raspbian
if [ ! "$osname" = "ubuntu" ] && [ ! "$osname" = "debian" ]; then
  osname=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
  osname=${osname^}
fi


# determine system
if ([ "$osname" = "ubuntu" ] && [ "$fullrelno" = "20.04" ]) || ([ "$osname" = "debian" ] && [ $relno -ge 10 ]); then
  echo $fullrel
else
 echo $fullrel
 echo -ne "${RED}Only Ubuntu release 20.04 and Debian 10 and later, are supported\n"
 echo -ne "Your system does not appear to be supported${NC}\n"
 exit 1
fi

if [ $EUID -eq 0 ]; then
  echo -ne "${RED}Do NOT run this script as root. Exiting.${NC}\n"
  exit 1
fi

#check if running as root
if [ $EUID -eq 0 ]; then
  echo -ne "\033[0;31mDo NOT run this script as root. Exiting.\e[0m\n"
  exit 1
fi

#Username
echo -ne "Enter your created username if you havent done this please do it now, use ctrl+c to cancel this script and do it${NC}: "
read username

#Get Dashboards
sudo mkdir /var/lib/grafana/dashboards
sudo rm /var/lib/grafana/dashboards/sebdash.json
sudo rm /var/lib/grafana/dashboards/default.json
sudo chown -R ${username}:${username} /var/lib/grafana/dashboards
cd /var/lib/grafana/dashboards
wget https://raw.githubusercontent.com/dinger1986/TRMM-Grafana/main/dashboards/sebdash.json
wget https://raw.githubusercontent.com/dinger1986/TRMM-Grafana/main/dashboards/tvdash.json

cd ~/
