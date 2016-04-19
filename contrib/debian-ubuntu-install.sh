#!/bin/bash --
# Author: @DirtyCajunRice

# Check if ran by root
if [[ $UID -ne 0 ]]; then
    echo 'Script must be run as root'
    exit 1
fi

# Check for distro; continue if debian/ubuntu || exit
if [[ $(cat /etc/issue) =~ Debian ]]; then
    distro=debian
elif [[ $(cat /etc/issue) =~ Ubuntu ]]; then
    distro=ubuntu
else
    echo "This script will only work on Debian and Ubuntu Distros, but you are using $(cat /etc/issue)"
    exit 1
fi

# Get external ip address (checking 3 sites for redundancy)
for i in 'ipecho.net/plain' 'ifconfig.me' 'checkip.amazonaws.com'; do
    extip=$(curl -s $i)
    [[ ! $extip ]] || break
done

# Get internal ip address
intip=$(ip r g 8.8.8.8 | awk 'NR==1{print $7};')

# Installed whiptail for script prerequisite
apt-get -qq install whiptail -y

# Show Whiptail and install required files
{
i=1
while read -r line; do
    i=$(( $i + 1 ))
    echo $i
    done < <(apt-get update && apt-get install unrar-free git-core openssl libssl-dev python2.7 -y)
} | whiptail --title "Progress" --gauge "
   Installing unrar-free, git-core, openssl, libssl-dev, and python2.7" 8 80 0

# Check to see if all prior packages were installed sucessfully. if not exit 1 and display whiptail issues

if [[ $(dpkg -l unrar-free git-core openssl libssl-dev python2.7 2>&1 | grep "no packages" | \
        awk '{print $6 }') ]]; then
whiptail --title "Package Installation Failed" --msgbox "               These Packages have failed:
               $(dpkg -l unrar-free git-core openssl libssl-dev python2.7 2>&1 | grep "no packages" | awk '{print $6 }')
Please resolve these issues and restart the install script" 15 66
exit 1
fi

# Check to see if sickrage exists; If not make user/group
if [[ ! "$(getent group sickrage)" ]]; then
    addgroup --system sickrage
fi
if [[ ! "$(getent passwd sickrage)" ]]; then
    adduser --disabled-password --system --home /var/lib/sickrage --gecos "SickRage" --ingroup sickrage sickrage
fi

# Check to see if /opt/sickrage exists. If it does ask if they want to overwrite it. if they do not exit 1
# if they do, remove the whole directory and recreate
if [[ ! -d /opt/sickrage ]]; then
    mkdir /opt/sickrage && chown sickrage:sickrage /opt/sickrage
else
    whiptail --title 'Overwrite?' --yesno "/opt/sickrage already exists, do you want to overwrite it?" 8 40
    choice=$?
    if [[ $choice == 1 ]]; then
        rm -rf /opt/sickrage && mkdir /opt/sickrage && chown sickrage:sickrage /opt/sickrage
        su -c "git clone https://github.com/SickRage/SickRage.git /opt/sickrage" -s /bin/bash sickrage
    else
        echo
        exit 1
    fi
fi

# Depending on Distro, Cp the service script, then change the owner/group and change the permissions. Finally
# start the service
if [[ $distro = ubuntu ]]; then
    if [[ $(/sbin/init --version 2> /dev/null) =~ upstart ]]; then
        cp /opt/sickrage/runscripts/init.upstart /etc/init/sickrage.conf
	chown root:root /etc/init/sickrage.conf && chmod 644 /etc/init/sickrage.conf
        service sickrage start

    elif [[ $(systemctl) =~ -\.mount ]]; then
        cp /opt/sickrage/runscripts/init.systemd /etc/systemd/system/sickrage.service
        chown root:root /etc/systemd/system/sickrage.service && chmod 644 /etc/systemd/system/sickrage.service
        systemctl -q enable sickrage && systemctl -q start sickrage
    else
        cp /opt/sickrage/runscripts/init.ubuntu /etc/init.d/sickrage
        chown root:root /etc/init.d/sickrage && chmod 644 /etc/init.d/sickrage
        update-rc.d sickrage defaults && service sickrage start
    fi
elif [[ $distro = debian ]]; then
    if [[ $(systemctl) =~ -\.mount ]]; then
        cp /opt/sickrage/runscripts/init.systemd /etc/systemd/system/sickrage.service
        chown root:root /etc/systemd/system/sickrage.service && chmod 644 /etc/systemd/system/sickrage.service
        systemctl -q enable sickrage && systemctl -q start sickrage
    else
        cp /opt/sickrage/runscripts/init.debian /etc/init.d/sickrage
        chown root:root /etc/init.d/sickrage && chmod 644 /etc/init.d/sickrage
        update-rc.d sickrage defaults && service sickrage start
    fi
fi

# Finish by explaining the script is finished and give them the relevant IP addresses
whiptail --title Complete --msgbox "Check that everything has been set up correctly by going to:
     
          Internal IP: http://$intip:8081
                             OR
          External IP: http://$extip:8081

 make sure to add sickrage to your download clients group" 15 66
