#!/bin/bash
# v0.0.1
# Install fresh Inspire pu instance
# Tested on Ubuntu 13.04
# Pedro Gaudêncio <pedro.gaudencio@cern.ch>

configfile=fresh.cfg
BRANCH=pu
#set -e

usage="$(basename "$0") [-h] [-v] [-d] -- install fresh Inspire pu instance

where:
    -h  show this help text
    -v  set name for the virtualenv (default: invenio)
    -d  set name for the database (default: pu)"

while getopts :h:v:d: option; do
        case "${option}" in
			h) echo "$usage"; exit;;
			v) VIRTUALENV=${OPTARG};;
			d) DATABASE_NAME=${OPTARG};;
        esac
done
shift $((OPTIND - 1))

activate_venvwrapper () {
	echo "Activating virtualenvwrapper..."
	source `which virtualenvwrapper.sh` || source "/usr/local/bin/virtualenvwrapper.sh"
}

source_cfg_file() {
	# check if the file contains something we don't want
	if egrep -q -v '^#|^[^ ]*=[^;]*' "$configfile"; then
	  echo "Config file is unclean, cleaning it..." >&2
	  # filter the original to a new file
	  egrep '^#|^[^ ]*=[^;&]*'  "$configfile" > "$configfile_secured"
	  configfile="$configfile_secured"
	fi

	# now source it, either the original or the filtered variant
	source "$configfile"
}

create_vars() {
	echo "Creating path variables..."
	if [ ! $VIRTUALENV ]; then
		if [ ! $virtual_env ]; then
			VIRTUALENV="invenio"
		else
			VIRTUALENV=$virtual_env
		fi
	fi

	if [ ! $DATABASE_NAME ]; then
		if [ ! $db_name ]; then
			DATABASE_NAME=$BRANCH
		else
			DATABASE_NAME=$db_name
		fi
	fi
}

create_workdirs() {
	if [ ! -d $HOME/bin ]; then
		echo "Creating script directories $HOME/bin..."
		mkdir -p $HOME/bin
	fi

	if [ ! -f $HOME/bin/git-new-workdir ]; then
		echo "Setting up git-new-workdir..."
		wget https://raw.github.com/git/git/master/contrib/workdir/git-new-workdir \
	     -O $HOME/bin/git-new-workdir
		chmod +x $HOME/bin/git-new-workdir
	fi
}

create_workenv() {
	if [ ! -d $HOME/src ]; then
		echo "Creating working environment $HOME/src..."
		mkdir -p $HOME/src; cd $HOME/src/
	else
		cd $HOME/src/
	fi

	#TODO: check if this works properly
	if [[ $repo_invenio && $branch_invenio && $repo_invenio_remote_name ]]; then
		if [ ! -d $HOME/src/invenio ]; then
			git clone --branch $branch_invenio $repo_invenio
		else
			cd $HOME/src/invenio
			branch_exists=`git show-ref refs/heads/$branch_invenio`

			if [[ $repo_invenio == "$(git ls-remote --get-url)" && -n "$branch_exists" ]]; then
				if [ $branch_invenio != "$(git symbolic-ref --short HEAD 2>/dev/null)"]; then
					git checkout $branch_invenio
				fi
			else
				git remote add $repo_invenio_remote_name $repo_invenio
				git fetch $repo_invenio_remote_name $branch_invenio
				git checkout $repo_invenio_remote_name/$branch_invenio
				git checkout -b $branch_invenio
			fi
		fi
	else
		if [ ! -d $HOME/src/invenio ]; then
			git clone --branch $BRANCH git://github.com/inveniosoftware/invenio.git
		fi
	fi

	if [ ! -d $WORKON_HOME/$VIRTUALENV ]; then
		mkvirtualenv $VIRTUALENV
	else
		echo "$VIRTUALENV virtualenv already exists, proceeding work on $VIRTUALENV."
	fi

	workon $VIRTUALENV || source $WORKON_HOME/$VIRTUALENV/bin/activate
	cdvirtualenv
	mkdir -p var/run/
	mkdir src; cd src
	$HOME/bin/git-new-workdir $HOME/src/invenio/ invenio $BRANCH
}

install_invenio() {
	echo "Installing Invenio..."
	cd invenio
	pip install -r requirements.txt
	pip install -e .
	if [ $install_ipython == true ]; then
		pip install ipython
	fi
	python setup.py compile_catalog
}

install_inspire() {
	echo "Installing Inspire..."
	cd $HOME/src

	#TODO: check if this works properly
	if [[ $repo_inspire && $branch_inspire && $repo_inspire_remote_name ]]; then
		if [ ! -d $HOME/src/invenio ]; then
			git clone --branch $branch_inspire $repo_inspire
		else
			cd $HOME/src/inspire-next
			branch_exists=`git show-ref refs/heads/$branch_inspire`
			if [[ $repo_inspire == "$(git ls-remote --get-url)" && -n "$branch_exists" ]]; then
				if [ $branch_inspire != "$(git symbolic-ref --short HEAD 2>/dev/null)"]; then
					git checkout $branch_inspire
				fi
			else
				git remote add $repo_inspire_remote_name $repo_inspire
				git fetch $repo_inspire_remote_name $branch_inspire
				git checkout $repo_inspire_remote_name/$branch_inspire
				git checkout -b $branch_inspire
			fi
		fi
	else
		if [ ! -d $HOME/src/invenio ]; then
			git clone git@github.com:inspirehep/inspire-next.git
		fi
	fi

	cdvirtualenv src/
	$HOME/bin/git-new-workdir $HOME/src/inspire-next/ inspire
	cd inspire
	pip install -r requirements.txt --exists-action i
	inveniomanage bower -i bower-base.json > bower.json
	bower install
}

config_invenio() {
	echo "Configuring Invenio..."
	inveniomanage config create secret-key
	inveniomanage config set CFG_EMAIL_BACKEND flask.ext.email.backends.console.Mail
	inveniomanage config set CFG_BIBSCHED_PROCESS_USER $USER
	inveniomanage config set CFG_DATABASE_NAME $DATABASE_NAME
	inveniomanage config set CFG_DATABASE_USER $BRANCH
	inveniomanage config set CFG_SITE_URL http://0.0.0.0:4000
	inveniomanage config set CFG_SITE_SECURE_URL http://0.0.0.0:4000
	inveniomanage config set CFG_BIBSCHED_NON_CONCURRENT_TASKS "[]"
	inveniomanage config set COLLECT_STORAGE invenio.ext.collect.storage.link
	npm install less clean-css requirejs uglify-js
	inveniomanage config set LESS_BIN `find $PWD/node_modules -iname lessc | head -1`
	inveniomanage config set CLEANCSS_BIN `find $PWD/node_modules -iname cleancss | head -1`
	inveniomanage config set REQUIREJS_BIN `find $PWD/node_modules -iname r.js | head -1`
	inveniomanage config set UGLIFYJS_BIN `find $PWD/node_modules -iname uglifyjs | head -1`
	inveniomanage config set REQUIREJS_RUN_IN_DEBUG False
	inveniomanage config set DEBUG True
}

populate_inspire() {
	echo "Configuring Inspire..."
	inveniomanage collect
	if [ $mysql_root_passwd ]; then
		inveniomanage database init --yes-i-know --user=root --password=$mysql_root_passwd
	else
		inveniomanage database init --yes-i-know --user=root --password=mysql
	fi
	inveniomanage demosite create -p inspire.base
	inveniomanage demosite populate -p inspire.base -f inspire/testsuite/data/demo-records.xml
}

config_git() {
	if [ $git_mail ]; then
		cdvirtualenv src/invenio
		git config user.email "$git_mail"
		cdvirtualenv src/inspire-next
		git config user.email "$git_mail"
	fi
}

install_fresh_inspire() {
	activate_venvwrapper
	create_vars
	create_workdirs
	create_workenv
	install_invenio
	install_inspire
	config_invenio
	populate_inspire
	config_git
	printf "\n\nFinished. Enjoy your Inspire instalation!\n\n"
}

install_fresh_inspire
