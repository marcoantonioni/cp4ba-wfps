#!/bin/bash

_me=$(basename "$0")

#--------------------------------------------------------
# read command line params
while getopts c:t:r flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        t) _TB=${OPTARG};;
        r) _REMOVE=true
    esac
done

if [[ -z "${_CFG}" ]]; then
  echo "usage: $_me -c path-of-config-file -t path-of-team-bindings-config-file"
  exit 1
fi
if [[ -z "${_TB}" ]]; then
  echo "usage: $_me -c path-of-config-file -t path-of-team-bindings-config-file"
  exit 
fi
if [[ ! -f "${_TB}" ]]; then
  echo "ERROR: file not found: ${_TB}"
  exit 1
fi

export CONFIG_FILE=${_CFG}
export TEAM_BINDINGS_FILE=${_TB}

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
# update team binding
updateTB () {

  TB_WHAT=$1
  TB_NAME=$2
  TB_CONTENT=$3
  _CONTENT_TO_SET=""

  if [[ "${TB_WHAT}" != "add_manager" ]]; then
    if [[ ! -z "${TB_CONTENT}" ]]; then
      IFS=$','
      read -a ITEMS <<< "${TB_CONTENT}"
      unset IFS

      UPDATED_LIST=""
      max_len=${#ITEMS[*]}
      idx=0
      for ITEM in "${ITEMS[@]}";
      do
        FORMATTED_ITEM="\""${ITEM}"\""
        UPDATED_LIST=${UPDATED_LIST}${FORMATTED_ITEM}
        idx=$((idx+1))
        if [[ $idx < $max_len ]]; then
          UPDATED_LIST=${UPDATED_LIST}","
        fi
      done
      _CONTENT_TO_SET=${UPDATED_LIST}
    fi
  else
    _CONTENT_TO_SET="\""${TB_CONTENT}"\""
  fi

  if [[ ! -z "${_CONTENT_TO_SET}" ]]; then
    echo -n "Updating team binding '${TB_NAME}' for '${TB_WHAT}' operation ..."
    _URI="/std/bpm/containers/${WFPS_TB_APP_ACRONYM}/versions/${WFPS_TB_SNAP_NAME}/team_bindings/${TB_NAME}"

    if [[ "${TB_WHAT}" = "add_manager" ]]; then
      # single item
      _DATA='{"'${TB_WHAT}'": '${_CONTENT_TO_SET}',"set_auto_refresh_enabled": true}'
    else
      # list of items
      _DATA='{"'${TB_WHAT}'": ['${_CONTENT_TO_SET}'],"set_auto_refresh_enabled": true}'
    fi

    CRED="-u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD}"
    UPD_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -H 'Content-Type: application/json' -d "${_DATA}" -X POST ${WFPS_URL_OPS}/${_URI})
    
    if [[ "${UPD_RESPONSE}" == *"error_"* ]]; then
      echo ""
      echo "ERROR configuring '${TB_NAME}' details:"
      echo "${UPD_RESPONSE}"
      echo
      exit
    else
      echo " configured !"
    fi
  fi
}

#--------------------------------------------------------------
# remove content of TB
removeTBContent () {
  TB_NAME=$1

  echo -n "Removing content from TeamBinding: "${TB_NAME}" ..."

  _URI="/std/bpm/containers/${WFPS_TB_APP_ACRONYM}/versions/${WFPS_TB_SNAP_NAME}/team_bindings"
  CRED="-u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD}"
  TB_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -H 'Content-Type: application/json' -X GET ${WFPS_URL_OPS}/${_URI})

  TB_CONTENT=$(echo "${TB_RESPONSE}" | jq -r '.team_bindings[] | select(.name=="'${TB_NAME}'")')
  TB_CONTENT_USERS=$(echo "${TB_CONTENT}" | jq .user_members)
  TB_CONTENT_GROUPS=$(echo "${TB_CONTENT}" | jq .group_members)
  TB_CONTENT_MGR=$(echo "${TB_CONTENT}" | jq .manager_name)

  if [[ "${TB_CONTENT_MGR}" = "null" ]]; then
    TB_CONTENT_MGR="\"\""
  fi

  _DATA='{
  "remove_users": '${TB_CONTENT_USERS}',
  "remove_groups": '${TB_CONTENT_GROUPS}',
  "remove_manager": '${TB_CONTENT_MGR}',
  "set_auto_refresh_enabled": true
  }'

  _URI="/std/bpm/containers/${WFPS_TB_APP_ACRONYM}/versions/${WFPS_TB_SNAP_NAME}/team_bindings/${TB_NAME}"
  CRED="-u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD}"
  TB_RESPONSE=$(curl -sk ${CRED} -H 'accept: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -H 'Content-Type: application/json' -d "${_DATA}" -X DELETE ${WFPS_URL_OPS}/${_URI})

  if [[ "${TB_RESPONSE}" == *"error_"* ]]; then
    echo ""
    echo "ERROR configuring '${TB_NAME}' details:"
    echo "${TB_RESPONSE}"
    echo
    exit
  else
    echo " done !"
  fi

}

#--------------------------------------------------------------
# update team bindings
updateTeamBindings () {
  getAdminInfo

  if [[ -z "${WFPS_ADMINUSER}" ]]; then
    WFPS_ADMINUSER=cpadmin
  fi
  getCsrfToken ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS}

  for i in {1..10}
  do
    _TB_NAME="WFPS_TB_NAME_"$i
    _TB_USERS="WFPS_TB_NAME_"$i"_USERS"
    _TB_GROUPS="WFPS_TB_NAME_"$i"_GROUPS"
    _TB_MGR_GROUP="WFPS_TB_NAME_"$i"_MGR_GROUP"

    if [[ ! -z "${!_TB_NAME}" ]]; then
      echo "---------------------"
      echo "Working on TeamBinding: "${!_TB_NAME}

      if [ "${_REMOVE}" = true ]; then
        removeTBContent ${!_TB_NAME}
      fi  

      updateTB "add_users" ${!_TB_NAME} ${!_TB_USERS}
      updateTB "add_groups" ${!_TB_NAME} ${!_TB_GROUPS}
      updateTB "add_manager" ${!_TB_NAME} "${!_TB_MGR_GROUP}"
    fi
  done

  echo ""
}

#--------------------------------------------------------

#==========================================
echo ""
echo "*************************************"
echo "***** WfPS Team Bindings Update *****"
echo "*************************************"
echo "Using config file: "${CONFIG_FILE}
echo "Using team bindings file: "${TEAM_BINDINGS_FILE}

source ${CONFIG_FILE}
source ${TEAM_BINDINGS_FILE}

echo ""
echo "Working on acronym ["${WFPS_TB_APP_ACRONYM}"] snapshot["${WFPS_TB_SNAP_NAME}"]"
echo ""

verifyAllParams
updateTeamBindings

