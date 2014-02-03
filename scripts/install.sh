#!/bin/bash

# HOW TO EXECUTE:
#	1.	SSH into a fresh installation of Ubuntu 12.10 64-bit
#	2.	Put this script anywhere, such as /tmp/install.sh
#	3.	$ chmod +x /tmp/install.sh && /tmp/install.sh
#

# NOTES:
#	1.	IMPORTANT: You must create a .#production file in the root of your Meteor
#		app. An example .#production file looks like this:
#
# 		export MONGO_URL='mongodb://user:pass@linus.mongohq.com:10090/dbname'
# 		export ROOT_URL='http://www.mymeteorapp.com'
# 		export NODE_ENV='production'
# 		export PORT=80
#
#	2.	The APPHOST variable below should be updated to the hostname or elastic
#		IP of the EC2 instance you created.
#
#	3.	The SERVICENAME variable below can remain the same, but if you prefer
#		you can name it after your app (example: SERVICENAME=foobar).
#
#	4.	Logs for you app can be found under /var/log/[SERVICENAME].log
#

################################################################################
# Variables you should adjust for your setup
################################################################################

APPHOST=ec2-54-242-4-24.compute-1.amazonaws.com
SERVICENAME=BieberTweets_angular
PORT=3003
NODE_ENV=production

################################################################################
# Internal variables
################################################################################

MAINUSER=$(whoami)
MAINGROUP=$(id -g -n $MAINUSER)

GITBAREREPO=/home/$MAINUSER/$SERVICENAME.git
EXPORTFOLDER=/tmp/$SERVICENAME
APPFOLDER=/home/$MAINUSER/Apps/$SERVICENAME

################################################################################
# Utility functions
################################################################################

function replace {
	sudo perl -0777 -pi -e "s{\Q$2\E}{$3}gm" "$1"
}

function replace_noescape {
	sudo perl -0777 -pi -e "s{$2}{$3}gm" "$1"
}

function symlink {
	if [ ! -f $2 ]
		then
			sudo ln -s "$1" "$2"
	fi
}

function append {
	echo -e "$2" | sudo tee -a "$1" > /dev/null
}

################################################################################
# Task functions
################################################################################

function setup_app_skeleton {
	echo "--------------------------------------------------------------------------------"
	echo "Setup app skeleton"
	echo "--------------------------------------------------------------------------------"

	rm -rf $APPFOLDER
	mkdir -p $APPFOLDER
}

function setup_app_service {
	echo "--------------------------------------------------------------------------------"
	echo "Setup app service"
	echo "--------------------------------------------------------------------------------"

	local SERVICEFILE=/etc/init.d/$SERVICENAME
	local LOGFILE=/var/log/$SERVICENAME.log

	sudo rm -f $SERVICEFILE

	append $SERVICEFILE "#!/bin/bash"
	append $SERVICEFILE " "

	append $SERVICEFILE "test -x \$NODE || exit 0"

	append $SERVICEFILE "function start_app {"
	append $SERVICEFILE "	NODE_ENV=$NODE_ENV PORT=$PORT nohup /usr/local/bin/node $APPFOLDER/server.js >> $LOGFILE 2>&1 &"
	append $SERVICEFILE "	\$! > \"/var/run/$SERVICENAME.pid\""
	append $SERVICEFILE "}"

	append $SERVICEFILE "function stop_app {"
  	append $SERVICEFILE "kill `cat /var/run/$SERVICENAME.pid`"
	append $SERVICEFILE "}"

	append $SERVICEFILE "case $1 in"
	append $SERVICEFILE "   start)"
	append $SERVICEFILE "      start_app ;;"
	append $SERVICEFILE "    stop)"
	append $SERVICEFILE "      stop_app ;;"
	append $SERVICEFILE "    restart)"
	append $SERVICEFILE "      stop_app"
	append $SERVICEFILE "      start_app"
	append $SERVICEFILE "      ;;"
	append $SERVICEFILE "    *)"
	append $SERVICEFILE "      echo \"usage: $APP {start|stop}\" ;;"
	append $SERVICEFILE "esac"
	append $SERVICEFILE "exit 0"
	
}

function setup_bare_repo {
	echo "--------------------------------------------------------------------------------"
	echo "Setup bare repo"
	echo "--------------------------------------------------------------------------------"

	rm -rf $GITBAREREPO
	mkdir -p $GITBAREREPO
	cd $GITBAREREPO

	git init --bare
	git update-server-info
}

function setup_post_update_hook {
	echo "--------------------------------------------------------------------------------"
	echo "Setup post update hook"
	echo "--------------------------------------------------------------------------------"

	local HOOK=$GITBAREREPO/hooks/post-receive
	local RSYNCSOURCE=$EXPORTFOLDER/app_rsync

	rm -f $HOOK

	append $HOOK "#!/bin/bash"
	append $HOOK "unset \$(git rev-parse --local-env-vars)"

	append $HOOK "echo \"------------------------------------------------------------------------\""
	append $HOOK "echo \"Exporting app from git repo\""
	append $HOOK "echo \"------------------------------------------------------------------------\""
	append $HOOK "sudo rm -rf $EXPORTFOLDER"
	append $HOOK "mkdir -p $EXPORTFOLDER"
	append $HOOK "git archive master | tar -x -C $EXPORTFOLDER"

	# append $HOOK "echo \"------------------------------------------------------------------------\""
	# append $HOOK "echo \"Updating production executable\""
	# append $HOOK "echo \"------------------------------------------------------------------------\""
	# append $HOOK "echo -e \"export NODE_ENV=$NODE_ENV\\n\" > $APPEXECUTABLE"
	# append $HOOK "echo -e \"export PORT=$PORT \\n\"  >> $APPEXECUTABLE"
	# append $HOOK "echo -e \"\\\n\\\n/usr/bin/node $APPFOLDER/server.js >> \\\$1 2>&1\" >> $APPEXECUTABLE"
	# append $HOOK "chmod 700 $APPEXECUTABLE"

	append $HOOK "echo \"------------------------------------------------------------------------\""
	append $HOOK "echo \"Bundling app as a standalone Node.js app\""
	append $HOOK "echo \"------------------------------------------------------------------------\""
	append $HOOK "cd $EXPORTFOLDER"
	append $HOOK "npm install"
	append $HOOK "bower install"
	append $HOOK "grunt build"

	append $HOOK "echo \"------------------------------------------------------------------------\""
	append $HOOK "echo \"Rsync standalone app to active app location\""
	append $HOOK "echo \"------------------------------------------------------------------------\""
	append $HOOK "rsync --checksum --recursive --update --delete --times $EXPORTFOLDER/ $APPFOLDER/"

	append $HOOK "echo \"------------------------------------------------------------------------\""
	append $HOOK "echo \"Restart app\""
	append $HOOK "echo \"------------------------------------------------------------------------\""
	append $HOOK "sudo /etc/init.d/SERVICENAME restart"

	# Clean-up
	append $HOOK "cd $APPFOLDER"
	append $HOOK "sudo rm -rf $EXPORTFOLDER"

	append $HOOK "echo \"\n\n--- Done.\""

	sudo chown $MAINUSER:$MAINGROUP $HOOK
	chmod +x $HOOK
}

function show_conclusion {
	echo -e "\n\n\n\n\n"
	echo "########################################################################"
	echo " On your local development server"
	echo "########################################################################"
	echo ""
	echo "Add remote repository:"
	echo "$ git remote add ec2 $MAINUSER@$APPHOST:$SERVICENAME.git"
	echo ""
	echo "To deploy:"
	echo "$ git push ec2 master"
	echo ""
}

################################################################################


setup_app_skeleton
setup_app_service
setup_bare_repo
setup_post_update_hook
show_conclusion