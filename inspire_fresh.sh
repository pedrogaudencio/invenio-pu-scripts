#!/bin/bash
# v0.0.1
# Install fresh Inspire pu instance
# Tested on Ubuntu 13.04
# Pedro Gaudêncio <pedro.gaudencio@cern.ch>

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
			#r2) REPO_INSPIRE=${OPTARG};;
			#b2) BRANCH_INSPIRE=${OPTARG};;
        esac
done
shift $((OPTIND - 1))

activate_venvwrapper () {
	echo "Activating virtualenvwrapper..."
	source `which virtualenvwrapper.sh` || source "/usr/local/bin/virtualenvwrapper.sh"
}

create_vars() {
	echo "Creating path variables..."
	if [ ! $VIRTUALENV ]; then
		VIRTUALENV="invenio"
	fi

	if [ ! $DATABASE_NAME ]; then
		DATABASE_NAME=$BRANCH
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

	if [ ! -d $HOME/src/invenio ]; then
		git clone --branch $BRANCH git://github.com/inveniosoftware/invenio.git
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
	pip install ipython
	python setup.py compile_catalog
}

install_inspire() {
	echo "Installing Inspire..."
	cd $HOME/src

	if [ ! -d $HOME/src/inspire-next ]; then
		git clone git@github.com:inspirehep/inspire-next.git
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
	inveniomanage database init --yes-i-know --user=root --password=mysql
	inveniomanage demosite create -p inspire.base
	inveniomanage demosite populate -p inspire.base -f inspire/testsuite/data/demo-records.xml
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
	printf "\n\nFinished. Enjoy your Inspire instalation!\n\n"
}

install_fresh_inspire
