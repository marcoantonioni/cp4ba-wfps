#!/bin/bash

_me=$(basename "$0")

_APP=""
_DETAILS=false
#--------------------------------------------------------
# read command line params
while getopts c:a:d flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        a) _APP=${OPTARG};;
        d) _DETAILS=true;;
    esac
done

if [[ -z "${_CFG}" ]]; then
  echo "usage: $_me -c path-of-config-file -a [optional] app-name -d [optional] app-details"
  exit 1
fi

export CONFIG_FILE=${_CFG}
export APPLICATION_NAME=${_APP}

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
    echo "Name, Branch, State"
    echo "-------------------"

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
echo "*************************************"
echo "*** WfPS Application Informations ***"
echo "*************************************"
echo "Using config file: "${CONFIG_FILE}

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

