#!/bin/bash

#set -euo pipefail


_me=$(basename "$0")

_ENV_CFG=""

#--------------------------------------------------------
_CLR_RED="\033[0;31m"   #'0;31' is Red's ANSI color code
_CLR_GREEN="\033[0;32m"   #'0;32' is Green's ANSI color code
_CLR_YELLOW="\033[1;33m"   #'1;32' is Yellow's ANSI color code
_CLR_BLUE="\033[0;34m"   #'0;34' is Blue's ANSI color code
_CLR_NC="\033[0m"

#--------------------------------------------------------
# read command line params
while getopts c:e: flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        e) _ENV_CFG=${OPTARG};;
    esac
done


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
  log_msg "usage: $_me -c path-of-config-file -e full-path-to-target-environment-config-file"
  exit 1
}

if [[ -z "${_CFG}" ]] || [[ -z "${_ENV_CFG}" ]]; then
  usage
fi

export CONFIG_FILE=${_CFG}
export TARGET_ENV_CONFIG_FILE=${_ENV_CFG}

source $_SCRIPT_DIR/oc-utils.sh

# Read target environment configuration, ignore error for IDP/LDAP configuration properties 
source ${TARGET_ENV_CONFIG_FILE} 2> /dev/null 1> /dev/null
source ${CONFIG_FILE}

verifyAllParams

log_info "${_CLR_GREEN}Exporting infos for '${_CLR_YELLOW}${WFPS_NAME}${_CLR_GREEN}', please wait for server ready..."
getAdminInfo
getWfPSUrls ${WFPS_NAMESPACE} ${WFPS_NAME}
getCsrfToken ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS}

mkdir -p $_SCRIPT_DIR/../output
OUT_FILE=$_SCRIPT_DIR/../output/exp-${WFPS_NAME}.vars
log_info "${_CLR_GREEN}Generating env vars in file '${_CLR_YELLOW}${OUT_FILE}${_CLR_GREEN}'${_CLR_NC}"
echo "export WFPS_NAME=${WFPS_NAME}" > ${OUT_FILE}
echo "export WFPS_NAMESPACE=${WFPS_NAMESPACE}" >> ${OUT_FILE}
echo "export WFPS_ADMINUSER=${WFPS_ADMINUSER}" >> ${OUT_FILE}
echo "export WFPS_ADMINPASSWORD=${WFPS_ADMINPASSWORD}" >> ${OUT_FILE}
echo "export WFPS_URL_OPS=${WFPS_URL_OPS}" >> ${OUT_FILE}
echo "export WFPS_EXTERNAL_BASE_URL=${WFPS_EXTERNAL_BASE_URL}" >> ${OUT_FILE}
echo "export WFPS_URL_EXPLORER=${WFPS_URL_EXPLORER}" >> ${OUT_FILE}
echo "export WFPS_URL_WORKPLACE=${WFPS_URL_WORKPLACE}" >> ${OUT_FILE}
echo "export WFPS_URL_PROCESSADMIN=${WFPS_URL_PROCESSADMIN}" >> ${OUT_FILE}
echo "export WFPS_CSRF_TOKEN=${WFPS_CSRF_TOKEN}" >> ${OUT_FILE}
echo "export WFPS_PAK_BASE_URL=${WFPS_PAK_BASE_URL}" >> ${OUT_FILE}
log_info "${_CLR_GREEN}Env vars for '${_CLR_YELLOW}${WFPS_NAME}${_CLR_GREEN}' in file '${_CLR_YELLOW}${OUT_FILE}${_CLR_GREEN}'"
cat ${OUT_FILE} | sed 's/export //g'

