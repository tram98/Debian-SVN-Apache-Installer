#!/bin/bash

#-+HEADER+-#################
#                          #
#  Name: SVN Apache Setup  #
#  Author: tram98          #
#  Date: 16/8/2019         #
#  Version: 1.0            #
#                          #
############################

#-+DESCRIPTION+-#################################################################
#                                                                               #
#  Hello,                                                                       #
#  this script is used to setup a SVN-Server with apache2.                      #
#  Just run it and follow the instructions.                                     #
#  In the end you should have a fully working SVN server up and running.        #
#  If something goes wrong, I'm sorry for that. Please note that my experience  #
#  is not that of an IT professional but that of a student that has programmed  #
#  for about 4-5 years. Please test this script in a safe environment before    #
#  productive use.								                                #
#                                                                               #
#################################################################################

#-+DISCLAIMER+-###################################################
#                                                                #
#  Please be aware that I take no responsibility for any damage  #
#  caused using this script.                                     #
#								                                 #
##################################################################

################LIB START#################

log()
{
	echo "$(date +%H:%M:%S):$1: ${@:2}"
}

info()
{
	log "INFO  " $@
}

error()
{
	log "ERROR " $@
	exit 1
}

warn()
{
	log "WARN  " $@
}

prompt()
{
	read -p "$(date +%H:%M:%S):PROMPT: ${@}: " input
}

#################LIB END#################

#################SCRIPT FUNCTIONS#################

SVN_DIR="/var/lib/svn_repositories"
SVN_WEB_DIR="svn"
input=""

install()
{
	info "Installing $1"
	apt-get -y install $1 > "/tmp/apt_install_$1.log" 2>&1
	if [ $? -ne 0 ] ; then
                error "Failed to install $1. See logfile /tmp/apt_install_$1.log for details"
        fi
	rm "/tmp/apt_install_$1.log" #remove apt install log if installation worked
}

checkIfRoot()
{
	info "Checking if script is run as root..."
	if [ $(id -u) -ne 0 ] ; then
		error "This script must be run as root!"
	fi
}

updateSystem()
{
	prompt "OK to run 'apt update' and 'apt upgrade'? (For noobs: This essentially updates most software on your system) (Y/n)"
	if [ $input == "Y" ] ; then
		info "Running 'apt update'..."
		apt update > "/tmp/apt_update.log" 2>&1
		if [ $? -ne 0 ] ; then
	                error "Failed to run 'apt update'. See logfile /tmp/apt_upgrade.log for details."
	        fi
		info "Running 'apt upgrade', this may take several minutes..."
		apt -y upgrade > "/tmp/apt_upgrade.log" 2>&1
		if [ $? -ne 0 ] ; then
	                error "Failed to run 'apt upgrade'. See logfile /tmp/apt_upgrade.log for details."
	        fi
		info "System Update complete..."
	else
		info "Skipped System update..."
	fi
}

userConfig()
{
	info "You may now enter custom settings for the svn server. Leave blank for default..."
	prompt "Custom svn directory (def: $SVN_DIR)"
	if [ $input ] ; then
		SVN_DIR=$input
	fi
	prompt "Custom svn web location (def: $SVN_WEB_DIR)"
        if [ $input ] ; then
                SVN_WEB_DIR=$input
        fi
}

setupSVN()
{
	info "Preparing SVN config file from template..."
	if [ -a "./dav_svn.conf.templ" ] ; then
                cp ./dav_svn.conf.templ dav_svn.conf
                sed -i "s:{SVN_DIR}:$SVN_DIR:g" dav_svn.conf
                sed -i "s:{SVN_WEB_DIR}:$SVN_WEB_DIR:g" dav_svn.conf
                mv ./dav_svn.conf /etc/apache2/mods-enabled/
	else
		error "Could not find svn template..."
	fi
	info "Creating SVN Root dir..."
	mkdir $SVN_DIR
	info "Creating test repository"
	svnadmin create $SVN_DIR/test
	info "Setup permissions on SVN root dir"
	chown -R www-data:www-data $SVN_DIR
	chmod -R 775 $SVN_DIR
}

installPackages()
{
	install apache2
	install subversion
	install libapache2-mod-svn
	install libsvn-dev
}

setupApache()
{
	info "Setting up apache2..."
	#enable svn mods in apache2
	info "Enabling dav mod..."
	a2enmod dav
	info "Enabling dav_svn mod..."
	a2enmod dav_svn
	info "Restarting apache2..."
	service apache2 restart
	if [ $? -ne 0 ] ; then
		error "Failed to restart apache2... Please check config"
	fi
}

setupAdminPassword()
{
	info "Enter SVN admin password(htpasswd for password protected weblogin)... "
	htpasswd -cm /etc/apache2/dav_svn.passwd admin
	if [ $? -eq 0 ] ; then
		info "Restarting apache2..."
		systemctl restart apache2.service
		if [ $? -ne 0 ] ; then
			error "Failed to restart apache2... Please check config"
		fi
	else
		error "htpasswd configuration failed. Please try again by restarting the script..."
	fi
}

success()
{
	info "Horray! Apparently the SVN-installation has completed without problems."
	info "You may want to check if the test repository is working by visiting the following link: http://localhost/$SVN_WEB_DIR/test"
}

#################SCRIPT START#################

checkIfRoot
userConfig
updateSystem
installPackages
setupApache
setupSVN
setupAdminPassword
success
