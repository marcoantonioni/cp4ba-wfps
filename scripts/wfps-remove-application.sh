#!/bin/bash

#set -euo pipefail


_me=$(basename "$0")

_APP=""
_BRANCH=""
_FORCE=false
_ENV_CFG=""

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

usage () {
  log_msg "${_CLR_GREEN}usage: $_me
    -c full-path-to-config-file
       (eg: '../configs/wfps1.properties')
    -e full-path-to-target-environment-config-file 
    -a app-acronym
    -b branch-name 
    -f (optional) force-suspend (used with: '-s deactivate' and '-r' )${_CLR_NC}"
}

#--------------------------------------------------------
# read command line params
while getopts c:e:a:b:f flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        e) _ENV_CFG=${OPTARG};;
        a) _APP=${OPTARG};;
        b) _BRANCH=${OPTARG};;
        f) _FORCE=true;;
    esac
done

if [[ -z "${_CFG}" ]] || [[ -z "${_ENV_CFG}" ]] || [[ -z "${_APP}" ]] || [[ -z "${_BRANCH}" ]]; then
  usage
  exit 1
fi

if [[ ! -f "${_CFG}" || ! -f "${_ENV_CFG}" ]]; then
  log_error "${_CLR_RED}ERROR, Configuration file not found -c '${_CLR_YELLOW}${_CFG}${_CLR_RED}' -e '${_CLR_YELLOW}${_ENV_CFG}${_CLR_RED}'${_CLR_NC}"
  usage
  exit 1
fi

export CONFIG_FILE=${_CFG}
export TARGET_ENV_CONFIG_FILE=${_ENV_CFG}

# Read target environment configuration, ignore error for IDP/LDAP configuration properties 
source ${TARGET_ENV_CONFIG_FILE} 2> /dev/null 1> /dev/null
source "${CONFIG_FILE}"

source $_SCRIPT_DIR/oc-utils.sh

removeApplication () {
  if [[ -z "${WFPS_ADMINUSER}" ]]; then
    WFPS_ADMINUSER=cpadmin
  fi
  getCsrfToken ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS}
  _URI="/std/bpm/containers/${_APP}/versions?versions=${_BRANCH}&force=${_FORCE}"
  CRED="-u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD}"
  REMOVE_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X DELETE ${WFPS_URL_OPS}/${_URI})

  if [[ "${REMOVE_RESPONSE}" == *"error_"* ]]; then
    log_error "${_CLR_RED}ERROR deleting '${_CLR_YELLOW}${_APP}/${_BRANCH}${_CLR_RED}' details:${_CLR_NC}"
    echo "${REMOVE_RESPONSE}" | jq .
    exit 1
  fi

  REMOVE_DESCR=$(echo ${REMOVE_RESPONSE} | jq .description | sed 's/"//g')
  REMOVE_URL=$(echo ${REMOVE_RESPONSE} | jq .url | sed 's/"//g')

  log_info "${_CLR_GREEN}Request result '${_CLR_YELLOW}${REMOVE_DESCR}${_CLR_GREEN}'"
  sleep 2
  log_info "${_CLR_GREEN}Get deletion status at url '${_CLR_YELLOW}${REMOVE_URL}${_CLR_GREEN}'"
  while true 
  do
    REMOVE_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X GET ${REMOVE_URL})
    REMOVE_STATE=$(echo ${REMOVE_RESPONSE} | jq .state | sed 's/"//g')
    if [[ ${REMOVE_STATE} = "running" ]]; then
      sleep 5
    else
      if [[ ${REMOVE_STATE} = "failure" ]]; then
        echo ${REMOVE_RESPONSE} | jq .
      fi
      log_info "${_CLR_GREEN}Final deletion state '${_CLR_YELLOW}${REMOVE_STATE}${_CLR_GREEN}'"
      break
    fi
  done
}

#--------------------------------------------------------

#==========================================
log_info "${_CLR_GREEN}***********************************"
log_info "${_CLR_GREEN}***** ${_CLR_YELLOW}WfPS Remove Application${_CLR_GREEN} *****"
log_info "${_CLR_GREEN}***********************************"
log_info "${_CLR_GREEN}Using config file '${_CLR_YELLOW}${_CFG}${_CLR_GREEN}'"

verifyAllParams
log_info "${_CLR_GREEN}Working on application acronym '${_CLR_YELLOW}${_APP}${_CLR_NC}' branch '${_CLR_YELLOW}${_BRANCH}${_CLR_NC}'... "
getAdminInfo
removeApplication
exit 0
