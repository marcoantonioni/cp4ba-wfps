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
  exit
fi

export CONFIG_FILE=${_CFG}

source ./oc-utils.sh
source ${CONFIG_FILE}
verifyAllParams

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
echo "Env vars for [${WFPS_NAME}] in file "${OUT_FILE}
cat ${OUT_FILE}

