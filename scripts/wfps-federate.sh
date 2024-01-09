#!/bin/bash

_me=$(basename "$0")


#--------------------------------------------------------
# read command line params
while getopts c:f: flag
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

source ./oc-utils.sh

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

}

#==========================================
echo ""
echo "**********************************************"
echo "****** WfPS Runtime Deployment Federation ****"
echo "**********************************************"
echo "Using config file: "${CONFIG_FILE}

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
