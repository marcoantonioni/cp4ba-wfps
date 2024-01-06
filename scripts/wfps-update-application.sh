#!/bin/bash

_me=$(basename "$0")

_APP=""
_BRANCH=""
_STATE="activate"
_DEFAULT=false
#--------------------------------------------------------
# read command line params
while getopts c:a:b:s:d flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        a) _APP=${OPTARG};;
        b) _BRANCH=${OPTARG};;
        s) _STATE=${OPTARG};;
        d) _DEFAULT=true;;
    esac
done

if [[ -z "${_CFG}" ]]; then
  echo "usage: $_me -c path-of-config-file -a app-acronym -b branch -s activate|deactivate -d [optional, make default]"
  exit
fi
if [[ -z "${_APP}" ]]; then
  echo "usage: $_me -c path-of-config-file -a app-acronym -b branch -s activate|deactivate -d [optional, make default]"
  exit
fi
if [[ -z "${_BRANCH}" ]]; then
  echo "usage: $_me -c path-of-config-file -a app-acronym -b branch -s activate|deactivate -d [optional, make default]"
  exit
fi

export CONFIG_FILE=${_CFG}

source ./oc-utils.sh



#--------------------------------------------------------------
# 
updateApplication () {
  getAdminInfo

  if [[ -z "${WFPS_ADMINUSER}" ]]; then
    WFPS_ADMINUSER=cpadmin
  fi
  getCsrfToken ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS}

  _URI="/std/bpm/containers/${_APP}/versions/${_BRANCH}/${_STATE}"
  CRED="-u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD}"
  UPD_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_URL_OPS}/${_URI})

  if [[ "${UPD_RESPONSE}" == *"error_"* ]]; then
    echo ""
    echo "ERROR configuring '${_APP}/${_BRANCH}' details:"
    echo "${UPD_RESPONSE}" | jq .
    echo
    exit
  fi

  if [[ "${_DEFAULT}" = "true" ]]; then    
    _URI="/std/bpm/containers/${_APP}/versions/${_BRANCH}/make_default"
    UPD_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_URL_OPS}/${_URI})
    if [[ "${UPD_RESPONSE}" == *"error_"* ]]; then
      echo ""
      echo "ERROR making default '${_APP}/${_BRANCH}' details:"
      echo "${UPD_RESPONSE}" | jq .
      echo
      exit
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
echo "Using config file: "${CONFIG_FILE}

source ${CONFIG_FILE}

echo ""

verifyAllParams
echo -n "Working on application acronym ["${_APP}"] branch["${_BRANCH}"]... "
updateApplication

