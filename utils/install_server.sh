#! /bin/sh

# Copyright 2011 Dvir Volk <dvirsk at gmail dot com>. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
#
#   1. Redistributions of source code must retain the above copyright notice, this list of
#      conditions and the following disclaimer.
#
#   2. Redistributions in binary form must reproduce the above copyright notice, this list
#      of conditions and the following disclaimer in the documentation and/or other materials
#      provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Dvir Volk OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
# # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Interactive service installer for redis server
# this generates a redis config file and an /etc/init.d script, and installs them
# this scripts should be run as root
#


die () {
	echo "ERROR: $1. Aborting!" 
	exit 1
}


#Initial defaults
_REDIS_PORT=6379

echo "Welcome to the redis service installer"
echo "This script will help you easily set up a running redis server

"

#check for root user TODO: replace this with a call to "id"
if [ `whoami` != "root" ] ; then
	echo "ERROR: You must run this installation script as root. Sorry!\n"
	exit 1
fi

#Read the redis port
read  -p "Please select the redis port for this instance: [$_REDIS_PORT] " REDIS_PORT 
if [ ! `echo $REDIS_PORT | egrep "^[0-9]+\$"`  ] ; then
	echo "Selecting default: $_REDIS_PORT"
	REDIS_PORT=$_REDIS_PORT 
fi

#read the redis config file
_REDIS_CONFIG_FILE="/etc/redis/$REDIS_PORT.conf"
read -p "Please select the redis config file name [$_REDIS_CONFIG_FILE] " REDIS_CONFIG_FILE
if [ !"$REDIS_CONFIG_FILE" ] ; then
	REDIS_CONFIG_FILE=$_REDIS_CONFIG_FILE
	echo "Selected default - $REDIS_CONFIG_FILE"
fi
#try and create it
mkdir -p `dirname "$REDIS_CONFIG_FILE"` || die "Could not create redis config directory"

#read the redis log file path
_REDIS_LOG_FILE="/var/log/redis_$REDIS_PORT.log"
read -p "Please select the redis log file name [$_REDIS_LOG_FILE] " REDIS_LOG_FILE
if [ !"$REDIS_LOG_FILE" ] ; then
	REDIS_LOG_FILE=$_REDIS_LOG_FILE
	echo "Selected default - $REDIS_LOG_FILE"
fi


#get the redis data directory
_REDIS_DATA_DIR="/var/lib/redis/$REDIS_PORT"
read -p "Please select the data directory for this instance [$_REDIS_DATA_DIR] " REDIS_DATA_DIR
if [ !"$REDIS_DATA_DIR" ] ; then
	REDIS_DATA_DIR=$_REDIS_DATA_DIR
	echo "Selected default - $REDIS_DATA_DIR"
fi
mkdir -p $REDIS_DATA_DIR || die "Could not create redis data directory"

#get the redis executable path
_REDIS_EXECUTABLE=`which redis-server`
read -p "Please select the redis executable path [$_REDIS_EXECUTABLE] " REDIS_EXECUTABLE
if [ ! -f "$REDIS_EXECUTABLE" ] ; then
	REDIS_EXECUTABLE=$_REDIS_EXECUTABLE
	
	if [ ! -f "$REDIS_EXECUTABLE" ] ; then
		echo "Mmmmm...  it seems like you don't have a redis executable. Did you run make install yet?"
		exit 1
	fi
	
fi

#render the tmplates
TMP_FILE="/tmp/$REDIS_PORT.conf"
TPL_FILE="./redis.conf.tpl"
INIT_TPL_FILE="./redis_init_script.tpl"
INIT_SCRIPT_DEST="/etc/init.d/redis_$REDIS_PORT"

#check the default for redis cli
CLI_EXEC=`which redis-cli`
if [ ! "$CLI_EXEC" ] ; then 
	CLI_EXEC=`dirname $REDIS_EXECUTABLE`"/redis-cli"
fi

#Generate config file from template
echo "## Generated by install_server.sh ##" > $TMP_FILE
cat $TPL_FILE | while read line; do eval "echo \"$line\"" >> $TMP_FILE; done
cp -f $TMP_FILE $REDIS_CONFIG_FILE || exit 1

#Generate sample script from template file
rm -f $TMP_FILE

#we hard code the configs here to avoid issues with templates containing env vars
#kinda lame but works!
REDIS_INIT_HEADER=\
"#/bin/sh\n
#Configurations injected by install_server below....\n\n
EXEC=$REDIS_EXECUTABLE\n
CLIEXEC=$CLI_EXEC\n
PIDFILE=/var/run/redis_${REDIS_PORT}.pid\n
CONF=\"$REDIS_CONFIG_FILE\"\n\n
###############\n\n"

#combine the header and the template (which is actually a static footer)
echo $REDIS_INIT_HEADER > $TMP_FILE && cat $INIT_TPL_FILE >> $TMP_FILE || die "Could not write init script to $TMP_FILE"

#copy to /etc/init.d
cp -f $TMP_FILE $INIT_SCRIPT_DEST && chmod +x $INIT_SCRIPT_DEST || die "Could not copy redis init script to  $INIT_SCRIPT_DEST"
echo "Copied $TMP_FILE => $INIT_SCRIPT_DEST"

#Install the service
echo "Installing service..."
update-rc.d redis_$REDIS_PORT defaults && echo "Success!"
/etc/init.d/redis_$REDIS_PORT start || die "Failed starting service..."

#tada
echo "Installation successful!"
exit 0



