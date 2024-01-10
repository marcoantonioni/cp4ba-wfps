#!/bin/bash

_me=$(basename "$0")

_NOWAIT=false
_YAML_ONLY=false
_TAG_ES=""
_TAG_FEDERATE=""
_CR_YAML=""

#--------------------------------------------------------
_CLR_RED="\033[0;31m"   #'0;31' is Red's ANSI color code
_CLR_GREEN="\033[0;32m"   #'0;32' is Green's ANSI color code
_CLR_YELLOW="\033[1;32m"   #'1;32' is Yellow's ANSI color code
_CLR_BLUE="\033[0;34m"   #'0;34' is Blue's ANSI color code
_CLR_NC="\033[0m"

usage () {
  echo ""
  echo -e "${_CLR_GREEN}usage: $_me
    -c full-path-to-config-file
       (eg: '../configs/env1.properties')
    -g(optional) generate-yaml-only
    -t(optional) path-of-trusted-certs-config-file
    -n(optional) no wait for instance readiness${_CLR_NC}"
}

#--------------------------------------------------------
# read command line params
while getopts c:t:ng flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        t) _TRUST=${OPTARG};;
        n) _NOWAIT=true;;
        g) _YAML_ONLY=true;;
    esac
done

if [[ -z "${_CFG}" ]]; then
  usage
  exit 1
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
  ${_TAG_FEDERATE}
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

#cat <<EOF | oc create -f -
#apiVersion: icp4a.ibm.com/v1
#kind: WfPSRuntime
#metadata:
#  name: ${WFPS_NAME}
#  namespace: ${WFPS_NAMESPACE}
#spec:
#  admin:
#    username: ${WFPS_ADMINUSER}
#  license:
#    accept: true
#  ${_TAG_FEDERATE}
#    ${_TAG_ES}
#  persistent:
#    storageClassName: ${WFPS_STORAGE_CLASS}
#  appVersion: ${WFPS_APP_VER}
#  image:
#    imagePullPolicy: IfNotPresent
#    repository: cp.icr.io/cp/cp4a/workflow-ps/workflow-ps-server
#    tag: ${WFPS_APP_TAG}
#  deploymentLicense: production
#  node:
#    resources:
#      limits:
#        cpu: ${WFPS_LIMITS_CPU}
#        memory: ${WFPS_LIMITS_MEMORY}
#      requests:
#        cpu: ${WFPS_REQS_CPU}
#        memory: ${WFPS_REQS_MEMORY}
#EOF

_CR_YAML="../output/${WFPS_NAME}.yaml"
cat <<EOF > ${_CR_YAML}
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
  ${_TAG_FEDERATE}
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

if [[ "${_YAML_ONLY}" = "false" ]]; then
  oc create -f ${_CR_YAML}
fi

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

  if [[ -z "${WFPS_FEDERATE}" ]]; then
    WFPS_FEDERATE=false
  fi
  
  if [[ "${WFPS_FEDERATE}" = "true" ]]; then

    _TAG_FEDERATE="capabilities: 
    federate:
      enable: ${WFPS_FEDERATE}"

    _TAG_ES="fullTextSearch:
      enable: true
      esStorage:
        storageClassName: thin-csi
        size: 10Gi
      esSnapshotStorage:
        storageClassName: thin-csi
        size: 2Gi"

  fi

  if [[ -z "${CERTS_LIST}" ]]; then
    deployWfPSRuntimeWithoutCerts
  else
    deployWfPSRuntimeWithCerts ${CERTS_LIST}
  fi

  echo "WfPS CR generated in: "${_CR_YAML}
}

#==========================================
echo ""
echo "*************************************"
echo "****** WfPS Runtime Deployment ******"
echo "*************************************"
echo "Using config file: "${CONFIG_FILE}

if [[ ! -f "${_CFG}" ]]; then
  echo "Configuration file not found: "${_CFG}
  usage
  exit 1
fi

source ${CONFIG_FILE}
if [[ ! -z "${TRUST_CERTS_FILE}" ]]; then
  source ${TRUST_CERTS_FILE}
fi

verifyAllParams

storageClassExist ${WFPS_STORAGE_CLASS}
if [ $? -eq 0 ]; then
    echo "ERROR: Storage class not found"
    exit 1
fi

resourceExist ${WFPS_NAMESPACE} wfps ${WFPS_NAME}
if [ $? -eq 0 ]; then
  echo "Ready to install..."
  getAdminInfo true
  if [[ -z "${WFPS_ADMINUSER}" ]]; then
    WFPS_ADMINUSER="cpadmin"
  fi
  deployWfPSRuntime
  waitForResourceCreated ${WFPS_NAMESPACE} wfps ${WFPS_NAME} 5
else
  echo ${WFPS_NAME}" already installed..."
  if [[ "${_YAML_ONLY}" = "true" ]]; then
    deployWfPSRuntime
  fi
fi

if [[ "${_YAML_ONLY}" = "false" ]]; then
  if [[ "${_NOWAIT}" = "false" ]]; then
    waitForWfPSReady ${WFPS_NAMESPACE} ${WFPS_NAME} 5
    if [ $? -eq 0 ]; then
      echo ${WFPS_NAME}" is not ready"
    else
      echo "Success, "${WFPS_NAME}" is operated through the folowing URLs using '${WFPS_ADMINUSER}' credentials"
      showWfPSUrls ${WFPS_NAMESPACE} ${WFPS_NAME}
    fi
  else
    echo "Success, ${WFPS_NAME} is building, you may check its status rerunning this command without -n parameter"
  fi
fi

exit 0
