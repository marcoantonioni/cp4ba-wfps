#!/bin/bash

_me=$(basename "$0")

#--------------------------------------------------------
# read command line params
while getopts c: flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
    esac
done

if [[ -z "${_CFG}" ]]; then
  echo "usage: $_me -c path-of-config-file"
  exit 1
fi

export CONFIG_FILE=${_CFG}

_SCRIPT_PATH="${BASH_SOURCE}"
while [ -L "${_SCRIPT_PATH}" ]; do
  _SCRIPT_DIR="$(cd -P "$(dirname "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"
  _SCRIPT_PATH="$(readlink "${_SCRIPT_PATH}")"
  [[ ${_SCRIPT_PATH} != /* ]] && _SCRIPT_PATH="${_SCRIPT_DIR}/${_SCRIPT_PATH}"
done
_SCRIPT_PATH="$(readlink -f "${_SCRIPT_PATH}")"
_SCRIPT_DIR="$(cd -P "$(dirname -- "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"

source $_SCRIPT_DIR/oc-utils.sh

source ${CONFIG_FILE}

verifyAllParams

echo "Exporting infos for '${WFPS_NAME}', please wait for server ready..."
getAdminInfo
getWfPSUrls ${WFPS_NAMESPACE} ${WFPS_NAME}
getCsrfToken ${WFPS_ADMINUSER} ${WFPS_ADMINPASSWORD} ${WFPS_URL_OPS}

OUT_FILE=./exp-${WFPS_NAME}.vars
echo "Generating env vars in file: "${OUT_FILE}
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
echo "Env vars for [${WFPS_NAME}] in file "${OUT_FILE}
echo ""
cat ${OUT_FILE}

