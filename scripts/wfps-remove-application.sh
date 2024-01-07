#!/bin/bash

_me=$(basename "$0")

_APP=""
_BRANCH=""
_FORCE=false

#--------------------------------------------------------
_CLR_RED="\033[0;31m"   #'0;31' is Red's ANSI color code
_CLR_GREEN="\033[0;32m"   #'0;32' is Green's ANSI color code
_CLR_YELLOW="\033[1;32m"   #'1;32' is Yellow's ANSI color code
_CLR_BLUE="\033[0;34m"   #'0;34' is Blue's ANSI color code
_CLR_NC="\033[0m"

usage () {
  echo ""
  echo -e "${_CLR_GREEN}usage: $_me
    -c full-path-to-config-file
       (eg: '../configs/wfps1.properties')
    -a app-acronym
    -b branch-name 
    -f (optional) force-suspend (used with: '-s deactivate' and '-r' )${_CLR_NC}"
}

#--------------------------------------------------------
# read command line params
while getopts c:a:b:f flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        a) _APP=${OPTARG};;
        b) _BRANCH=${OPTARG};;
        f) _FORCE=true;;
    esac
done

if [[ -z "${_CFG}" ]] || [[ -z "${_APP}" ]] || [[ -z "${_BRANCH}" ]]; then
  usage
  exit
fi

if [[ ! -f "${_CFG}" ]]; then
  echo "Configuration file not found: "${_CFG}
    usage
  exit 1
fi

source ${_CFG}

source ./oc-utils.sh

removeApplication () {
  if [[ -z "${WFPS_ADMINUSER}" ]]; then
    WFPS_ADMINUSER=cpadmin
  fi
  getCsrfToken ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS}
  _URI="/std/bpm/containers/${_APP}/versions?versions=${_BRANCH}&force=${_FORCE}"
  CRED="-u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD}"
  REMOVE_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X DELETE ${WFPS_URL_OPS}/${_URI})

  if [[ "${REMOVE_RESPONSE}" == *"error_"* ]]; then
    echo ""
    echo "ERROR deleting '${_APP}/${_BRANCH}' details:"
    echo "${REMOVE_RESPONSE}" | jq .
    echo
    exit 1
  fi

  REMOVE_DESCR=$(echo ${REMOVE_RESPONSE} | jq .description | sed 's/"//g')
  REMOVE_URL=$(echo ${REMOVE_RESPONSE} | jq .url | sed 's/"//g')

  echo "Request result: "${REMOVE_DESCR}
  sleep 2
  echo "Get deletion status at url: "${REMOVE_URL}
  while [ true ]
  do
    echo -n "."
    REMOVE_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X GET ${REMOVE_URL})
    REMOVE_STATE=$(echo ${REMOVE_RESPONSE} | jq .state | sed 's/"//g')
    if [[ ${REMOVE_STATE} = "running" ]]; then
      sleep 5
    else
      if [[ ${REMOVE_STATE} = "failure" ]]; then
        echo ${REMOVE_RESPONSE} | jq .
      fi
      echo ""
      echo "Final deletion state: "${REMOVE_STATE}
      break
    fi
  done
}

#--------------------------------------------------------

#==========================================
echo ""
echo "***********************************"
echo "***** WfPS Remove Application *****"
echo "***********************************"
echo "Using config file: "${_CFG}


echo ""

verifyAllParams
echo -n "Working on application acronym ["${_APP}"] branch ["${_BRANCH}"]... "
getAdminInfo
removeApplication
exit 0
