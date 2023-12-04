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


#--------------------------------------------------------
getAdminInfo () {
  WFPS_ADMINUSER=$(oc get secrets -n ${WFPS_NAMESPACE} platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 -d)
  WFPS_ADMINPASSWORD=$(oc get secrets -n ${WFPS_NAMESPACE} platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d)
}

#--------------------------------------------------------
deployWfPSRuntime () {

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

#==========================================
echo ""
echo "*************************************"
echo "****** WfPS Runtime Deployment ******"
echo "*************************************"
echo "Using config file: "${CONFIG_FILE}

source ${CONFIG_FILE}

verifyAllParams

storageClassExist ${WFPS_STORAGE_CLASS}
if [ $? -eq 0 ]; then
    echo "ERROR: Storage class not found"
    exit
fi

resourceExist ${WFPS_NAMESPACE} wfps ${WFPS_NAME}
if [ $? -eq 0 ]; then
  echo "Ready to install..."
  getAdminInfo
  if [[ -z "${WFPS_ADMINUSER}" ]]; then
    WFPS_ADMINUSER=cpadmin
  fi
  deployWfPSRuntime
  waitForResourceCreated ${WFPS_NAMESPACE} wfps ${WFPS_NAME} 60
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
