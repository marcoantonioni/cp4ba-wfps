#!/bin/bash

#set -euo pipefail


_me=$(basename "$0")

#--------------------------------------------------------
_CLR_RED="\033[0;31m"   #'0;31' is Red's ANSI color code
_CLR_GREEN="\033[0;32m"   #'0;32' is Green's ANSI color code
_CLR_YELLOW="\033[1;33m"   #'1;32' is Yellow's ANSI color code
_CLR_BLUE="\033[0;34m"   #'0;34' is Blue's ANSI color code
_CLR_NC="\033[0m"

#----------------------------------------------------
_SCRIPT_PATH="${BASH_SOURCE}"
while [ -L "${_SCRIPT_PATH}" ]; do
  _SCRIPT_DIR="$(cd -P "$(dirname "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"
  _SCRIPT_PATH="$(readlink "${_SCRIPT_PATH}")"
  [[ ${_SCRIPT_PATH} != /* ]] && _SCRIPT_PATH="${_SCRIPT_DIR}/${_SCRIPT_PATH}"
done
_SCRIPT_PATH="$(readlink -f "${_SCRIPT_PATH}")"
_SCRIPT_DIR="$(cd -P "$(dirname -- "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"

#----------------------------------------------------
if [[ ! -f "$_SCRIPT_DIR/../../cp4ba-logger/scripts/logger.sh" ]]; then
  echo "Error, log package not found !"
  echo "Clone it alongside with other cp4ba-..."
  echo "use the command: git clone https://github.com/marcoantonioni/cp4ba-logger"
  exit 1
fi
source $_SCRIPT_DIR/../../cp4ba-logger/scripts/logger.sh
if [[ -z "${CP4BA_LOGGING_ENABLED}" ]]; then 
  export CP4BA_LOGGING_ENABLED=true
fi
if [[ -z "${CP4BA_LOG_LEVEL}" ]]; then 
  export CP4BA_LOG_LEVEL="INFO"
fi
if [[ -z "${CP4BA_LOG_TO_CONSOLE}" ]]; then 
  export CP4BA_LOG_TO_CONSOLE=true
fi
if [[ -z "${CP4BA_LOG_TO_FILE}" ]]; then 
  export CP4BA_LOG_TO_FILE=false
fi
if [[ -z "${CP4BA_LOG_FILE}" ]]; then 
  export CP4BA_LOG_FILE=""
fi
if [[ -z "${CP4BA_LOG_MAX_SIZE}" ]]; then 
  export CP4BA_LOG_MAX_SIZE=$((10 * 1024 * 1024))
fi
if [[ -z "${CP4BA_LOG_BACKUP_COUNT}" ]]; then 
  export CP4BA_LOG_BACKUP_COUNT=5
fi

_APP=""
_DETAILS=false
_ENV_CFG=""

#--------------------------------------------------------
# read command line params
while getopts c:e:a:d flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        e) _ENV_CFG=${OPTARG};;
        a) _APP=${OPTARG};;
        d) _DETAILS=true;;
    esac
done

_SCRIPT_PATH="${BASH_SOURCE}"
while [ -L "${_SCRIPT_PATH}" ]; do
  _SCRIPT_DIR="$(cd -P "$(dirname "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"
  _SCRIPT_PATH="$(readlink "${_SCRIPT_PATH}")"
  [[ ${_SCRIPT_PATH} != /* ]] && _SCRIPT_PATH="${_SCRIPT_DIR}/${_SCRIPT_PATH}"
done
_SCRIPT_PATH="$(readlink -f "${_SCRIPT_PATH}")"
_SCRIPT_DIR="$(cd -P "$(dirname -- "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"

source $_SCRIPT_DIR/oc-utils.sh

if [[ -z "${_CFG}" ]]; then
  log_msg "usage: $_me -c path-of-config-file -e full-path-to-target-environment-config-file -a [optional] app-name -d [optional] app-details"
  exit 1
fi     

export CONFIG_FILE=${_CFG}
export TARGET_ENV_CONFIG_FILE=${_ENV_CFG}
export APPLICATION_NAME=${_APP}

#------------------------------------------
listAllApplications () {
# $1 admin user
# $2 admin password
# $3 url ops
# $4 csrf token

  CRED="-u $1:$2"
  _URI="/std/bpm/installedVersions?filter=All&sortType=Name&sortOrder=ASC&offset=0&limit=10&includeStateAndPossibleActions=true&includeBranchTipVersions=false"
  _APPS=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '$4 -X GET $3/${_URI} | jq .installedVersions)

  if [[ "${_DETAILS}" = "true" ]]; then
    echo ${_APPS} | jq .[]
  else
    log_msg "${_CLR_YELLOW}Name, Branch, State"
    log_msg "${_CLR_GREEN}-------------------"

    for row in $(echo "${_APPS}" | jq -r '.[] | @base64'); do
        _jq() {
          
          _APP_NAME=$(echo ${row} | base64 --decode | jq -r ".project_name")
          _APP_BRANCH=$(echo ${row} | base64 --decode | jq -r ".branch_name")
          _APP_STATE=$(echo ${row} | base64 --decode | jq -r ".state")

          echo "${_APP_NAME}, ${_APP_BRANCH}, ${_APP_STATE}" | sed 's/"//g'
        }
      echo $(_jq '.project_name')

    done
  fi  
}

#------------------------------------------
applicationInfo () {
# $1 admin user
# $2 admin password
# $3 url ops
# $4 csrf token
# $5 app name

  CRED="-u $1:$2"
  _URI="/std/bpm/installedVersions?filter=All&sortType=Name&sortOrder=ASC&offset=0&limit=10&includeStateAndPossibleActions=true&includeBranchTipVersions=false"
  _APP=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '$4 -X GET $3/${_URI} | jq '.installedVersions[] | select(.project_name | IN("'$5'"))')
  if [[ "${_DETAILS}" = "true" ]]; then
    echo ${_APP} | jq .
  else
    _APP_NAME=$(echo "${_APP}" | jq .project_name)
    _APP_BRANCH=$(echo "${_APP}" | jq .branch_name)
    _APP_STATE=$(echo "${_APP}" | jq .state)
    echo "${_APP_NAME}, ${_APP_BRANCH}, ${_APP_STATE}" | sed 's/"//g'
  fi
}


#==========================================
log_info "${_CLR_GREEN}*************************************"
log_info "${_CLR_GREEN}*** ${_CLR_YELLOW}WfPS Application Informations${_CLR_GREEN} ***"
log_info "${_CLR_GREEN}*************************************"
log_info "${_CLR_GREEN}Using config file '${_CLR_YELLOW}${CONFIG_FILE}${_CLR_GREENs}'"

source ${TARGET_ENV_CONFIG_FILE} 2>/dev/null 1>/dev/null  
source ${CONFIG_FILE}

verifyAllParams

getAdminInfo
getCsrfToken ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS}

if [[ -z ${APPLICATION_NAME} ]]; then
  listAllApplications ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS} ${WFPS_CSRF_TOKEN} 
else
  applicationInfo ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS} ${WFPS_CSRF_TOKEN} ${APPLICATION_NAME}
fi

exit 0

