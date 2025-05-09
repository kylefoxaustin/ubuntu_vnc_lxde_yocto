#!/bin/bash

##### ubuntu_vnc_lxde_yocto container ######


# This is the ENTRYPOINT script which is run in the docker container ubuntu_vnc_lxde_yocto
# the purpose of the script is to provide a full LXDE desktop GUI environment within the
# container, accessible by your remote host system by a VNC viewer (127.0.0.1:5900)
#
# The container serves dual purposes:
# 1) enable a full ubuntu 18 installation with LXDE GUI + sound so you can do anything with
#    the container you would normally do with Ubuntu
# 2) an interactive menu that enables via terminal to install Yocto projects and i.MX BSPs
#
# eventually the intent is to port this container to run natively on i.MX 8 or any
# i.MX processor that can run docker-ce engine.  That way you can pull down this container
# and use the i.MX 8 processor to drive a local screen.  In essence, it enables you to pull
# the container onto i.MX 8 and run Ubuntu with just two commands (pull, then run) vs a full
# native install
#
# This container has been tested on:
# Acer Aspire E 17 laptop running Ubuntu 18
# Acer Aspire E 17 laptop running Windows 10 + VirtualBox with a Ubuntu VM (docker on VM)
#
# This script will also enable the user to specify a USER name and PASSWORD.
# These parameters are passed to the startup.sh by the docker run command itself, not via this script's argument processing capabilities
# that is why you see USER and PASSWORD processed below without any apparent checking for those arguments to be passed into the shell itself.
# that is all handled by docker...
#
# you do not have to include a USER name/Password or VNC or SSL configuration unless you so choose
#
# Maintainer:  kyle fox (github.com/kylefoxaustin)
#
# source for LXDE_VNC docker image:  https://github.com/fcwu/docker-ubuntu-vnc-desktop
# and many thanks to fcwu (aka Doro Wu), fcwu.tw@gmail.com for creating the initial
# LXDE_VNC docker image


###############################
#       globals              #
#############################

# set DEBUGON
DEBUGON=1
BINDIRECTORY="/usr/local/bin"
REPOFILE="/usr/local/bin/repo"
TERM=xterm	 
POKYDIR="${HOME}/poky"

### debug messaging on or off function
### this function must always be at the top of the script as it
### may be used in the script immediately following its definition
### within the body of this script, if a debug message is to be run
### it will have the form of "debug && <command to run>
### if DEBUGON=0 then the <command to run> will be executed
### if DEBUGON=1 then the <command to run> will be ignored

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
debug && sleep 5
debug && echo "this is who the user is $USER"
debug && sleep 5

debug && echo "setting USER to root"

USER=${USER:-root}
debug && echo "this is who the user is $USER"
debug && sleep 5

debug && echo "setting HOME to root"
HOME=/root
if [ "$USER" != "root" ]; then
    debug && echo "starting user not equal to root"
    debug && echo "* enable custom user: $USER"
    useradd --create-home --shell /bin/bash --user-group --groups adm,sudo $USER
debug && sleep 5

    if [ -z "$PASSWORD" ]; then
        debug && echo "Setting default password to \"password\""
        PASSWORD=password
debug && sleep 5

    fi
    HOME=/home/$USER
    echo "$USER:$PASSWORD" | chpasswd
debug && sleep 5

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
    chown -R --verbose $USER:$USER $BINDIRECTORY
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


################################
#  Final Steps               ##
##############################


debug && echo "HOME ENV was $HOME"
debug && echo "setting HOME ENV to actual path"
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

#############################################
# Main interactive install menu           ##
# 1) setup poky                           ##
# 2) setup repo (prep for install of bsp) ##
# 3) install chosen i.MX bsp              ##
# 4) advanced:  execute a command         ##
############################################


# ===================
# Script funtionality
# ===================
# FUNCTION: dosomething_1
# note:  for each menu item, you will create a new dosomething_x function
#        e.g. menu item 2 requires a dosomething_2 function here




##############################
#  functions for menu script    ##
############################


### check if repo has been installed

repocheck () {
    # function returns
    # "1" in passed-in variable REPOFILE if the repo file is not installed
    # "2" in passed-in variable REPOFILE if the repo file IS installed
    
	      debug && echo "REPOFILE is equal to $REPOFILE " > /dev/stderr
	      debug && echo "BINDIRECTORY = $BINDIRECTORY " > /dev/stderr
	      sleep 2
	      if [ ! -f "$REPOFILE" ]; then
		  debug && echo "repo does not exist in $BINDIRECTORY" > /dev/stderr
		  debug && echo "ls the directory for repo" > /dev/stderr
		  debug && sudo ls $BINDIRECTORY > /dev/stderr      
		  debug && echo $PATH > /dev/stderr
		  debug && sleep 2
		  REPOEXISTS="1"
	      elif [ -f "$REPOFILE" ]; then
		  debug && echo "repo found!  repo is installed here: $BINDIRECTORY" > /dev/stderr
		  debug && echo "ls the directory for repo" > /dev/stderr
		  debug && sudo ls $BINDIRECTORY > /dev/stderr
		  debug && echo $PATH > /dev/stderr
		  debug && sleep 2
		  REPOEXISTS="2"
	      fi
	      }

repoinstall () {
    # function attempts to install the googleapis.com git-repo file
    echo "curl //storage.googleapis.com/git-repo-downloads/repo..."
    sudo curl https://storage.googleapis.com/git-repo-downloads/repo > temprepo
    echo "curl complete to temprepo file...."
    echo "attempting to set temprepo file  executable"
    sudo chmod a+x temprepo
    echo "copying temprepo into $REPOFILE"
    sudo cp temprepo $REPOFILE
    echo "cleaning up temprepo file..."
    sudo rm temprepo
    echo "press ENTER to continue"
    read enterkey
	  }

poky_init_build_env () {

    # if this function is called then poky is installed already
    # so don't need to check if poky exists or not
    
    local TEMPPOKYDIR=""
    TEMPPOKYDIR=$1
    echo "this is the temppokydir value"
    echo $TEMPPOKYDIR
    echo "Run the Yocto build environment script (oe-init-build-env)? Enter Y or N"
    read RUNENV
    case $RUNENV in 
	y|Y ) debug && echo "yes"
	      source $TEMPPOKYDIR/oe-init-build-env
	      echo "oe-init-build-env completed"
	      echo "press ENTER to continue..."
	      read enterkey	       ;;
	n|N ) echo "Exiting Poky init build environment setup...";;
	* ) echo "invalid option";;
    esac
    
}


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
		  git clone --progress git://git.yoctoproject.org/poky $POKYDIR
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
		  poky_init_build_env $POKYDIR
	      elif find $POKYDIR -mindepth 1 | read; then
		  echo "$POKYDIR exists, is non empty, therefore poky already installed"
		  echo "press ENTER to continue..."
		  read enterkey
	      else
		  echo "$POKYDIR exists but directory does not contain anything"
		  echo "proceeding with installation into $POKYDIR"
		  echo "beginning clone...:"
		  git clone --progress git://git.yoctoproject.org/poky $POKYDIR
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
		  poky_init_build_env $POKYDIR
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
    debug && echo "i am inside doSomething 2"4
    local CONTINUE=0
    local REPOEXISTS=""
    local CHECKREPO=""
    read CONTINUE
    case $CONTINUE in 
	y|Y ) debug && echo "yes"
	      debug && echo "inside dosomething_2 case statement Checking for existance of file /usr/local/bin/repo"
	      repocheck $REPOEXISTS
	      debug && echo " $REPOEXISTS is the value of repo_check function"
	      CHECKREPO=$REPOEXISTS
	      
	      if [[ "$CHECKREPO" -eq "1" ]]; then
		  echo "repo file not found!"
		  echo "proceeding with repo installation into $REPOFILE"
		  repoinstall
	      elif [[ "$CHECKREPO" -eq "2" ]]; then
		  echo "repo file found!"
		  echo "file is located in $BINDIRECTORY"
		  echo "exiting repo install..."
     	      fi
	      ;;
	n|N ) echo "no";;
	* ) echo "invalid option";;
    esac
}

doSomething_3() {
    echo "Install i.MX 8 bsp?  Enter Y or N" 
    local CONTINUE=0
    local REPOEXISTS=""
    local CHECKREPO=""
    repocheck $REPOEXISTS
    CHECKREPO=$REPOEXISTS
    if [[ "$CHECKREPO" -eq "1" ]]; then
	  echo "repo is not installed"
	  echo "please go back to main menu and install the repo (option 2)"
	  read throwaway
	  echo "Continue? Hit Enter"
	  throwaway=0
	  read throwaway
	  case "$throwaway" in 
	      y|Y ) ;;
	      * )   ;;
	  esac
    else
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
					
				echo "mkdir $DIR/imx-4.9.88-2.0.0_ga"
				mkdir -p $DIR/imx-4.9.88-2.0.0_ga
				echo "attempting to chown $USER to own $DIR"
				sudo chown $USER:$USER $DIR

				echo "cd $DIR/imx-4.9.88-2.0.0_ga"
				cd $DIR/imx-4.9.88-2.0.0_ga

				echo "initializing repo"
				repo init -u https://source.codeaurora.org/external/imx/imx-manifest  -b imx-linux-rocko -m imx-4.9.88-2.0.0_ga.xml
				echo "initialization complete"
				echo ""
				echo "syncing repo"
				echo ""
				/usr/local/bin/repo sync
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
			  * ) echo "invalid option"
			      STOPLOOP=0
			      ;;
		      esac

		  done
		  ;;
	    n|N ) debug && echo "no"
		  ;;
	    * ) echo "invalid option"
		;;
	esac
    fi
    
}

doSomething_4() {
    echo "For advanced users only"
    echo "on the next line you can write any ubuntu command you wish and it will be executed"
    echo "note: user with caution.  There are no protections against mis-use or accidental mistakes"
    echo "      ALL commands you enter WILL execute and can damage or destroy the container"
    
    echo ""
    echo ""
    local KEEPLOOPING=0
    while [ "$KEEPLOOPING" -eq "0" ]
    do
	
	printf "Enter Your Command: "
	read MYCOMMANDS 
	echo "execute the following commands: \"$MYCOMMANDS\" ? enter Y or N"
	read yesno
	case "$yesno" in 
	    y|Y )
		eval $MYCOMMANDS
		;;
	    n|N )
		;;
	esac
	
	echo ""
	echo "execute another command?  enter Y or N"
	read yesno
	case "$yesno" in 
	    y|Y )
		KEEPLOOPING=0
		;;
	    n|N )
		KEEPLOOPING=1
		;;
	esac
    done
}

# ================
# Install Menu Script structure
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
    echo "  4. Advanced - execute any command"
    echo "  5. Exit"
    echo ""
}

# Use menu...
# Main menu handler loop


echo "ABOUT TO START THE MENU INSTALL"
sleep 2

KEEPLOOPING=0
while [ $KEEPLOOPING -eq 0 ]
  do
    show_menus
    echo "Enter choice [ 1 - 5 ] "
    menuchoice=0
    read menuchoice
    case $menuchoice in
	1) doSomething_1 ;;
	2) doSomething_2 ;;
	3) doSomething_3 ;;
	4) doSomething_4 ;;
	5) echo "exiting"
	   KEEPLOOPING=1
	   continue;;
	*) echo -e "${RED}Error...${STD}" && sleep 2
	   ;;
    esac
    echo "Return to the Main Menu? (y/n)"
    yesno=0
    read yesno
    case "$yesno" in 
	y|Y ) continue;;
	n|N ) break;;
    esac
  done


debug && echo "about to exec /bin/tini -- usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf"

exec /bin/tini -- /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf

debug && echo "tini started, container is ready for full run mode"
debug && echo "you may now start working with it"
