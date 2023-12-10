#!/bin/bash

_me=$(basename "$0")

#--------------------------------------------------------
# read command line params
while getopts c:t: flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        t) _TRUST=${OPTARG};;
    esac
done

if [[ -z "${_CFG}" ]]; then
  echo "usage: $_me -c path-of-config-file -t [optional]path-of-trusted-certs-config-file"
  exit
fi

export CONFIG_FILE=${_CFG}
if [[ ! -z "${_TRUST}" ]]; then
  export TRUST_CERTS_FILE=${_TRUST}
fi

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
deployWfPSRuntime () {

  if [[ ! -z "${TRUST_CERTS_FILE}" ]]; then
    CERTS_LIST=""
    for i in {1..10}
    do
      _CRT="TCERT_SECRET_NAME_"$i
      if [[ ! -z "${!_CRT}" ]]; then
        if [[ -z "${CERTS_LIST}" ]]; then
          CERTS_LIST="["
        fi
        CERTS_LIST=${CERTS_LIST}"${!_CRT},"
      fi
    done
    if [[ ! -z "${CERTS_LIST}" ]]; then
      CERTS_LIST=${CERTS_LIST}"]"
    fi
  fi

  if [[ -z "${CERTS_LIST}" ]]; then
    deployWfPSRuntimeWithoutCerts
  else
    deployWfPSRuntimeWithCerts ${CERTS_LIST}
  fi

}

#==========================================
echo ""
echo "*************************************"
echo "****** WfPS Runtime Deployment ******"
echo "*************************************"
echo "Using config file: "${CONFIG_FILE}

source ${CONFIG_FILE}
if [[ ! -z "${TRUST_CERTS_FILE}" ]]; then
  source ${TRUST_CERTS_FILE}
fi

verifyAllParams

storageClassExist ${WFPS_STORAGE_CLASS}
if [ $? -eq 0 ]; then
    echo "ERROR: Storage class not found"
    exit
fi

resourceExist ${WFPS_NAMESPACE} wfps ${WFPS_NAME}
if [ $? -eq 0 ]; then
  echo "Ready to install..."
  getAdminInfo true
  if [[ -z "${WFPS_ADMINUSER}" ]]; then
    WFPS_ADMINUSER=cpadmin
  fi
  deployWfPSRuntime
  waitForResourceCreated ${WFPS_NAMESPACE} wfps ${WFPS_NAME} 5
else
  echo ${WFPS_NAME}" already installed..."
fi

waitForWfPSReady ${WFPS_NAMESPACE} ${WFPS_NAME} 5
if [ $? -eq 0 ]; then
  echo ${WFPS_NAME}" is not ready"
else
  echo ${WFPS_NAME}" is operated through the folowing URLs using '${WFPS_ADMINUSER}' credentials"
  showWfPSUrls ${WFPS_NAMESPACE} ${WFPS_NAME}
fi

exit 0
