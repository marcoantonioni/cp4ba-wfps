#!/bin/bash

_me=$(basename "$0")

_TSK=false
_PRO=false
_LAU=false
_ALL=false

_UN=""
_UP=""

#--------------------------------------------------------
# read command line params
while getopts c:u:w:tpla flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        t) _TSK=true;;
        p) _PRO=true;;
        l) _LAU=true;;
        a) _ALL=true;;
        u) _UN=${OPTARG};;
        w) _UP=${OPTARG};;
    esac
done

if [[ "${_ALL}" = "true" ]]; then
  _TSK=true
  _PRO=true
  _LAU=true
fi

if [[ -z "${_CFG}" ]]; then
  echo "usage: $_me -c path-of-config-file -t [display task list] -p [display process list] -l [display launchable entities] -a [display all]"
  exit
fi

export CONFIG_FILE=${_CFG}

source ./oc-utils.sh


#--------------------------------------------------------
showTasks () {
  echo "--------------------------------------------------------------"
  echo "Task list from WFPS '${WFPS_NAME}'"

  _CRED="-u ${_UN}:${_UP}"
  _DATA='{"size":0,"id":0,"name":"","fields":[],"organization":"byTask","shared":false,"teams":[],"interaction":"claimed_and_available","conditions":[],"sort":[],"aliases":[]}'
  RESPONSE=$(curl -sk ${_CRED} -H "BPMCSRFToken: "${WFPS_CSRF_TOKEN} -H 'accept: application/json' -X PUT "${WFPS_EXTERNAL_BASE_URL}/rest/bpm/federated/v1/tasks?calcStats=true&usersFullName=true&size=0" -d $_DATA)

  if [[ "${RESPONSE}" == *"401"* ]] || [[ "${RESPONSE}" == *"403"* ]] || [[ "${RESPONSE}" == *"errorMessage"* ]]; then
    echo "ERROR"
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
  echo "Process list from WFPS '${WFPS_NAME}'"

  _CRED="-u ${_UN}:${_UP}"
  RESPONSE=$(curl -sk ${_CRED} -X 'PUT' ${WFPS_EXTERNAL_BASE_URL}/rest/bpm/federated/v1/instances \
      -H 'accept: application/json' -H 'Content-Type: application/json' -H "BPMCSRFToken: "${WFPS_CSRF_TOKEN} \
      -d '{ "shared": true, "teams": [ ], "interaction": "all", "size": 25, "name": "MySavedSearch", "sort": [ { "field": "instanceDueDate", "order": "ASC" } ], "conditions": [ ], "fields": [ "instanceDueDate", "instanceName", "instanceId", "instanceStatus", "instanceProcessApp", "instanceSnapshot", "bpdName" ]}')

  if [[ "${RESPONSE}" == *"401"* ]] || [[ "${RESPONSE}" == *"403"* ]] || [[ "${RESPONSE}" == *"errorMessage"* ]]; then
    echo "ERROR"
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
  echo "Launchable entities from WFPS '${WFPS_NAME}'"

  _CRED="-u ${_UN}:${_UP}"
  RESPONSE=$(curl -sk ${_CRED} -H "BPMCSRFToken: ${WFPS_CSRF_TOKEN}" -H 'accept: application/json'  -X GET "${WFPS_EXTERNAL_BASE_URL}/rest/bpm/federated/v1/launchableEntities")

  if [[ "${RESPONSE}" == *"401"* ]] || [[ "${RESPONSE}" == *"403"* ]] || [[ "${RESPONSE}" == *"errorMessage"* ]]; then
    echo "ERROR"
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
echo "****** WFPS Show Federated Contents ******"
echo "****************************************"
echo "Using config file: "${CONFIG_FILE}

source ${CONFIG_FILE}

verifyAllParams

getAdminInfo

if [[ -z "${_UN}" ]]; then
  _UN="${WFPS_ADMINUSER}"
  _UP="${WFPS_ADMINPASSWORD}"
fi

echo "User: "$_UN

getCsrfToken ${_UN} ${_UP} ${WFPS_URL_OPS}

showContents

if [[ "${_TSK}" = "false" ]] && [[ "${_PRO}" = "false" ]] && [[ "${_LAU}" = "false" ]] && [[ "${_ALL}" = "false" ]]; then
  echo "ERROR: add one of the following params:"
  echo "  -t [display task list]"
  echo "  -p [display process list]"
  echo "  -l [display launchable entities]"
  echo "  -a [display all]"
  exit 1
fi