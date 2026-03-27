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
_INST_TMP_FOLDER="/tmp"
setTemporaryFolder () {
  _OK=0
  _ERR_MSG_FOLDER="is a folder"
  _ERR_MSG_PERMISSIONS=""
  if [[ ! -z "${CP4BA_INST_TMP_FOLDER}" ]]; then
    if [[ -d "${CP4BA_INST_TMP_FOLDER}" ]]; then
      if [[ -r "${CP4BA_INST_TMP_FOLDER}" ]] && [[ -w "${CP4BA_INST_TMP_FOLDER}" ]]; then 
        _OK=1
      else
        _ERR_MSG_PERMISSIONS=", you have not rights to read and/or write"
        _OK=-1
      fi
    else
      _ERR_MSG_FOLDER="is NOT a folder"
    fi

    if [[ $_OK -lt 1 ]]; then
      echo -e "${_CLR_RED}[✗] ERROR '${_CLR_YELLOW}${CP4BA_INST_TMP_FOLDER}${_CLR_RED}' is not a valid temporary folder, check if it is a folder or if you have write permissions !${_CLR_NC}"
      echo -e "${_CLR_RED}'${_CLR_YELLOW}${CP4BA_INST_TMP_FOLDER}${_CLR_RED}' ${_ERR_MSG_FOLDER}${_ERR_MSG_PERMISSIONS}${_CLR_NC}"
      exit 1
    fi
    export _INST_TMP_FOLDER="${CP4BA_INST_TMP_FOLDER}"
  fi
  echo -e "${_CLR_GREEN}Running with temporary folder '${_CLR_YELLOW}${_INST_TMP_FOLDER}${_CLR_GREEN}'${_CLR_NC}"

}

#--------------------------------------------------------
# read command line params
while getopts c:e: flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        e) _ENV_CFG=${OPTARG};;
    esac
done

usage () {
  echo "usage: $_me -c path-of-config-file -e full-path-to-target-environment-config-file"
  exit 1
}

if [[ -z "${_CFG}" ]] || [[ -z "${_ENV_CFG}" ]]; then
  usage
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

__workaround () {
  _HOST=$(oc get route cpd -o jsonpath='{.spec.host}') 1>/dev/null
  _PATCH_FILE="${_INST_TMP_FOLDER}/wfps-patch-$RANDOM.yaml"
  _PROPS='<properties> 
          <server merge="mergeChildren">
            <portal merge="mergeChildren">
              <bpm-data-endpoint merge="replace">'${_HOST}':443/'${WFPS_NAME}'-wfps/rest/bpm/federated</bpm-data-endpoint>
              <federated-dashboards-endpoint merge="replace">'${_HOST}':443/'${WFPS_NAME}'-wfps/rest/bpm/federated</federated-dashboards-endpoint>
            </portal>
          </server>
        </properties>'
  _CUSTOMIZE="
spec:
  node:
    customize:
      lombardiXML: |-
        "${_PROPS}

  echo -e "$_CUSTOMIZE" > $_PATCH_FILE
  oc patch -n ${WFPS_NAMESPACE} wfps ${WFPS_NAME} --type='merge' --patch-file ${_PATCH_FILE} 1>/dev/null
  rm $_PATCH_FILE

}
#--------------------------------------------------------
federateWfPSServer () {

  if [[ -z "${WFPS_FEDERATE}" ]]; then
    WFPS_FEDERATE=false
  fi
  if [[ "${WFPS_FEDERATE}" = "true" ]]; then
    echo "Federate ${WFPS_NAME}..."
  else
    echo "Unfederate ${WFPS_NAME}..."
  fi
  
  if [[ -z "${WFPS_NAME}" ]] || [[ -z "${WFPS_FEDERATE}" ]] || [[ -z "${WFPS_FEDERATE_TEXTSEARCH}" ]] || 
    [[ -z "${WFPS_FEDERATE_TEXTSEARCH_SIZE}" ]] || [[ -z "${WFPS_FEDERATE_TEXTSEARCHSIZE_SNAP}" ]]; then
      echo "Error, some vars WFPS_... not set."
      exit 1
  fi

  oc patch -n ${WFPS_NAMESPACE} wfps ${WFPS_NAME} --type='merge' -p '{"spec": {"capabilities":{"federate":{"enable": '${WFPS_FEDERATE}'}}}}' 1>/dev/null
  oc patch -n ${WFPS_NAMESPACE} wfps ${WFPS_NAME} --type='merge' -p '{"spec": {"capabilities":{"fullTextSearch":{"enable": '${WFPS_FEDERATE_TEXTSEARCH}',"esStorage":{"storageClassName":"'${WFPS_STORAGE_CLASS_BLOCK}'","size":"'${WFPS_FEDERATE_TEXTSEARCH_SIZE}'"},"esSnapshotStorage":{"storageClassName":"'${WFPS_STORAGE_CLASS_BLOCK}'","size":"'${WFPS_FEDERATE_TEXTSEARCHSIZE_SNAP}'"}}}}}' 1>/dev/null

  if [[ "${WFPS_FEDERATE}" = "true" ]]; then
    __workaround
  fi
}

#==========================================
echo ""
echo "**********************************************"
echo "****** WfPS Runtime Deployment Federation ****"
echo "**********************************************"
echo "Using config file: "${CONFIG_FILE}

# Read target environment configuration, ignore error for IDP/LDAP configuration properties 
source ${TARGET_ENV_CONFIG_FILE} 2> /dev/null 1> /dev/null
source ${CONFIG_FILE}

verifyAllParams

storageClassExist ${WFPS_STORAGE_CLASS}
if [ $? -eq 0 ]; then
    echo "ERROR: Storage class '${WFPS_STORAGE_CLASS}' not found"
    exit
fi

storageClassExist ${WFPS_STORAGE_CLASS_BLOCK}
if [ $? -eq 0 ]; then
    echo "ERROR: Storage class '${WFPS_STORAGE_CLASS_BLOCK}' not found"
    exit
fi

resourceExist ${WFPS_NAMESPACE} wfps ${WFPS_NAME}
if [ $? -eq 1 ]; then
  echo "Ready to federate/unfederate..."
  getAdminInfo true
  if [[ -z "${WFPS_ADMINUSER}" ]]; then
    WFPS_ADMINUSER=cpadmin
  fi
  federateWfPSServer
else
  echo ERROR, ${WFPS_NAME}" not found"
fi

exit 0
