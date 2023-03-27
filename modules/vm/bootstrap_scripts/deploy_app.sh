#!/bin/bash
set -ex
set -o pipefail

# version: 26Mar2023

##################################################
#############     SET GLOBALS     ################
##################################################

REPO_NAME="create-azure-vm"

GIT_REPO_URL="https://github.com/miztiik/$REPO_NAME.git"

APP_DIR="/var/$REPO_NAME"

LOG_FILE="/var/log/miztiik-automation-bootstrap.log"

# https://learn.microsoft.com/en-us/azure/virtual-machines/linux/tutorial-automate-vm-deployment

instruction()
{
  echo "usage: ./build.sh package <stage> <region>"
  echo ""
  echo "/build.sh deploy <stage> <region> <pkg_dir>"
  echo ""
  echo "/build.sh test-<test_type> <stage>"
}

echoerror() {
    printf "${RC} * ERROR${EC}: $@\n" 1>&2;
}

assume_role() {
  if [ -n "$DEPLOYER_ROLE_ARN" ]; then
    echo "Assuming role $DEPLOYER_ROLE_ARN ..."
  fi
}

unassume_role() {
  unset TOKEN
}

function clone_git_repo(){
    install_libs
    # mkdir -p /var/
    cd /var
    git clone $GIT_REPO_URL

}

function add_env_vars(){
    IMDS=`curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01"`
}

function install_libs(){
    # Prepare the server for python3
    yum -y install python-pip python3 git
    yum -y install jq
}

function install_nodejs(){
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
    . ~/.nvm/nvm.sh
    nvm install node
    node -e "console.log('Running Node.js ' + process.version)"
}

function check_execution(){
    echo "hello" >/tmp/miztiik.log
}

check_execution                 | tee "${LOG_FILE}"
install_libs                    | tee "${LOG_FILE}"



