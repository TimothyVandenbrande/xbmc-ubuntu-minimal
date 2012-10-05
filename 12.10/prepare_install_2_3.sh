#!/bin/bash

THIS_FILE=$0
SCRIPT_VERSION="2.3"

VIDEO_MANUFACTURER=""
VIDEO_DRIVER=""
VIDEO_MANUFACTURER_NAME=""

HOME_DIRECTORY="/home/$USER/"
TEMP_DIRECTORY=$HOME_DIRECTORY"temp/"
ENVIRONMENT_FILE="/etc/environment" 
ENVIRONMENT_BACKUP_FILE="/etc/environment.bak"
INIT_FILE="/etc/init.d/xbmc"
XBMC_ADDONS_DIR=$HOME_DIRECTORY".xbmc/addons/"
XBMC_USERDATA_DIR=$HOME_DIRECTORY".xbmc/userdata/"
XBMC_ADVANCEDSETTINGS_FILE=$XBMC_USERDATA_DIR"advancedsettings.xml"
XBMC_ADVANCEDSETTINGS_BACKUP_FILE=$XBMC_USERDATA_DIR"advancedsettings.xml.bak"
XWRAPPER_BACKUP_FILE="/etc/X11/Xwrapper.config.bak"
XWRAPPER_FILE="/etc/X11/Xwrapper.config"
SYSTEM_LIMITS_FILE="/etc/security/limits.conf"
INITRAMFS_SPLASH_FILE="/etc/initramfs-tools/conf.d/splash"
XWRAPPER_CONFIG_FILE="/etc/X11/Xwrapper.config"
POWERMANAGEMENT_DIR="/var/lib/polkit-1/localauthority/50-local.d/"

XBMC_PPA="ppa:wsnipex/xbmc-xvba"
HTS_TVHEADEND_PPA="ppa:jabbors/hts-stable"
OSCAM_PPA="ppa:oscam/ppa"

GITHUB_ROOT_URL="https://github.com/Bram77/xbmc-ubuntu-minimal/raw/master/"
ADDONS_DIR_URL=$GITHUB_ROOT_URL"addons/"
SCRIPTS_DIR_URL=$GITHUB_ROOT_URL"12.10/"

LOG_TEXT="\n"
LOG_FILE=$HOME_DIRECTORY"xbmc_installation.log"
DIALOG_WIDTH=70
SCRIPT_TITLE="XBMC installation script v$SCRIPT_VERSION for Ubuntu 12.10 by Bram van Oploo :: bram@sudo-systems.com :: www.sudo-systems.com"

## ------ START functions ---------

function log()
{
    echo "$@" >> $LOG_FILE
	LOG_TEXT="$LOG_TEXT$@\n"
	
	dialog --title "Ubuntu configuration and XBMC installation in progress..." --backtitle "$SCRIPT_TITLE" --infobox "$LOG_TEXT" 34 $DIALOG_WIDTH
}

function showInfo()
{
    echo "$@" >> $LOG_FILE
	LOG_TEXT="$LOG_TEXT$@\n"

    dialog --title "Installing..." --backtitle "$SCRIPT_TITLE" --infobox "\n$@" 5 $DIALOG_WIDTH
}

function showError()
{
    echo "$@" >> $LOG_FILE
	LOG_TEXT="$LOG_TEXT$@\n"

    dialog --title "Error" --backtitle "$SCRIPT_TITLE" --msgbox "\n$@" 5 $DIALOG_WIDTH
}

function showDialog()
{
	dialog --title "XBMC installation script" \
		--backtitle "$SCRIPT_TITLE" \
		--msgbox "\n$@" 12 $DIALOG_WIDTH
}

function showErrorDialog()
{
	dialog --title "ERROR" \
		--backtitle "$SCRIPT_TITLE" \
		--msgbox "\n$@" 8 $DIALOG_WIDTH
}

function installDependencies()
{
    echo "-- Installing installation dependencies..."
    echo ""

	sudo apt-get -y install dialog software-properties-common > /dev/null 2>&1
	
	echo $?
	
	exit
	
	if [ $? != 0 ];
	then
	    echo "Error installing dependencies. Installation aborted."
	    exit
	fi
}

function fixLocaleBug()
{
    if [ ! -f $ENVIRONMENT_FILE ];
    then
        sudo touch $ENVIRONMENT_FILE
    fi

	if [ -f $ENVIRONMENT_BACKUP_FILE ];
	then
		sudo rm $ENVIRONMENT_FILE > /dev/null 2>&1
		sudo cp $ENVIRONMENT_BACKUP_FILE $ENVIRONMENT_FILE > /dev/null 2>&1
	else
		sudo cp $ENVIRONMENT_FILE $ENVIRONMENT_BACKUP_FILE > /dev/null 2>&1
	fi

	echo "LC_MESSAGES=\"C\"" | sudo tee -a $ENVIRONMENT_FILE > /dev/null 2>&1
	echo "LC_ALL=\"en_US.UTF-8\"" | sudo tee -a $ENVIRONMENT_FILE > /dev/null 2>&1
	
	if [ $? == 0 ];
	then
	    showInfo "Ubuntu locale environment bug fixed"
	else
	    showError "ERROR: Ubuntu locale environment bug could not be fixed"
	fi
}

function applyXbmcNiceLevelPermissions()
{
	if [ ! -f $SYSTEM_LIMITS_FILE ];
	then
		sudo touch $SYSTEM_LIMITS_FILE > /dev/null 2>&1
	fi

	echo "$USER             -       nice            -1" | sudo tee -a $SYSTEM_LIMITS_FILE> /dev/null 2>&1
	
	if [ $? == 0 ];
	then
	    showInfo "Allowed XBMC to prioritize threads"
	else
	    showError "ERROR: Failed to allow XBMC to prioritize threads"
	fi
}

function addUserToRequiredGroups()
{
	sudo adduser $USER video > /dev/null 2>&1
	sudo adduser $USER audio > /dev/null 2>&1
	sudo adduser $USER users > /dev/null 2>&1
	showInfo "XBMC user added to required groups"
}

function addXbmcPpa()
{
    showInfo "Adding Wsnipex xbmc-xvba PPA..."
    sudo mkdir -p $HOME_DIRECTORY".gnupg/" > /dev/null 2>&1
	sudo add-apt-repository -y $XBMC_PPA > /dev/null 2>&1
	
	if [ $? == 0 ];
	then
	    showInfo "Wsnipex xbmc-xvba PPA added"
	else
	    showError "ERROR: Could not add xbmc-xvba PPA"
	fi
}

function distUpgrade()
{
    showInfo "Updating Ubuntu with latest packages (may take a while)..."
	sudo apt-get -qq update > /dev/null 2>&1
	sudo apt-get -y -qq dist-upgrade > /dev/null 2>&1
	
	if [ $? == 0 ];
	then
	    showInfo "Ubuntu installation updated"
	else
	    showError "ERROR: Ubuntu dist-upgrade failed"
	fi
}

function installXinit()
{
    showInfo "Installing xinit..."
    sudo dpkg-query -l xinit > /dev/null 2>&1
    
    if [ $? == 1 ];
    then
        sudo apt-get -y -qq install xinit > /dev/null 2>&1
        
        if [ $? == 0 ];
	    then
	        showInfo "Xinit installed"
	    else
	        showError "ERROR: Xinit could not be installed"
	    fi
    else
        showInfo "Skipping. Xinit already installed"
    fi
}

function installPowerManagement()
{
    showInfo "Installing power management packages..."

    mkdir -p $TEMP_DIRECTORY > /dev/null
	cd $TEMP_DIRECTORY
	sudo apt-get -y -qq install policykit-1 upower udisks acpi-support > /dev/null 2>&1
	
	if [ $? != 0 ];
    then
        showError "ERROR: A problem occured while instlling power management packages"
    else
        showInfo "Power management packages installed"
    fi
	
	wget -q $SCRIPTS_DIR_URL"custom-actions.pkla" > /dev/null 2>&1
	sudo mkdir -p $POWERMANAGEMENT_DIR > /dev/null 2>&1
	
	if [ -f ./custom-actions.pkla ];
	then
        sudo mv custom-actions.pkla $POWERMANAGEMENT_DIR > /dev/null 2>&1
        
        if [ $? == 0 ];
	    then
	        showInfo "XBMC power management features enabled"
	    else
	        showError "ERROR: XBMC power management features could not be enabled"
	    fi
	else
	    showError "ERROR: XBMC power management file could not be downloaded"
	fi
}

function installAudio()
{
    showInfo "Installing audio packages....\n!! Please make sure no used channels are muted !!"
	sudo apt-get -y -qq install linux-sound-base alsa-base alsa-utils libasound2 > /dev/null 2>&1
	
	if [ $? == 0 ];
    then
        showInfo "Audio packages successfully installed"
        sudo alsamixer
    else
        showError "ERROR: Audio packages could not be installed"
    fi
}

function installLirc()
{
    showInfo "Installing lirc"
	sudo apt-get -y -qq install lirc
	
	if [ $? == 0 ];
    then
        showInfo "Lirc successfully installed"
    else
        showError "ERROR: Lirc installation failed"
    fi
}

function installTvHeadend()
{
    showInfo "Adding jabbors hts-stable PPA..."
    sudo mkdir -p $HOME_DIRECTORY".gnupg/" > /dev/null 2>&1
	sudo add-apt-repository -y $HTS_TVHEADEND_PPA > /dev/null 2>&1
	
	if [ $? == 0 ];
    then
        showInfo "Jabbors hts-stable tvheadend PPA added"
        
        distUpgrade
    
        showInfo "Installing hts tvheadend..."
        sudo apt-get -y -qq install tvheadend > /dev/null 2>&1
        sudo dpkg-reconfigure tvheadend
        
        if [ $? == 0 ];
        then
            showInfo "Hts tvheadend successfully installed"
        else
            showError "ERROR: Hts tvheadend could not be installed"
        fi
    else
        showError "ERROR: Jabbors hts-stable tvheadend PPA could not be added"
    fi
}

function installOscam()
{
    showInfo "Adding oscam PPA..."
    sudo mkdir -p $HOME_DIRECTORY".gnupg/" > /dev/null 2>&1
	sudo add-apt-repository -y $OSCAM_PPA > /dev/null 2>&1
	
	if [ $? == 0 ];
    then
        showInfo "Oscam PPA successfully added"
    else
        showError "ERROR: Oscam PPA could not be added"
    fi

    distUpgrade
    
    showInfo "Installing oscam..."
    sudo apt-get -y -qq install oscam > /dev/null 2>&1
    
    if [ $? == 0 ];
    then
        showInfo "Oscam successfully installed"
    else
        showError "ERROR: Oscam could not be installed"
    fi
}

function installXbmc()
{
    showInfo "Installing XBMC..."
    sudo dpkg-query -l xbmc > /dev/null 2>&1
    
    if [ $? == 1 ];
    then
	    sudo apt-get -y -qq install xbmc > /dev/null 2>&1
	    
	    if [ $? == 0 ];
        then
            showInfo "XBMC successfully installed"
        else
            showError "ERROR: XBMC could not be installed"
        fi
    else
        showInfo "Skipping. XBMC already installed"
    fi
}

function enableDirtyRegionRendering()
{
    showInfo "Enabling XBMC dirty-region-rendering..."    
    
	if [ -f $XBMC_ADVANCEDSETTINGS_BACKUP_FILE ];
	then
		rm $XBMC_ADVANCEDSETTINGS_BACKUP_FILE > /dev/null 2>&1
	fi

	if [ -f $XBMC_ADVANCEDSETTINGS_FILE ];
	then
		mv $XBMC_ADVANCEDSETTINGS_FILE $XBMC_ADVANCEDSETTINGS_BACKUP_FILE > /dev/null 2>&1
	fi
	
	mkdir -p $TEMP_DIRECTORY > /dev/null
	cd $TEMP_DIRECTORY
	wget -q $SCRIPTS_DIR_URL"dirty_region_rendering.xml" 2>&1
	mkdir -p $XBMC_USERDATA_DIR > /dev/null 2>&1
	
	if [ -f ./dirty_region_rendering.xml ];
	then
        mv dirty_region_rendering.xml $XBMC_ADVANCEDSETTINGS_FILE > /dev/null 2>&1
        
        if [ $? == 0 ];
        then
            showInfo "XBMC dirty region rendering enabled"
        else
            showError "ERROR: XBMC dirty region rendering could not be enabled"
        fi
    else
        showError "XBMC dirty region rendering file could not be downloaded"
    fi
}

function installXbmcAddonRepositoriesInstaller()
{
    showInfo "Installing Addon Repositories Installer addon..."
	mkdir -p $TEMP_DIRECTORY > /dev/null
	cd $TEMP_DIRECTORY
	wget -q $ADDONS_DIR_URL"plugin.program.repo.installer-1.0.5.tar.gz" > /dev/null 2>&1

	if [ ! -d $XBMC_ADDONS_DIR ];
	then
		mkdir -p $XBMC_ADDONS_DIR > /dev/null 2>&1
	fi

    if [ -f ./plugin.program.repo.installer-1.0.5.tar.gz ];
    then
        tar -xvzf ./plugin.program.repo.installer-1.0.5.tar.gz -C $XBMC_ADDONS_DIR > /dev/null 2>&1
        
        if [ $? == 0 ];
        then
            showInfo "Addon Repositories Installer addon successfully installed"
        else
            showError "ERROR: Addon Repositories Installer addon could not be installed"
        fi
    else
	    showError "Addon Repositories Installer addon could not be downloaded"
    fi
}

function installVideoDriver()
{
    showInfo "Installing $VIDEO_MANUFACTURER_NAME video drivers..."
    sudo dpkg-query -l $VIDEO_DRIVER > /dev/null 2>&1
    
    if [ $? == 1 ];
    then
        sudo apt-get -y install $VIDEO_DRIVER > /dev/null 2>&1
        
        if [ $? == 0 ];
        then
            showInfo "$VIDEO_MANUFACTURER_NAME video drivers successfully installed"
            
            if [ $VIDEO_MANUFACTURER == "ati" ];
            then
	            sudo aticonfig --initial -f > /dev/null 2>&1
	            sudo aticonfig --sync-vsync=on > /dev/null 2>&1
	            sudo aticonfig --set-pcs-u32=MCIL,HWUVD_H264Level51Support,1 > /dev/null 2>&1

	            dialog --title "Disable underscan" \
		            --backtitle "$SCRIPT_TITLE" \
		            --yesno "Do you want to disable underscan (removes black borders)? Do this only if you're sure you need it!" 7 $DIALOG_WIDTH

	            RESPONSE=$?
	            case $RESPONSE in
                    0) 
                        disbaleAtiUnderscan
                        ;;
                    1) 
                        enableAtiUnderscan
                        ;;
                    255) 
                        showInfo "ATI underscan configuration skipped"
                        ;;
	            esac
            fi
        else
            showError "ERROR: $VIDEO_MANUFACTURER_NAME video drivers could not be installed"
        fi
    else
	    showInfo "Skipping. $VIDEO_MANUFACTURER_NAME video drivers already installed."
    fi
}

function disbaleAtiUnderscan()
{
	sudo kill $(pidof X) > /dev/null 2>&1
	sudo aticonfig --set-pcs-val=MCIL,DigitalHDTVDefaultUnderscan,0 > /dev/null 2>&1
	
	if [ $? == 0 ];
    then
        showInfo "Underscan successfully disabled"
    else
        showError "ERROR: Underscan could not be disabled"
    fi
}

function enableAtiUnderscan()
{
	sudo kill $(pidof X) > /dev/null 2>&1
	sudo aticonfig --set-pcs-val=MCIL,DigitalHDTVDefaultUnderscan,1 > /dev/null 2>&1
	
	if [ $? == 0 ];
    then
        showInfo "Underscan successfully enabled"
    else
        showError "ERROR: Underscan could not be enabled"
    fi
}

function installXbmcAutorunScript()
{
    showInfo "Installing XBMC autorun support..."
    
    mkdir -p $TEMP_DIRECTORY > /dev/null
	cd $TEMP_DIRECTORY
	wget -q $SCRIPTS_DIR_URL"xbmc_init_script" > /dev/null 2>&1
	
	if [ ! -f ./xbmc_init_script ];
	then
	    showError "Download of XBMC autorun script failed"
	else
	    if [ -f $INIT_FILE ];
	    then
		    sudo rm $INIT_FILE > /dev/null 2>&1
	    fi

	    sudo mv ./xbmc_init_script $INIT_FILE > /dev/null 2>&1
	    sudo chmod a+x /etc/init.d/xbmc > /dev/null 2>&1
	    sudo update-rc.d xbmc defaults > /dev/null 2>&1
	    
	    if [ $? == 0 ];
        then
            showInfo "XBMC autorun succesfully configured"
        else
            showError "ERROR: XBMC autorun could not be configured"
        fi
	fi
}

function installXbmcBootScreen()
{
    showInfo "Installing XBMC boot screen (please be patient)..."
    sudo dpkg-query -l plymouth-theme-xbmc-logo > /dev/null 2>&1
    
    if [ $? == 1 ];
    then
	    sudo apt-get -y -qq install plymouth-label v86d > /dev/null 2>&1
	    
	    if [ $? == 0 ];
        then
            mkdir -p $TEMP_DIRECTORY > /dev/null
            cd $TEMP_DIRECTORY
            wget -q $SCRIPTS_DIR_URL"plymouth-theme-xbmc-logo.deb" > /dev/null 2>&1
            
            if [ ! -f ./plymouth-theme-xbmc-logo.deb ];
            then
                showError "Download of XBMC boot screen package failed"
            else
                sudo dpkg -i ./plymouth-theme-xbmc-logo.deb > /dev/null 2>&1
                
                if [ $? == 0 ];
                then
                    showInfo "XBMC boot screen successfully installed"
                    
                    if [ -f $INITRAMFS_SPLASH_FILE ];
                    then
                        sudo rm $INITRAMFS_SPLASH_FILE > /dev/null 2>&1
                    fi

                    sudo touch $INITRAMFS_SPLASH_FILE > /dev/null 2>&1
                    echo "FRAMEBUFFER=y" | sudo tee -a $INITRAMFS_SPLASH_FILE > /dev/null 2>&1
                    sudo update-grub > /dev/null 2>&1
                    sudo update-initramfs -u > /dev/null 2>&1
                    
                    if [ $? == 0 ];
                    then
                        showInfo "XBMC boot screen succesfully applied"
                    else
                        showError "ERROR: XBMC boot screen could not be applied"
                    fi
                else
                    showError "ERROR: XBMC boot screen could not be installed"
                fi
            fi
        
            showInfo "XBMC boot screen installation requirements installed"
        else
            showError "ERROR: XBMC boot screen installation requirements could not be installed"
        fi
    else
        showInfo "Skipping. XBMC boot screen already installed"
    fi
}

function reconfigureXServer()
{
    showInfo "Configuring X-server..."
    
    if [ ! -f $XWRAPPER_FILE ];
    then
        sudo touch $XWRAPPER_FILE
    fi

	if [ ! -f $XWRAPPER_BACKUP_FILE ];
	then
		sudo mv $XWRAPPER_FILE $XWRAPPER_BACKUP_FILE > /dev/null 2>&1
	fi

	if [ -f $XWRAPPER_FILE ];
	then
		sudo rm $XWRAPPER_FILE > /dev/null 2>&1
	fi

	sudo touch $XWRAPPER_FILE > /dev/null 2>&1
	echo "allowed_users=anybody" | sudo tee -a $XWRAPPER_CONFIG_FILE > /dev/null 2>&1
	
	if [ $? == 0 ];
    then
        showInfo "X-server successfully configured"
    else
        showError "ERROR: X-server could not be configured"
    fi
}

function selectAdditionalOptions()
{
    cmd=(dialog --title "Optional packages and features" 
        --backtitle "$SCRIPT_TITLE" 
        --checklist "Plese select optional packages to install:" 
        15 $DIALOG_WIDTH 5)
        
    options=(1 "Lirc (IR remote support)" off
            2 "Hts tvheadend (live TV backend)" off
            3 "Oscam (live HDTV decryption tool)" off
            4 "XBMC Dirty region rendering (improved performance)" on
            5 "XBMC Addon Repositories Installer addon" on)
            
    choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

    for choice in $choices
    do
        case ${choice//\"/} in
            1)
                installLirc
                ;;
            2)
                installTvHeadend 
                ;;
            3)
                installOscam 
                ;;
            4)
                enableDirtyRegionRendering 
                ;;
            5)
                installXbmcAddonRepositoriesInstaller 
                ;;
        esac
    done
}

function selectVideoDriver()
{
    cmd=(dialog --backtitle "Video driver installation"
        --radiolist "Select your video chipset manufacturer (required):" 
        10 $DIALOG_WIDTH 3)
        
    options=(1 "NVIDIA" on
         2 "ATI (series >= 5xxx)" off
         3 "Intel" off)
         
    choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

    case ${choice//\"/} in
        1)
            VIDEO_MANUFACTURER="nvidia"
		    VIDEO_DRIVER="nvidia-current"
		    VIDEO_MANUFACTURER_NAME="NVIDIA"
		    installVideoDriver
            ;;
        2)
            VIDEO_MANUFACTURER="ati"
		    VIDEO_DRIVER="fglrx"
		    VIDEO_MANUFACTURER_NAME="ATI"
		    installVideoDriver
            ;;
        3)
            VIDEO_MANUFACTURER="intel"
		    VIDEO_DRIVER="i965-va-driver"
		    VIDEO_MANUFACTURER_NAME="Intel"
		    installVideoDriver
            ;;
        *)
            selectVideoDriver
            ;;
    esac
}

function cleanUp()
{
    showInfo "Cleaning up..."
	sudo apt-get -y autoclean > /dev/null 2>&1
	sudo apt-get -y autoremove > /dev/null 2>&1
	sudo rm -R $TEMP_DIRECTORY > /dev/null 2>&1
	rm $HOME_DIRECTORY$THIS_FILE
}

function rebootMachine()
{
    showInfo "Reboot system..."
	dialog --title "Installation complete" \
		--backtitle "$SCRIPT_TITLE" \
		--yesno "Do you want to reboot now?" 7 $DIALOG_WIDTH

	case $? in
        0)
            clear
            echo ""
            echo "Installation complete. Rebooting..."
            echo ""
            sudo reboot now > /dev/null 2>&1
	        ;;
	    1) 
            quit
	        ;;
	    255) 
	        quit
	        ;;
	esac
}

function renewLogFile()
{
    if [ -f $LOG_FILE ];
    then
        rm $LOG_FILE
    fi

    touch $LOG_FILE
}

function quit()
{
	clear
	exit
}

control_c()
{
  quit
}

## ------- END functions -------

clear

renewLogFile

echo ""
installDependencies
echo "Loading installer..."
showDialog "Welcome to the XBMC minimal installation script. Some parts may take a while to install depending on your internet connection speed.\n\nPlease be patient..."
trap control_c SIGINT

fixLocaleBug
applyXbmcNiceLevelPermissions
addUserToRequiredGroups
addXbmcPpa
distUpgrade
selectVideoDriver
installXinit
installPowerManagement
installAudio
installXbmc
installXbmcAutoRunScript
installXbmcBootScreen
reconfigureXServer
selectAdditionalOptions
cleanUp
rebootMachine