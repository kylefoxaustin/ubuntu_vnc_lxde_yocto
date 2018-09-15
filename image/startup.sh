#!/bin/bash

# set DEBUGON
DEBUGON=1

debug () {
      return $DEBUGON
      }

debug && echo "Beginning of startup.sh script"


###############################
# set VNC password section  ##
#############################

if [ -n "$VNC_PASSWORD" ]; then
    debug && echo "starting set password section"
    debug && echo -n "$VNC_PASSWORD" > /.password1
    x11vnc -storepasswd $(cat /.password1) /.password2
    chmod 400 /.password*
    sed -i 's/^command=x11vnc.*/& -rfbauth \/.password2/' /etc/supervisor/conf.d/supervisord.conf
    export VNC_PASSWORD=
fi


###############################
# set resolution of display ##
#############################

if [ -n "$RESOLUTION" ]; then
    debug && echo "starting set resolution section"
    sed -i "s/1024x768/$RESOLUTION/" /usr/local/bin/xvfb.sh
fi


######################################
# set the user up and permissions  ##
# either root or user supplied    ##
# via docker run -e USER         ##
##################################

debug && echo "This is the HOME directory before setting HOME to root $HOME"
debug && echo "this is the path of current directory:"
debug && pwd
debug && sleep 2
debug && echo "setting USER to root"
USER=${USER:-root}
debug && echo "setting HOME to root"
HOME=/root
if [ "$USER" != "root" ]; then
    debug && echo "starting user not equal to root"
    debug && echo "* enable custom user: $USER"
    useradd --create-home --shell /bin/bash --user-group --groups adm,sudo $USER
    if [ -z "$PASSWORD" ]; then
        debug && echo "Setting default password to \"password\""
        PASSWORD=password
    fi
    HOME=/home/$USER
    debug && echo "$USER:$PASSWORD" | chpasswd
    cp -r /root/{.gtkrc-2.0,.asoundrc} ${HOME}
    [ -d "/dev/snd" ] && chgrp -R adm /dev/snd
fi

######################################
# clean up supervisord.conf        ##
####################################

debug && echo "about to remove \%USER\%:\%USER\% from supervisord.con"
sed -i "s|%USER%|$USER|" /etc/supervisor/conf.d/supervisord.conf

debug && echo "about to remove \%HOME\%:\%HOME\% from supervisord.conf"
sed -i "s|%HOME%|$HOME|" /etc/supervisor/conf.d/supervisord.conf

#############################################
# set up pcmanfm/LXDE directory and links ##
###########################################

debug && echo "about to mkdir for .config, pacmanfm, lxde"
mkdir -p $HOME/.config/pcmanfm/LXDE/

debug && echo "making hard link to /.config/pcmanfm/LXDE/"
ln -sf /usr/local/share/doro-lxde-wallpapers/desktop-items-0.conf $HOME/.config/pcmanfm/LXDE/
debug && echo "about to chown USER, -e USERNAME option performed at docker run command"

# check if 1st time run or not
# if already run, then we don't need to change permissions and don't want to
# this keeps chown from changing owernship of potentially thousands of files
# which can take a long time

if [ ! -f /usr/local/chownstatus/chownhasrun.txt ]; then
    debug && echo "This is 1st time container has run, need to chown $USER:$USER $HOME" 
    chown -R --verbose $USER:$USER $HOME
    mkdir -p /usr/local/chownstatus/
    touch /usr/local/chownstatus/chownhasrun.txt 
fi

#############################################
# set up nginx                            ##
###########################################

# nginx workers
debug && echo "about to sed -i nginx workers"
sed -i 's|worker_processes .*|worker_processes 1;|' /etc/nginx/nginx.conf

# nginx ssl
if [ -n "$SSL_PORT" ] && [ -e "/etc/nginx/ssl/nginx.key" ]; then
    debug && echo "SSL has not been chosen on docker run commmand"
    debug && echo "removing SSL port from /etc/nginx/sites-enabled/default"  
	sed -i 's|#_SSL_PORT_#\(.*\)443\(.*\)|\1'$SSL_PORT'\2|' /etc/nginx/sites-enabled/default
	sed -i 's|#_SSL_PORT_#||' /etc/nginx/sites-enabled/default
fi

# nginx http base authentication
if [ -n "$HTTP_PASSWORD" ]; then
    debug && echo "HTTP_PASSWORD was not chosen on docker run command"
    debug && echo "* enable HTTP base authentication"
    htpasswd -bc /etc/nginx/.htpasswd $USER $HTTP_PASSWORD
	sed -i 's|#_HTTP_PASSWORD_#||' /etc/nginx/sites-enabled/default
fi

# novnc websockify
debug && echo "setting hard link, websockify" 
ln -s /usr/local/lib/web/frontend/static/websockify /usr/local/lib/web/frontend/static/novnc/utils/websockify
debug && echo "about to chmod to executable the following: /usr/local/lib/web/frontend/static/websockify/run"
chmod +x /usr/local/lib/web/frontend/static/websockify/run

# clearup
debug && echo "clearup.  about to set password and http_password to null"

PASSWORD=
HTTP_PASSWORD=


#############################################
# Main interactive install menu           ##
# 1) setup poky                           ##
# 2) setup repo (prep for install of bsp) ##
# 3) install chosen i.MX bsp              ##
############################################

MAXMENU=3
# ===================
# Script funtionality
# ===================
# FUNCTION: dosomething_1
# note:  for each menu item, you will create a new dosomething_x function
#        e.g. menu item 2 requires a dosomething_2 function here

doSomething_1() {
    echo "Install Poky?  Enter Y or N"
    local CONTINUE=0
    read CONTINUE 
    case $CONTINUE in 
	y|Y ) echo "yes"
	      POKYDIR="${HOME}/poky"
	      echo "checking if Yocto Poky has been installed already"
	      echo "POKYDIR is = $POKYDIR"
	      if [ ! -d "$POKYDIR" ]; then
		  echo "Yocto Poky check... POKYDIR doesn't exist so creating Poky and cloning"
		  mkdir -p $POKYDIR
		  echo $PWD
		  echo "beginning clone...:"
		  git clone git://git.yoctoproject.org/poky $POKYDIR
		  echo $PWD
		  cd $POKYDIR
		  echo $PWD
		  echo ""
		  echo "clone complete..."
		  echo "about to initiate git checkout, tags yocto-2.5 to my-yocto-2.5"
		  git checkout tags/yocto-2.5 -b my-yocto-2.5
		  echo "git checkout complete..."
		  echo "install complete into $POKYDIR"
		  echo "press ENTER to continue..."
		  read enterkey
	      elif find $POKYDIR -mindepth 1 | read; then
		  echo "$POKYDIR exists, is non empty, therefore poky already installed"
		  echo "press ENTER to continue..."
		  read enterkey
	      else
		  echo "$POKYDIR exists but directory does not contain anything"
		  echo "proceeding with installation into $POKYDIR"
		  echo "beginning clone...:"
		  git clone git://git.yoctoproject.org/poky $POKYDIR
		  echo $PWD
		  cd $POKYDIR
		  echo $PWD
		  echo "clone complete..."
		  echo "about to initiate git checkout, tags yocto-2.5 to my-yocto-2.5"
		  git checkout tags/yocto-2.5 -b my-yocto-2.5
		  echo "git checkout complete"
		  echo "install complete..."
		  echo "press ENTER to continue..."
		  read enterkey
	      fi
	      ;;
	n|N ) echo "no";;
	* ) echo "invalid choice";;
    esac
}

# FUNCTION: dosomething_2
# note:  for each menu item, you will create a new dosomething_x function
#        e.g. menu item 2 requires a dosomething_2 function here

doSomething_2() {
    echo "Install repo tool?  Enter Y or N" 
    local CONTINUE=0
    read CONTINUE
    case $CONTINUE in 
	y|Y ) echo "yes"
	      BINDIRECTORY="/usr/local/bin"
	      REPOFILE="/usr/local/bin/repo"
	      echo "Checking for existance of file /usr/local/bin/repo"
	      echo "REPOFILE = $REPOFILE "
	      echo "BINDIRECTORY = $BINDIRECTORY "
	      if [ ! -f "$REPOFILE" ]; then

		  # Control will enter here if ~/bin doesn't exist.
		  # now mkdir ~/bin and install ~/bin/repo directory with repo from NXP i.MX recommended yocto packages
		  echo "REPOFILE wasn't found, attempting to mkdir and curl"
		  sudo curl https://storage.googleapis.com/git-repo-downloads/repo > $REPOFILE
		  echo "curl complete..."
		  echo "attempting to make $REPOFILE executable"
		  chmod a+x $REPOFILE
		  echo "press ENTER to continue"
		  read enterkey
	      else
		  echo "repo was found!" 
		  echo "press ENTER to continue..."
		  read enterkey
	      fi
	      ;;
	n|N ) echo "no";;
	* ) echo "invalid";;
    esac
}

doSomething_3() {
    echo "Install i.MX 8 bsp?  Enter Y or N" 
    local CONTINUE=0
    read CONTINUE
    case $CONTINUE in 
	y|Y ) echo "yes"

	      STOPLOOP=0
	      while [ $STOPLOOP -eq 0 ]
	      do
		  
	      IMXBSPNAME=0
	      CODEAUR=0
	      IMXBSPVERSION=0
	      DIR=yocto-imx-bsp
	      YESNOEXIT=0
	      
	      echo "I need the source code expository URL"
	      echo "Just hit ENTER if you want to use default https://source.codeaurora.org/external/imx/imx-manifest"  
	      echo "please enter the URL:"
	      read CODEAUR
	      if [ -z "$CODEAUR" ]; then
		  CODEAUR="https://source.codeaurora.org/external/imx/imx-manifest"
	      fi

	      echo "I need the name of the bsp" 
	      echo "Just hit ENTER if you want to use default imx-linux-rocko"  
	      echo "please enter the name:"
	      read IMXBSPNAME
	      if [ -z "$IMXBSPNAME" ]; then
		  IMXBSPNAME="imx-linux-rocko"
	      fi

	      echo "I need the version of the bsp" 
	      echo "Just hit ENTER if you want to use default imx-4.9.88-2.0.0_ga.xml"  
	      echo "please enter the version:"
	      read IMXBSPVERSION
	      if [ -z "$IMXBSPVERSION" ]; then
		  IMXBSPVERSION="imx-4.9.88-2.0.0_ga.xml"
	      fi

	      echo "this is the init and sync I will attempt:"
	      echo "repo init -u $CODEAUR -b $IMXBSPNAME -m $IMXBSPVERSION"
	      echo "is this correct?  enter Y (to sync), N (to redo), E (to exit)"

	      read YESNOEXIT
	      
	      case $YESNOEXIT in 
		  y|Y ) echo "beginning repo sync"
			echo "install directory will be ./yocto-imx-bsp"
			echo "attempting to chown $USER to own $DIR"
			sudo chown $USER:$USER $DIR

			echo "mkdir $DIR/imx-4.9.88-2.0.0_ga"
			mkdir -p $DIR/imx-4.9.88-2.0.0_ga
			echo "cd $DIR/imx-4.9.88-2.0.0_ga"
			cd $DIR/imx-4.9.88-2.0.0_ga

			echo "initializing repo"
			repo init -u https://source.codeaurora.org/external/imx/imx-manifest  -b imx-linux-rocko -m imx-4.9.88-2.0.0_ga.xml
			echo "initialization complete"
			echo ""
			echo "syncing repo"
			echo ""
			repo sync
			echo ""
			echo "repo sync complete"
	      
			cat README-IMXBSP | head
	      
			echo -e "\n\n\n"

			echo "cat README-IMXBSP to see the complete the options on how to build"
			STOPLOOP=1
			break;;
		  n|N ) STOPLOOP=0
			continue;;
		  e|E ) STOPLOOP=1
			break;;
		  * ) echo "invalid"
		      STOPLOOP=0
		      ;;
	      esac

	      done
	      ;;
	      n|N ) echo "no"
		    ;;
	      * ) echo "invalid"
		  ;;
    esac
}


# ================
# Script structure
# ================


# FUNCTION: display menu options
# this is the main menu engine to show what you can do
show_menus() {
    clear
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo " Main Menu"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "  1. Install Yocto Poky"
    echo "  2. Install Repo"
    echo "  3. pull i.MX image"
    echo "  4. Exit"
    echo ""
}

# Use menu...
  # Main menu handler loop
  while true
  do
    show_menus
    echo "Enter choice [ 1 - 4 ] "
    menuchoice=0
    read menuchoice
    case $menuchoice in
	1) doSomething_1 ;;
	2) doSomething_2 ;;
	3) doSomething_3 ;;
	4) echo "exiting" ;;
	*) echo -e "${RED}Error...${STD}" && sleep 2
	   ;;
    esac
    echo "Perform another install? (y/n)"
    yesno=0
    read yesno
    case "$yesno" in 
	y|Y ) continue;;
	n|N ) break;;
    esac
  done
  


################################
#  Final Steps               ##
##############################

debug && echo "HOME ENV was $HOME"
debug && echo "setting HOME ENV to actual path"
export HOME=$HOME # don't think this is taking...
debug && echo "HOME ENV is now $HOME"
debug && sleep 10

#now add line to bashrc and profile for HOME directory's actual position
#at this point, ubuntu has HOME=/home.  But if you start container as root (default) and
#don't place a new user name in the docker run command, then HOME needs to be /root
#we do the install menu prior to this so that if we are already root, we don't change
#the bashrc and profiles to 'root'

if [ "$HOME" = "/root" ]; then
    debug && echo "HOME was /root so about to set bashrc and profile exports"
    echo 'export HOME=/root/' >> /root/.bashrc
    source /root/.bashrc
    echo 'export HOME=/root/' >> /root/.profile
    source /root/.bashrc
else
    debug && echo "HOME was NOT /root so about to set bashrc and profile exports"
    echo 'export HOME=$HOME' >> /${HOME}/.bashrc
    source /${HOME}/.bashrc
    echo 'export HOME=$HOME' >> /${HOME}/.profile
    source /${HOME}/.bashrc
fi


debug && echo "about to exec /bin/tini -- usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf"

exec /bin/tini -- /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf

debug && echo "tini started, container is ready for full run mode"
debug && echo "you may now start working with it"
