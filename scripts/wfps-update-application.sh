#!/bin/bash

_me=$(basename "$0")

_APP=""
_BRANCH=""
_STATE="activate"
_DEFAULT=false
_FORCE=false
_SUSPEND_INSTANCES=false

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
    -s activate|deactivate
    -h (optional) suspend-instances (used with: '-s deactivate')
    -f (optional) force-suspend (used with: '-s deactivate')
    -d (optional) make-snapshot-default${_CLR_NC}"
}

#--------------------------------------------------------
# read command line params
while getopts c:a:b:s:dfrh flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        a) _APP=${OPTARG};;
        b) _BRANCH=${OPTARG};;
        s) _STATE=${OPTARG};;
        d) _DEFAULT=true;;
        f) _FORCE=true;;
        h) _SUSPEND_INSTANCES=true;;
    esac
done

if [[ -z "${_CFG}" ]] || [[ -z "${_APP}" ]] || [[ -z "${_BRANCH}" ]]; then
  usage
  exit 1
fi

if [[ ! -f "${_CFG}" ]]; then
  echo "Configuration file not found: "${_CFG}
    usage
  exit 1
fi

source ${_CFG}

_SCRIPT_PATH="${BASH_SOURCE}"
while [ -L "${_SCRIPT_PATH}" ]; do
  _SCRIPT_DIR="$(cd -P "$(dirname "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"
  _SCRIPT_PATH="$(readlink "${_SCRIPT_PATH}")"
  [[ ${_SCRIPT_PATH} != /* ]] && _SCRIPT_PATH="${_SCRIPT_DIR}/${_SCRIPT_PATH}"
done
_SCRIPT_PATH="$(readlink -f "${_SCRIPT_PATH}")"
_SCRIPT_DIR="$(cd -P "$(dirname -- "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"

source $_SCRIPT_DIR/oc-utils.sh

#--------------------------------------------------------------
# 
updateApplication () {

  if [[ -z "${WFPS_ADMINUSER}" ]]; then
    WFPS_ADMINUSER=cpadmin
  fi
  getCsrfToken ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS}

  _EXTRA_PARAMS=""
  if [[ "${_STATE}" = "deactivate" ]]; then
    _EXTRA_PARAMS="?force=${_FORCE}&suspend_bpd_instances=${_SUSPEND_INSTANCES}"
  fi

  _URI="/std/bpm/containers/${_APP}/versions/${_BRANCH}/${_STATE}${_EXTRA_PARAMS}"
  CRED="-u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD}"
  UPD_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_URL_OPS}/${_URI})

  if [[ "${UPD_RESPONSE}" == *"error_"* ]]; then
    echo ""
    echo "ERROR configuring '${_APP}/${_BRANCH}' details:"
    echo "${UPD_RESPONSE}" | jq .
    echo
    exit 1
  fi

  if [[ "${_STATE}" = "activate" ]]; then
    if [[ "${_DEFAULT}" = "true" ]]; then    
      _URI="/std/bpm/containers/${_APP}/versions/${_BRANCH}/make_default"
      UPD_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_URL_OPS}/${_URI})
      if [[ "${UPD_RESPONSE}" == *"error_"* ]]; then
        echo ""
        echo "ERROR making default '${_APP}/${_BRANCH}' details:"
        echo "${UPD_RESPONSE}" | jq .
        echo
        exit 1
      fi
    fi
  fi
  echo " configured !"
}

#--------------------------------------------------------

#==========================================
echo ""
echo "***********************************"
echo "***** WfPS Update Application *****"
echo "***********************************"
echo "Using config file: "${_CFG}


echo ""

verifyAllParams
echo -n "Working on application acronym ["${_APP}"] branch ["${_BRANCH}"]... "
getAdminInfo
updateApplication
exit 0
