#!/bin/bash

#set -euo pipefail


_me=$(basename "$0")

_TSK=false
_PRO=false
_LAU=false
_ALL=false

_UN=""
_UP=""
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


#--------------------------------------------------------
# read command line params
while getopts c:e:u:w:tpla flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        e) _ENV_CFG=${OPTARG};;
        t) _TSK=true;;
        p) _PRO=true;;
        l) _LAU=true;;
        a) _ALL=true;;
        u) _UN=${OPTARG};;
        w) _UP=${OPTARG};;
    esac
done

if [[ "${_ALL}" = "false" ]] && [[ "${_ALL}" = "false" ]] && [[ "${_ALL}" = "false" ]] && [[ "${_ALL}" = "false" ]]; then
  _ALL=true
fi

if [[ "${_ALL}" = "true" ]]; then
  _TSK=true
  _PRO=true
  _LAU=true
fi

if [[ -z "${_CFG}" ]] || [[ -z "${_ENV_CFG}" ]]; then
  log_msg "usage: $_me -c path-of-config-file -e target-environment-config-file -t [display task list] -p [display process list] -l [display launchable entities] -a [display all]"
  exit 1
fi

export CONFIG_FILE=${_CFG}
export TARGET_ENV_CONFIG_FILE=${_ENV_CFG}

source $_SCRIPT_DIR/oc-utils.sh


#--------------------------------------------------------
showTasks () {
  log_info "${_CLR_GREEN}--------------------------------------------------------------"
  log_info "${_CLR_GREEN}Task list from WFPS '${_CLR_YELLOW}${WFPS_NAME}${_CLR_GREEN}'"
  _CRED="-u ${_UN}:${_UP}"
  _DATA='{"size":0,"id":0,"name":"","fields":[],"organization":"byTask","shared":false,"teams":[],"interaction":"claimed_and_available","conditions":[],"sort":[],"aliases":[]}'
  RESPONSE=$(curl -sk ${_CRED} -H "BPMCSRFToken: "${WFPS_CSRF_TOKEN} -H 'accept: application/json' -X PUT "${WFPS_EXTERNAL_BASE_URL}/rest/bpm/federated/v1/tasks?calcStats=true&usersFullName=true&size=0" -d $_DATA)

  if [[ "${RESPONSE}" == *"401"* ]] || [[ "${RESPONSE}" == *"403"* ]] || [[ "${RESPONSE}" == *"errorMessage"* ]]; then
    log_error "${_CLR_RED}ERROR${_CLR_NC}"
    echo "${RESPONSE}"
    exit 1
  else
    echo ${RESPONSE} | jq .items
    _NUM_TASKS=$(echo $RESPONSE | jq .size)
    log_msg "${_CLR_GREEN}Total tasks: ${_CLR_YELLOW}${_NUM_TASKS}"
  fi
}

#--------------------------------------------------------
showProcesses () {
  log_info "${_CLR_GREEN}--------------------------------------------------------------"
  log_info "${_CLR_GREEN}Process list from WFPS '${_CLR_YELLOW}${WFPS_NAME}${_CLR_GREEN}'"

  _CRED="-u ${_UN}:${_UP}"
  RESPONSE=$(curl -sk ${_CRED} -X 'PUT' ${WFPS_EXTERNAL_BASE_URL}/rest/bpm/federated/v1/instances \
      -H 'accept: application/json' -H 'Content-Type: application/json' -H "BPMCSRFToken: "${WFPS_CSRF_TOKEN} \
      -d '{ "shared": true, "teams": [ ], "interaction": "all", "size": 25, "name": "MySavedSearch", "sort": [ { "field": "instanceDueDate", "order": "ASC" } ], "conditions": [ ], "fields": [ "instanceDueDate", "instanceName", "instanceId", "instanceStatus", "instanceProcessApp", "instanceSnapshot", "bpdName" ]}')

  if [[ "${RESPONSE}" == *"401"* ]] || [[ "${RESPONSE}" == *"403"* ]] || [[ "${RESPONSE}" == *"errorMessage"* ]]; then
    log_error "${_CLR_RED}ERROR${_CLR_NC}"
    echo "${RESPONSE}"
    exit 1
  else
    echo ${RESPONSE} | jq .items
    _NUM_PROCESSES=$(echo $RESPONSE | jq .size)
    log_msg "${_CLR_GREEN}Total processes: ${_CLR_YELLOW}${_NUM_PROCESSES}"
  fi
}

#--------------------------------------------------------
showLaunchableEntities () {
  log_info "${_CLR_GREEN}--------------------------------------------------------------"
  log_info "${_CLR_GREEN}Launchable entities from WFPS '${_CLR_YELLOW}${WFPS_NAME}${_CLR_GREEN}'"

  _CRED="-u ${_UN}:${_UP}"
  RESPONSE=$(curl -sk ${_CRED} -H "BPMCSRFToken: ${WFPS_CSRF_TOKEN}" -H 'accept: application/json'  -X GET "${WFPS_EXTERNAL_BASE_URL}/rest/bpm/federated/v1/launchableEntities")

  if [[ "${RESPONSE}" == *"401"* ]] || [[ "${RESPONSE}" == *"403"* ]] || [[ "${RESPONSE}" == *"errorMessage"* ]]; then
    log_error "${_CLR_RED}ERROR${_CLR_NC}"
    echo "${RESPONSE}"
    exit 1
  else
    echo ${RESPONSE} | jq .items
    _NUM_ENTS=$(echo ${RESPONSE} | jq '.items | length')
    log_msg "${_CLR_GREEN}Total launchable entities: ${_CLR_YELLOW}${_NUM_ENTS}"
  fi
}

#--------------------------------------------------------
showContents () {

  if [[ "${_TSK}" = "true" ]]; then
    showTasks
  fi
  if [[ "${_PRO}" = "true" ]]; then
    showProcesses
  fi
  if [[ "${_LAU}" = "true" ]]; then
    showLaunchableEntities
  fi
}

#==========================================
log_info "${_CLR_GREEN}****************************************"
log_info "${_CLR_GREEN}**** ${_CLR_YELLOW}WFPS Show Federated Contents${_CLR_GREEN} ******"
log_info "${_CLR_GREEN}****************************************"
log_info "${_CLR_GREEN}Using config file '${_CLR_YELLOW}${CONFIG_FILE}${_CLR_GREEN}'"

# Read target environment configuration, ignore error for IDP/LDAP configuration properties 
source ${TARGET_ENV_CONFIG_FILE} 2> /dev/null 1> /dev/null
source "${CONFIG_FILE}"

verifyAllParams

getAdminInfo

if [[ -z "${_UN}" ]]; then
  _UN="${WFPS_ADMINUSER}"
  _UP="${WFPS_ADMINPASSWORD}"
fi

# echo "User: "$_UN

getCsrfToken ${_UN} ${_UP} ${WFPS_URL_OPS}

showContents

if [[ "${_TSK}" = "false" ]] && [[ "${_PRO}" = "false" ]] && [[ "${_LAU}" = "false" ]] && [[ "${_ALL}" = "false" ]]; then
  log_error "${_CLR_RED}ERROR: add one of the following params:${_CLR_NC}"
  log_error "  -t [display task list]"
  log_error "  -p [display process list]"
  log_error "  -l [display launchable entities]"
  log_error "  -a [display all]"
  exit 1
fi