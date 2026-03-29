#!/bin/bash

#set -euo pipefail


_me=$(basename "$0")

_ENV_CFG=""

#--------------------------------------------------------
_CLR_RED="\033[0;31m"   #'0;31' is Red's ANSI color code
_CLR_GREEN="\033[0;32m"   #'0;32' is Green's ANSI color code
_CLR_YELLOW="\033[1;33m"   #'1;32' is Yellow's ANSI color code
_CLR_BLUE="\033[0;34m"   #'0;34' is Blue's ANSI color code
_CLR_NC="\033[0m"


#--------------------------------------------------------
# read command line params
while getopts c:e:a: flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        e) _ENV_CFG=${OPTARG};;
        a) _APP=${OPTARG};;
    esac
done

usage () {
  echo ""
  echo -e "${_CLR_GREEN}usage: $_me
    -c full-path-to-wfps-config-file 
       (eg: '../configs/env1.properties')
    -e full-path-to-target-environment-config-file 
    -a path-of-deployable-app${_CLR_NC}"
}

if [[ -z "${_CFG}" || -z ${_ENV_CFG} || -z "${_APP}" ]]; then
  usage
  exit 1
fi

export CONFIG_FILE=${_CFG}
export TARGET_ENV_CONFIG_FILE=${_ENV_CFG}
export APPLICATION_FILE=${_APP}

_SCRIPT_PATH="${BASH_SOURCE}"
while [ -L "${_SCRIPT_PATH}" ]; do
  _SCRIPT_DIR="$(cd -P "$(dirname "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"
  _SCRIPT_PATH="$(readlink "${_SCRIPT_PATH}")"
  [[ ${_SCRIPT_PATH} != /* ]] && _SCRIPT_PATH="${_SCRIPT_DIR}/${_SCRIPT_PATH}"
done
_SCRIPT_PATH="$(readlink -f "${_SCRIPT_PATH}")"
_SCRIPT_DIR="$(cd -P "$(dirname -- "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"

source $_SCRIPT_DIR/oc-utils.sh

#------------------------------------------
installApplication () {
# $1 admin user
# $2 admin password
# $3 url ops
# $4 csrf token
# $5 fullpath app file

  echo -e "Installing application '${_CLR_YELLOW}$5${_CLR_NC}'"
  CRED="-u $1:$2"
  INST_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '$4 -H 'Content-Type: multipart/form-data' -F 'install_file=@'$5';type=application/x-zip-compressed' -X POST $3/std/bpm/containers/install?inactive=false%26caseOverwrite=false)
  INST_DESCR=$(echo ${INST_RESPONSE} | jq .description | sed 's/"//g')
  INST_URL=$(echo ${INST_RESPONSE} | jq .url | sed 's/"//g')

  echo -e "Request result '${_CLR_YELLOW}${INST_DESCR}${_CLR_NC}'"
  sleep 2
  echo -e "Get installation status at url '${_CLR_YELLOW}${INST_URL}${_CLR_NC}'"
  while true 
  do
    echo -n "."
    INST_STATE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '$4 -X GET ${INST_URL} | jq .state | sed 's/"//g')
    if [[ ${INST_STATE} == "running" ]]; then
      sleep 5
    else
      echo ""
      echo -e "Final installation state '${_CLR_YELLOW}${INST_STATE}${_CLR_NC}'"
      break
    fi
  done
}

verifyInstalledApplication () {
# $1 admin user
# $2 admin password
# $3 url ops
# $4 csrf token
# $5 app name

  CRED="-u $1:$2"
  curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '$4 -X GET $3/std/bpm/containers | jq . | grep $5

}


#==========================================
echo "*************************************"
echo -e "*** ${_CLR_YELLOW}WfPS Application Installation${_CLR_NC} ***"
echo "*************************************"
echo -e "Using config file '${_CLR_YELLOW}${CONFIG_FILE}${_CLR_NC}' for application '${_CLR_YELLOW}${APPLICATION_FILE}${_CLR_NC}'"

# Read target environment configuration, ignore error for IDP/LDAP configuration properties 
source ${TARGET_ENV_CONFIG_FILE} 2> /dev/null 1> /dev/null
source ${CONFIG_FILE}

verifyAllParams

if [[ ! -f ${APPLICATION_FILE} ]]; then
  echo ""
  echo -e "${_CLR_RED}ERROR, file '${_CLR_YELLOW}${APPLICATION_FILE}${_CLR_RED}' not found.${_CLR_NC}"
  exit 1
fi

getAdminInfo
getCsrfToken ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS}

installApplication ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS} ${WFPS_CSRF_TOKEN} ${APPLICATION_FILE}

# verifyInstalledApplication ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS} ${WFPS_CSRF_TOKEN} "SimpleDemoWfPS"

exit 0

