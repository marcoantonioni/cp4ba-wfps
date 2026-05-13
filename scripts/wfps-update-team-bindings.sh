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

_ENV_CFG=""

#--------------------------------------------------------
# read command line params
while getopts c:e:t:r flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        e) _ENV_CFG=${OPTARG};;
        t) _TB=${OPTARG};;
        r) _REMOVE=true
    esac
done

usage () {
  log_msg "${_CLR_GREEN}usage: $_me
    -c full-path-to-wfps-config-file 
       (eg: '../configs/env1.properties')
    -e full-path-to-target-environment-config-file 
    -t path-of-team-bindings-config-file${_CLR_NC}"
}

if [[ -z "${_CFG}" || -z "${_ENV_CFG}" || -z "${_TB}" ]]; then
  usage
  exit 1
fi
if [[ ! -f "${_TB}" ]]; then
  log_error "${_CLR_RED}ERROR file not found '${_CLR_YELLOW}${_TB}${_CLR_NC}'"
  exit 1
fi

export CONFIG_FILE=${_CFG}
export TARGET_ENV_CONFIG_FILE=${_ENV_CFG}
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
    log_info "${_CLR_GREEN}Updating team binding '${_CLR_YELLOW}${TB_NAME}${_CLR_NC}' for '${_CLR_YELLOW}${TB_WHAT}${_CLR_GREEN}' operation"
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
      log_error "${_CLR_RED}ERROR configuring '${_CLR_YELLOW}${TB_NAME}${_CLR_RED}' details:"
      echo "${UPD_RESPONSE}"
      exit 1
    fi
  fi
}

#--------------------------------------------------------------
# remove content of TB
removeTBContent () {
  TB_NAME=$1

  log_info "${_CLR_GREEN}Removing content from TeamBinding '${_CLR_YELLOW}${TB_NAME}${_CLR_GREEN}'"

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
    log_error "${_CLR_RED}ERROR configuring '${_CLR_YELLOW}${TB_NAME}${_CLR_RED}' details:${_CLR_NC}"
    echo "${TB_RESPONSE}"
    exit 1
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
      log_info "${_CLR_GREEN}--------------------------"
      log_info "${_CLR_GREEN}Working on TeamBinding '${_CLR_YELLOW}${!_TB_NAME}${_CLR_GREEN}'"

      if [ "${_REMOVE}" = true ]; then
        removeTBContent ${!_TB_NAME}
      fi  

      updateTB "add_users" ${!_TB_NAME} ${!_TB_USERS}
      updateTB "add_groups" ${!_TB_NAME} ${!_TB_GROUPS}
      updateTB "add_manager" ${!_TB_NAME} "${!_TB_MGR_GROUP}"
    fi
  done
}

#--------------------------------------------------------

#==========================================
log_info "${_CLR_GREEN}*************************************"
log_info "${_CLR_GREEN}***** ${_CLR_YELLOW}WfPS Team Bindings Update${_CLR_GREEN} *****"
log_info "${_CLR_GREEN}*************************************"
log_info "${_CLR_GREEN}Using config file '${_CLR_YELLOW}${CONFIG_FILE}${_CLR_GREEN}'"
log_info "${_CLR_GREEN}Using team bindings file '${_CLR_YELLOW}${TEAM_BINDINGS_FILE}${_CLR_GREEN}'"

# Read target environment configuration, ignore error for IDP/LDAP configuration properties 
source ${TARGET_ENV_CONFIG_FILE} 2> /dev/null 1> /dev/null
source ${CONFIG_FILE}
source ${TEAM_BINDINGS_FILE}

log_info "${_CLR_GREEN}Working on acronym '${_CLR_YELLOW}${WFPS_TB_APP_ACRONYM}${_CLR_NC}' snapshot '${_CLR_YELLOW}${WFPS_TB_SNAP_NAME}${_CLR_GREEN}'"

verifyAllParams
updateTeamBindings

