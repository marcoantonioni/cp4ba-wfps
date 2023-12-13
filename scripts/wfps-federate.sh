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
  exit
fi

export CONFIG_FILE=${_CFG}

source ./oc-utils.sh

#--------------------------------------------------------
deployWfPSRuntimeWithCerts () {
cat <<EOF | oc create -f -
apiVersion: icp4a.ibm.com/v1
kind: WfPSRuntime
metadata:
  name: ${WFPS_NAME}
  namespace: ${WFPS_NAMESPACE}
spec:
  admin:
    username: ${WFPS_ADMINUSER}
  license:
    accept: true
  capabilities: 
    federate:
      enable: ${WFPS_FEDERATE}
    ${_TAG_ES}
  persistent:
    storageClassName: ${WFPS_STORAGE_CLASS}
  tls:
    serverTrustCertificateList: $1
  appVersion: ${WFPS_APP_VER}
  image:
    imagePullPolicy: IfNotPresent
    repository: cp.icr.io/cp/cp4a/workflow-ps/workflow-ps-server
    tag: ${WFPS_APP_TAG}
  deploymentLicense: production
  node:
    resources:
      limits:
        cpu: ${WFPS_LIMITS_CPU}
        memory: ${WFPS_LIMITS_MEMORY}
      requests:
        cpu: ${WFPS_REQS_CPU}
        memory: ${WFPS_REQS_MEMORY}
EOF

}
#--------------------------------------------------------
deployWfPSRuntimeWithoutCerts () {
cat <<EOF | oc create -f -
apiVersion: icp4a.ibm.com/v1
kind: WfPSRuntime
metadata:
  name: ${WFPS_NAME}
  namespace: ${WFPS_NAMESPACE}
spec:
  admin:
    username: ${WFPS_ADMINUSER}
  license:
    accept: true
  capabilities: 
    federate:
      enable: ${WFPS_FEDERATE}
    ${_TAG_ES}
  persistent:
    storageClassName: ${WFPS_STORAGE_CLASS}
  appVersion: ${WFPS_APP_VER}
  image:
    imagePullPolicy: IfNotPresent
    repository: cp.icr.io/cp/cp4a/workflow-ps/workflow-ps-server
    tag: ${WFPS_APP_TAG}
  deploymentLicense: production
  node:
    resources:
      limits:
        cpu: ${WFPS_LIMITS_CPU}
        memory: ${WFPS_LIMITS_MEMORY}
      requests:
        cpu: ${WFPS_REQS_CPU}
        memory: ${WFPS_REQS_MEMORY}
EOF

}
#--------------------------------------------------------
federateWfPSServer () {

  if [[ -z "${WFPS_FEDERATE}" ]]; then
    WFPS_FEDERATE=false
  fi
  
  oc patch -n ${WFPS_NAMESPACE} wfps ${WFPS_NAME} --type='merge' -p '{"spec": {"capabilities":{"federate":{"enable": '${WFPS_FEDERATE}'}}}}'
  oc patch -n ${WFPS_NAMESPACE} wfps ${WFPS_NAME} --type='merge' -p '{"spec": {"capabilities":{"fullTextSearch":{"enable": '${WFPS_FEDERATE_TEXTSEARCH}',"esStorage":{"storageClassName":"'${WFPS_STORAGE_CLASS_BLOCK}'","size":"'${WFPS_FEDERATE_TEXTSEARCH_SIZE}'"},"esSnapshotStorage":{"storageClassName":"'${WFPS_STORAGE_CLASS_BLOCK}'","size":"'${WFPS_FEDERATE_TEXTSEARCHSIZE_SNAP}'"}}}}}'

}

#==========================================
echo ""
echo "**********************************************"
echo "****** WfPS Federate Runtime Deployment ******"
echo "**********************************************"
echo "Using config file: "${CONFIG_FILE}

source ${CONFIG_FILE}

verifyAllParams

storageClassExist ${WFPS_STORAGE_CLASS}
if [ $? -eq 0 ]; then
    echo "ERROR: Storage class not found"
    exit
fi

resourceExist ${WFPS_NAMESPACE} wfps ${WFPS_NAME}
if [ $? -eq 1 ]; then
  echo "Ready to federate..."
  getAdminInfo true
  if [[ -z "${WFPS_ADMINUSER}" ]]; then
    WFPS_ADMINUSER=cpadmin
  fi
  federateWfPSServer
else
  echo ERROR, ${WFPS_NAME}" not found"
fi

exit 0
