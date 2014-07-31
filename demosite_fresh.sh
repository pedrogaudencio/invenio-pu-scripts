#!/bin/bash
# v0.0.1
# Install fresh Invenio demosite pu instance
# Tested on Ubuntu 13.04
# Pedro Gaudêncio <pedro.gaudencio@cern.ch>

BRANCH=pu
#set -e

usage="$(basename "$0") [-h] [-v] [-d] -- install fresh Invenio demosite pu instance

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

	if [ ! -d $HOME/src/invenio-demosite ]; then
		git clone --branch $BRANCH git://github.com/inveniosoftware/invenio-demosite.git
	fi

	if [ ! -d $WORKON_HOME/$VIRTUALENV ]; then
		mkvirtualenv $VIRTUALENV
	else
		echo "$VIRTUALENV virtualenv already exists, proceeding work on $VIRTUALENV."
	fi

	workon $VIRTUALENV || source $WORKON_HOME/$VIRTUALENV/bin/activate
	cdvirtualenv
	mkdir src; cd src
	$HOME/bin/git-new-workdir $HOME/src/invenio/ invenio $BRANCH
	$HOME/bin/git-new-workdir $HOME/src/invenio-demosite/ invenio-demosite $BRANCH
}

install_invenio() {
	echo "Installing Invenio..."
	cd invenio
	pip install -r requirements.txt
	pip install -e .
	python setup.py compile_catalog
	npm install
	bower install
	grunt
	inveniomanage collect
}

install_demosite() {
	echo "Installing Invenio-Demosite..."
	cdvirtualenv src/invenio-demosite/
	pip install -r requirements.txt --exists-action i
	inveniomanage bower -i bower-base.json > bower.json
	bower install
}

config_invenio() {
	echo "Configuring Invenio..."
	cdvirtualenv src/invenio/
	inveniomanage config create secret-key
	inveniomanage config set CFG_EMAIL_BACKEND flask.ext.email.backends.console.Mail
	inveniomanage config set CFG_BIBSCHED_PROCESS_USER $USER
	inveniomanage config set CFG_DATABASE_NAME $DATABASE_NAME
	inveniomanage config set CFG_DATABASE_USER $BRANCH
	inveniomanage config set CFG_SITE_URL http://0.0.0.0:4000
	inveniomanage config set CFG_SITE_SECURE_URL http://0.0.0.0:4000
	inveniomanage config set COLLECT_STORAGE invenio.ext.collect.storage.link
	inveniomanage config set LESS_BIN `find $PWD/node_modules -iname lessc | head -1`
	inveniomanage config set CLEANCSS_BIN `find $PWD/node_modules -iname cleancss | head -1`
	inveniomanage config set REQUIREJS_BIN `find $PWD/node_modules -iname r.js | head -1`
	inveniomanage config set UGLIFYJS_BIN `find $PWD/node_modules -iname uglifyjs | head -1`
	inveniomanage config set REQUIREJS_RUN_IN_DEBUG False
	inveniomanage config set DEBUG True
}

setup_demosite() {
	echo "Setting up Invenio-Demosite..."
	cdvirtualenv src/invenio-demosite/
	inveniomanage database init --user=root --password=mysql --yes-i-know
	inveniomanage database create
	inveniomanage demosite create --packages=invenio_demosite.base
}

install_fresh_invenio_demosite() {
	activate_venvwrapper
	create_vars
	create_workdirs
	create_workenv
	install_invenio
	install_demosite
	config_invenio
	setup_demosite
	printf "\n\nFinished. Enjoy your Invenio demosite instalation!\n\n"
}

install_fresh_invenio_demosite
