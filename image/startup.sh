#!/bin/bash
echo "Beginning of startup.sh script"

if [ -n "$VNC_PASSWORD" ]; then
    echo "starting set password section"
    echo -n "$VNC_PASSWORD" > /.password1
    x11vnc -storepasswd $(cat /.password1) /.password2
    chmod 400 /.password*
    sed -i 's/^command=x11vnc.*/& -rfbauth \/.password2/' /etc/supervisor/conf.d/supervisord.conf
    export VNC_PASSWORD=
fi

if [ -n "$RESOLUTION" ]; then
    echo "starting set resolution section"
    sed -i "s/1024x768/$RESOLUTION/" /usr/local/bin/xvfb.sh
fi
echo "THIS IS THE HOME DIRECTORY BEFORE SETTING HOME TO ROOT"
echo $HOME
pwd
sleep 2
echo "setting USER to root"
USER=${USER:-root}
echo "setting HOME to root"
HOME=/root
if [ "$USER" != "root" ]; then
    echo "starting user not equal to root"
    echo "* enable custom user: $USER"
    useradd --create-home --shell /bin/bash --user-group --groups adm,sudo $USER
    if [ -z "$PASSWORD" ]; then
        echo "  set default password to \"ubuntu\""
        PASSWORD=password
    fi
    HOME=/home/$USER
    echo "$USER:$PASSWORD" | chpasswd
    cp -r /root/{.gtkrc-2.0,.asoundrc} ${HOME}
    [ -d "/dev/snd" ] && chgrp -R adm /dev/snd
fi

echo "hello, enter some input"
sleep 5

read varname

echo "starting sed -i etc, supervisor, conf.d, supervisord.conf"
sed -i "s|%USER%|$USER|" /etc/supervisor/conf.d/supervisord.conf

echo "starting 2nd line of sed -i etc, supervisor, conf.d, supervisord.conf"
sed -i "s|%HOME%|$HOME|" /etc/supervisor/conf.d/supervisord.conf

# home folder
echo "about to mkdir for .config, pacmanfm, lxde"
mkdir -p $HOME/.config/pcmanfm/LXDE/
echo "about to ln -sf /usr/local/share/doro-lxde-wallpapers/desktop-teims.blah"

ln -sf /usr/local/share/doro-lxde-wallpapers/desktop-items-0.conf $HOME/.config/pcmanfm/LXDE/
echo "about to chown USER"

if [ ! -f /usr/local/chownstatus/chownhasrun.txt ]; then
    echo "this is the first time the container has run, need to chown $USER:$USER $HOME" 
    chown -R --verbose $USER:$USER $HOME
    mkdir -p /usr/local/chownstatus/
    touch /usr/local/chownstatus/chownhasrun.txt 
fi

# nginx workers
echo "about to sed -i nginx workers"
sed -i 's|worker_processes .*|worker_processes 1;|' /etc/nginx/nginx.conf

# nginx ssl
if [ -n "$SSL_PORT" ] && [ -e "/etc/nginx/ssl/nginx.key" ]; then
    echo "* enable SSL"
    echo "starting to enable SSL"
	sed -i 's|#_SSL_PORT_#\(.*\)443\(.*\)|\1'$SSL_PORT'\2|' /etc/nginx/sites-enabled/default
	sed -i 's|#_SSL_PORT_#||' /etc/nginx/sites-enabled/default
fi

# nginx http base authentication
if [ -n "$HTTP_PASSWORD" ]; then
    echo "about to enable http base authentication"
    echo "* enable HTTP base authentication"
    htpasswd -bc /etc/nginx/.htpasswd $USER $HTTP_PASSWORD
	sed -i 's|#_HTTP_PASSWORD_#||' /etc/nginx/sites-enabled/default
fi

# novnc websockify
echo "about to novnc websockify"
echo "about to ln -s /usr/local/lib/web/frontend/static/websockify"

ln -s /usr/local/lib/web/frontend/static/websockify /usr/local/lib/web/frontend/static/novnc/utils/websockify
echo "about to chmod +x /usr/local/lib/web/frontend/static/websockify/run"
chmod +x /usr/local/lib/web/frontend/static/websockify/run

# clearup
echo "clearup.  about to set password and http_password to null"

PASSWORD=
HTTP_PASSWORD=

BINDIRECTORY="/usr/local/bin"
REPOFILE="/usr/local/bin/repo"
echo "about to check for existence of file /usr/local/bin/repo"
echo "REPOFILE = $REPOFILE "
echo "BINDIRECTORY = $BINDIRECTORY "
if [ ! -f "$REPOFILE" ]; then

    # Control will enter here if ~/bin doesn't exist.
    # now mkdir ~/bin and install ~/bin/repo directory with repo from NXP i.MX recommended yocto packages
    echo "REPOFILE wasn't found, attempting to mkdir and curl"
    curl https://storage.googleapis.com/git-repo-downloads/repo > $REPOFILE
    chmod a+x $REPOFILE
else
    echo "repo was found!" 
fi


# now clone Poky in (from Yocto quick setup guide)
apt-get update

if find /home/kyle/foo -mindepth 1 | read; then
   echo "dir not empty"
else
   echo "dir empty"
fi

#HOME=/home/$USER
POKYDIR="${HOME}/poky"
echo "POKYDIR is = $POKYDIR"
if [ ! -d "$POKYDIR" ]; then
    echo "POKYDIR doesn't exist so creating Poky and cloning"
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


echo "about to exec /bin/tini -- usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf"

exec /bin/tini -- /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
