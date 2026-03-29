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
  echo "usage: $_me -c path-of-config-file -e target-environment-config-file -t [display task list] -p [display process list] -l [display launchable entities] -a [display all]"
  exit 1
fi

export CONFIG_FILE=${_CFG}
export TARGET_ENV_CONFIG_FILE=${_ENV_CFG}

_SCRIPT_PATH="${BASH_SOURCE}"
while [ -L "${_SCRIPT_PATH}" ]; do
  _SCRIPT_DIR="$(cd -P "$(dirname "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"
  _SCRIPT_PATH="$(readlink "${_SCRIPT_PATH}")"
  [[ ${_SCRIPT_PATH} != /* ]] && _SCRIPT_PATH="${_SCRIPT_DIR}/${_SCRIPT_PATH}"
done
_SCRIPT_PATH="$(readlink -f "${_SCRIPT_PATH}")"
_SCRIPT_DIR="$(cd -P "$(dirname -- "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"

source $_SCRIPT_DIR/oc-utils.sh


#--------------------------------------------------------
showTasks () {
  echo "--------------------------------------------------------------"
  echo -e "Task list from WFPS '${_CLR_YELLOW}${WFPS_NAME}${_CLR_NC}'"
  _CRED="-u ${_UN}:${_UP}"
  _DATA='{"size":0,"id":0,"name":"","fields":[],"organization":"byTask","shared":false,"teams":[],"interaction":"claimed_and_available","conditions":[],"sort":[],"aliases":[]}'
  RESPONSE=$(curl -sk ${_CRED} -H "BPMCSRFToken: "${WFPS_CSRF_TOKEN} -H 'accept: application/json' -X PUT "${WFPS_EXTERNAL_BASE_URL}/rest/bpm/federated/v1/tasks?calcStats=true&usersFullName=true&size=0" -d $_DATA)

  if [[ "${RESPONSE}" == *"401"* ]] || [[ "${RESPONSE}" == *"403"* ]] || [[ "${RESPONSE}" == *"errorMessage"* ]]; then
    echo -e "${_CLR_RED}ERROR${_CLR_NC}"
    echo "${RESPONSE}"
    exit 1
  else
    echo ${RESPONSE} | jq .items
    _NUM_TASKS=$(echo $RESPONSE | jq .size)
    echo "Total tasks: "${_NUM_TASKS}
  fi
}

#--------------------------------------------------------
showProcesses () {
  echo "--------------------------------------------------------------"
  echo -e "Process list from WFPS '${_CLR_YELLOW}${WFPS_NAME}${_CLR_NC}'"

  _CRED="-u ${_UN}:${_UP}"
  RESPONSE=$(curl -sk ${_CRED} -X 'PUT' ${WFPS_EXTERNAL_BASE_URL}/rest/bpm/federated/v1/instances \
      -H 'accept: application/json' -H 'Content-Type: application/json' -H "BPMCSRFToken: "${WFPS_CSRF_TOKEN} \
      -d '{ "shared": true, "teams": [ ], "interaction": "all", "size": 25, "name": "MySavedSearch", "sort": [ { "field": "instanceDueDate", "order": "ASC" } ], "conditions": [ ], "fields": [ "instanceDueDate", "instanceName", "instanceId", "instanceStatus", "instanceProcessApp", "instanceSnapshot", "bpdName" ]}')

  if [[ "${RESPONSE}" == *"401"* ]] || [[ "${RESPONSE}" == *"403"* ]] || [[ "${RESPONSE}" == *"errorMessage"* ]]; then
    echo -e "${_CLR_RED}ERROR${_CLR_NC}"
    echo "${RESPONSE}"
    exit 1
  else
    echo ${RESPONSE} | jq .items
    _NUM_PROCESSES=$(echo $RESPONSE | jq .size)
    echo "Total processes: "${_NUM_PROCESSES}
  fi
}

#--------------------------------------------------------
showLaunchableEntities () {
  echo "--------------------------------------------------------------"
  echo -e "Launchable entities from WFPS '${_CLR_YELLOW}${WFPS_NAME}${_CLR_NC}'"

  _CRED="-u ${_UN}:${_UP}"
  RESPONSE=$(curl -sk ${_CRED} -H "BPMCSRFToken: ${WFPS_CSRF_TOKEN}" -H 'accept: application/json'  -X GET "${WFPS_EXTERNAL_BASE_URL}/rest/bpm/federated/v1/launchableEntities")

  if [[ "${RESPONSE}" == *"401"* ]] || [[ "${RESPONSE}" == *"403"* ]] || [[ "${RESPONSE}" == *"errorMessage"* ]]; then
    echo -e "${_CLR_RED}ERROR${_CLR_NC}"
    echo "${RESPONSE}"
    exit 1
  else
    echo ${RESPONSE} | jq .items
    _NUM_ENTS=$(echo ${RESPONSE} | jq '.items | length')
    echo "Total launchable entities: "${_NUM_ENTS}
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
  echo ""
}

#==========================================
echo ""
echo "****************************************"
echo -e "**** ${_CLR_YELLOW}WFPS Show Federated Contents${_CLR_NC} ******"
echo "****************************************"
echo -e "Using config file '${_CLR_YELLOW}${CONFIG_FILE}${_CLR_NC}'"

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
  echo -e "${_CLR_RED}ERROR: add one of the following params:${_CLR_NC}"
  echo "  -t [display task list]"
  echo "  -p [display process list]"
  echo "  -l [display launchable entities]"
  echo "  -a [display all]"
  exit 1
fi