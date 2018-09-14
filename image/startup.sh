#!/bin/bash

# set DEBUGON
DEBUGON=1

debug () {
      return $DEBUGON
      }

debug && echo "Beginning of startup.sh script"


echo "this is the 1st interactive part of the script"
echo "tell me your name"
read someone
echo "hello $someone"

if [ -n "$VNC_PASSWORD" ]; then
    debug && echo "starting set password section"
    debug && echo -n "$VNC_PASSWORD" > /.password1
    x11vnc -storepasswd $(cat /.password1) /.password2
    chmod 400 /.password*
    sed -i 's/^command=x11vnc.*/& -rfbauth \/.password2/' /etc/supervisor/conf.d/supervisord.conf
    export VNC_PASSWORD=
fi

if [ -n "$RESOLUTION" ]; then
    debug && echo "starting set resolution section"
    sed -i "s/1024x768/$RESOLUTION/" /usr/local/bin/xvfb.sh
fi
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

debug && echo "about to remove \%USER\%:\%USER\% from supervisord.con"
sed -i "s|%USER%|$USER|" /etc/supervisor/conf.d/supervisord.conf

debug && echo "about to remove \%HOME\%:\%HOME\% from supervisord.conf"
sed -i "s|%HOME%|$HOME|" /etc/supervisor/conf.d/supervisord.conf

# home folder
debug && echo "about to mkdir for .config, pacmanfm, lxde"
mkdir -p $HOME/.config/pcmanfm/LXDE/
debug && echo "making hard link to /.config/pcmanfm/LXDE/"

ln -sf /usr/local/share/doro-lxde-wallpapers/desktop-items-0.conf $HOME/.config/pcmanfm/LXDE/
debug && echo "about to chown USER, -e USERNAME option performed at docker run command"

if [ ! -f /usr/local/chownstatus/chownhasrun.txt ]; then
    debug && echo "This is 1st time container has run, need to chown $USER:$USER $HOME" 
    chown -R --verbose $USER:$USER $HOME
    mkdir -p /usr/local/chownstatus/
    touch /usr/local/chownstatus/chownhasrun.txt 
fi

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

BINDIRECTORY="/usr/local/bin"
REPOFILE="/usr/local/bin/repo"
debug && echo "Checking for existance of file /usr/local/bin/repo"
debug && echo "REPOFILE = $REPOFILE "
debug && echo "BINDIRECTORY = $BINDIRECTORY "
if [ ! -f "$REPOFILE" ]; then

    # Control will enter here if ~/bin doesn't exist.
    # now mkdir ~/bin and install ~/bin/repo directory with repo from NXP i.MX recommended yocto packages
    debug && echo "REPOFILE wasn't found, attempting to mkdir and curl"
    curl https://storage.googleapis.com/git-repo-downloads/repo >$REPOFILE
    chmod a+x $REPOFILE
else
    echo "repo was found!" 
fi


# now clone Poky in (from Yocto quick setup guide)
apt-get update

#HOME=/home/$USER
POKYDIR="${HOME}/poky"
debug && echo "checking if Yocto Poky has been installed already"
debug && echo "POKYDIR is = $POKYDIR"
if [ ! -d "$POKYDIR" ]; then
    echo "Yocto Poky check... POKYDIR doesn't exist so creating Poky and cloning"
    mkdir -p $POKYDIR
    echo $PWD
    git clone git://git.yoctoproject.org/poky $POKYDIR
    echo $PWD
    cd $POKYDIR
    echo $PWD
    git checkout tags/yocto-2.5 -b my-yocto-2.5
elif find $POKYDIR -mindepth 1 | read; then
    echo "POKYDIR exists, is non empty, therefore poky already installed"
else
    git clone git://git.yoctoproject.org/poky $POKYDIR
    echo $PWD
    cd $POKYDIR
    echo $PWD
    git checkout tags/yocto-2.5 -b my-yocto-2.5
fi

debug && echo "HOME ENV was $HOME"
debug && echo "setting HOME ENV to actual path"
export HOME=$HOME # don't think this is taking...
debug && echo "HOME ENV is now $HOME"
debug && sleep 10

#now add line to bashrc and profile for HOME directory's actual position
#at this point, ubuntu has HOME=/home.  But if you start container as root (default) and
#don't place a new user name in the docker run command, then HOME needs to be /root

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
