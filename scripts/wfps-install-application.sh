#!/bin/bash

#set -euo pipefail


_me=$(basename "$0")

_ENV_CFG=""

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

  echo "Installing application: "$5
  CRED="-u $1:$2"
  INST_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '$4 -H 'Content-Type: multipart/form-data' -F 'install_file=@'$5';type=application/x-zip-compressed' -X POST $3/std/bpm/containers/install?inactive=false%26caseOverwrite=false)
  INST_DESCR=$(echo ${INST_RESPONSE} | jq .description | sed 's/"//g')
  INST_URL=$(echo ${INST_RESPONSE} | jq .url | sed 's/"//g')

  echo "Request result: "${INST_DESCR}
  sleep 2
  echo "Get installation status at url: "${INST_URL}
  while true 
  do
    echo -n "."
    INST_STATE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '$4 -X GET ${INST_URL} | jq .state | sed 's/"//g')
    if [[ ${INST_STATE} == "running" ]]; then
      sleep 5
    else
      echo ""
      echo "Final installation state: "${INST_STATE}
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
echo "*** WfPS Application Installation ***"
echo "*************************************"
echo "Using config file: "${CONFIG_FILE}" for application: "${APPLICATION_FILE}

# Read target environment configuration, ignore error for IDP/LDAP configuration properties 
source ${TARGET_ENV_CONFIG_FILE} 2> /dev/null 1> /dev/null
source ${CONFIG_FILE}

verifyAllParams

if [[ ! -f ${APPLICATION_FILE} ]]; then
  echo ""
  echo "ERROR: file "${APPLICATION_FILE}" not found."
  exit 1
fi

getAdminInfo
getCsrfToken ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS}

installApplication ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS} ${WFPS_CSRF_TOKEN} ${APPLICATION_FILE}

# verifyInstalledApplication ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS} ${WFPS_CSRF_TOKEN} "SimpleDemoWfPS"

exit 0

