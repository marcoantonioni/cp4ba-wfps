#!/bin/bash

#set -euo pipefail


_me=$(basename "$0")

_NOWAIT=false
_YAML_ONLY=false
_TAG_ES=""
_TAG_FEDERATE=""
_CR_YAML=""
_ENV_CFG=""

#--------------------------------------------------------
_CLR_RED="\033[0;31m"   #'0;31' is Red's ANSI color code
_CLR_GREEN="\033[0;32m"   #'0;32' is Green's ANSI color code
_CLR_YELLOW="\033[1;33m"   #'1;32' is Yellow's ANSI color code
_CLR_BLUE="\033[0;34m"   #'0;34' is Blue's ANSI color code
_CLR_NC="\033[0m"

usage () {
  echo ""
  echo -e "${_CLR_GREEN}usage: $_me
    -c full-path-to-wfps-config-file 
       (eg: '../configs/env1.properties')
    -e full-path-to-target-environment-config-file 
    -g(optional) generate-yaml-only
    -t(optional) path-of-trusted-certs-config-file
    -n(optional) no wait for instance readiness${_CLR_NC}"
}

#--------------------------------------------------------
# read command line params
while getopts c:t:e:ng flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        e) _ENV_CFG=${OPTARG};;
        t) _TRUST=${OPTARG};;
        n) _NOWAIT=true;;
        g) _YAML_ONLY=true;;
    esac
done

if [[ -z "${_CFG}" ]] || [[ -z "${_ENV_CFG}" ]]; then
  usage
  exit 1
fi



export CONFIG_FILE=${_CFG}
export TARGET_ENV_CONFIG_FILE=${_ENV_CFG}

if [[ ! -z "${_TRUST}" ]]; then
  export TRUST_CERTS_FILE=${_TRUST}
fi

_SCRIPT_PATH="${BASH_SOURCE}"
while [ -L "${_SCRIPT_PATH}" ]; do
  _SCRIPT_DIR="$(cd -P "$(dirname "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"
  _SCRIPT_PATH="$(readlink "${_SCRIPT_PATH}")"
  [[ ${_SCRIPT_PATH} != /* ]] && _SCRIPT_PATH="${_SCRIPT_DIR}/${_SCRIPT_PATH}"
done
_SCRIPT_PATH="$(readlink -f "${_SCRIPT_PATH}")"
_SCRIPT_DIR="$(cd -P "$(dirname -- "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"

source $_SCRIPT_DIR/oc-utils.sh

#--------------------------------------------------------
deployWfPSRuntimeWithCerts () {

_TAG="${WFPS_APP_TAG}"
if [[ ! -z "${WFPS_PATCHED_IMG}" ]]; then
  _TAG="${WFPS_PATCHED_IMG_TAG}"
fi

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
  appVersion: "${WFPS_APP_VER}"
  image:
    imagePullPolicy: IfNotPresent
    repository: "${WFPS_PATCHED_IMG:-cp.icr.io/cp/cp4a/workflow-ps/workflow-ps-server}"
    tag: "${_TAG}"
  deploymentLicense: production
  node:
    resources:
      limits:
        cpu: ${WFPS_LIMITS_CPU}
        memory: ${WFPS_LIMITS_MEMORY}
      requests:
        cpu: ${WFPS_REQS_CPU}
        memory: ${WFPS_REQS_MEMORY}
  businessEvent:
    enable: false

  database:
    external:
      serverName: ${WFPS_EXT_DB_SERVER}
      port: ${WFPS_EXT_DB_PORT}
      type: postgresql
      databaseName:	${WFPS_EXT_DB_NAME}
      current_schema: wfpsdb
      dbCredentialSecret:	${WFPS_EXT_DB_CREDENTIAL_SECRET} # The secret key must include the username and password      
      enableSSL: false
      sslMode: require
    client:
      maxConnectionPoolSize: 200
      minConnectionPoolSize: 50

EOF

}
#--------------------------------------------------------
deployWfPSRuntimeWithoutCerts () {

_TAG="${WFPS_APP_TAG}"
if [[ ! -z "${WFPS_PATCHED_IMG}" ]]; then
  _TAG="${WFPS_PATCHED_IMG_TAG}"
fi

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
  appVersion: "${WFPS_APP_VER}"
  image:
    imagePullPolicy: IfNotPresent
    repository: "${WFPS_PATCHED_IMG:-cp.icr.io/cp/cp4a/workflow-ps/workflow-ps-server}"
    tag: "${_TAG}"
  deploymentLicense: production
  node:
    resources:
      limits:
        cpu: ${WFPS_LIMITS_CPU}
        memory: ${WFPS_LIMITS_MEMORY}
      requests:
        cpu: ${WFPS_REQS_CPU}
        memory: ${WFPS_REQS_MEMORY}

  database:
    external:
      serverName: ${WFPS_EXT_DB_SERVER}
      port: ${WFPS_EXT_DB_PORT}
      type: postgresql
      databaseName:	${WFPS_EXT_DB_NAME}
      current_schema: wfpsdb
      dbCredentialSecret:	${WFPS_EXT_DB_CREDENTIAL_SECRET} # The secret key must include the username and password      
      enableSSL: false
      sslMode: require
    client:
      maxConnectionPoolSize: 200
      minConnectionPoolSize: 50

EOF

if [[ "${_YAML_ONLY}" = "false" ]]; then
  oc create -f ${_CR_YAML}
fi

}

createSecrets () {
  _SECRET_NAME="${CP4BA_INST_CR_NAME}-ibm-mls-itp-admin-secret"
  [[ "${_VERBOSE}" = "true" ]] && echo -e "Secret '${_CLR_YELLOW}${WFPS_EXT_DB_CREDENTIAL_SECRET}${_CLR_NC}'"
  oc delete secret -n ${WFPS_NAMESPACE} ${WFPS_EXT_DB_CREDENTIAL_SECRET} 2> /dev/null 1> /dev/null
  oc create secret -n ${WFPS_NAMESPACE} generic ${WFPS_EXT_DB_CREDENTIAL_SECRET} \
    --from-literal=username="${WFPS_EXT_DB_USER_NAME}" \
    --from-literal=password="${WFPS_EXT_DB_USER_PASSWORD}" 1> /dev/null

}

generateCR () {
  _CR_YAML="../output/${WFPS_NAME}.yaml"

  envsubst < ${WFPS_RUNTIME_TEMPLATE} > ${_CR_YAML}
  if [[ $? -ne 0 ]]; then
    echo -e "${_CLR_RED}[✗] Error, CP4BA CR not generated.${_CLR_NC}"
    exit 1
  fi

  if [[ -f "${_CR_YAML}" ]]; then
    yq ${_CR_YAML} 2>/dev/null 1>/dev/null
    YAML_ERROR=$?
    if [ $YAML_ERROR -gt 0 ]; then
      echo -e "${_CLR_RED}[✗] Error, wrong yaml format in '${_CLR_YELLOW}${_CR_YAML}${_CLR_RED}'${_CLR_NC}"
      echo "++++++++++++++++++++++++++++++++++++++++"
      yq ${_CR_YAML}
      echo "++++++++++++++++++++++++++++++++++++++++"
      exit 1
    fi
  else
    echo -e "${_CLR_GREEN}[✗] Error, file not found '${_CLR_YELLOW}${_CR_YAML}${_CLR_RED}'${_CLR_NC}"
    exit 1
  fi 
  echo -e "${_CLR_GREEN}CR '${_CLR_YELLOW}${CP4BA_INST_CR_NAME}${_CLR_GREEN}' saved in file '${_CLR_YELLOW}${_CR_YAML}${_CLR_YELLOW}'${_CLR_NC}"
}



#-------------------------------
_createDatabases () {
# $1 CP4BA_INST_DB_CR_NAME
# $3 _CR_SUFFIX

  _DB_CR_NAME=$1
  _DB_CR_NAME_SUFFIX=$2
  _FOUND=0

  _PG_BASE_FOLDER="tmp/postgresql"

  _DONE=0
  _KO=0

  _MAX_WAIT_READY=600
  echo -e "${_CLR_GREEN}Wait for pod '${_CLR_YELLOW}"${_DB_CR_NAME}-${_DB_CR_NAME_SUFFIX}"${_CLR_GREEN}' ready (may take minutes)${_CLR_NC}"
  _RES=$(oc wait -n ${CP4BA_INST_SUPPORT_NAMESPACE} pod/${_DB_CR_NAME}-${_DB_CR_NAME_SUFFIX} --for condition=Ready --timeout="${_MAX_WAIT_READY}"s 2>/dev/null)
  _IS_READY=$(echo $_RES | grep "condition met" | wc -l)
  if [ $_IS_READY -eq 1 ]; then
    echo -e "${_CLR_GREEN}Database pod is ready, load and execute sql statements in '${_CLR_YELLOW}${_DB_CR_NAME}-${_DB_CR_NAME_SUFFIX}${_CLR_GREEN}' db server${_CLR_NC}"

    # wait for container ready
    while true 
    do
      oc rsh -n ${CP4BA_INST_SUPPORT_NAMESPACE} -c='postgres' ${_DB_CR_NAME}-${_DB_CR_NAME_SUFFIX} mkdir -p /${_PG_BASE_FOLDER}/setupdb 2>/dev/null 1>/dev/null
      if [ $? -gt 0 ]; then
        echo -e -n "${_CLR_GREEN}container '${_CLR_YELLOW}postgres${_CLR_GREEN}' not ready in pod '${_CLR_YELLOW}${_DB_CR_NAME}-${_DB_CR_NAME_SUFFIX}${_CLR_GREEN}'\033[0K\r"
        sleep 5
        echo -e -n "                                                            \033[0K\r"
      else
        break
      fi
    done

    if [ $_KO -eq 0 ]; then
      # echo -e "${_CLR_GREEN}... create folders for tablespaces${_CLR_NC}"

      oc rsh -n ${CP4BA_INST_SUPPORT_NAMESPACE} -c='postgres' ${_DB_CR_NAME}-${_DB_CR_NAME_SUFFIX} mkdir -p /${_PG_BASE_FOLDER}/setupdb 2>/dev/null 1>/dev/null
      if [ $? -gt 0 ]; then
        _KO=1
        echo -e "${_CLR_RED}Error creating folders in pod '${_CLR_YELLOW}${_DB_CR_NAME}-${_DB_CR_NAME_SUFFIX}${_CLR_RED}'${_CLR_NC}"        
      fi
    fi

    if [ $_KO -eq 0 ]; then
      # echo -e "${_CLR_GREEN}... copy sql statements file into pod's f.s. (${_PG_BASE_FOLDER}/setupdb/${WFPS_EXT_DB_TEMPLATE}) ${_CLR_NC}"
      oc cp ${WFPS_EXT_DB_TEMPLATE} ${CP4BA_INST_SUPPORT_NAMESPACE}/${_DB_CR_NAME}-${_DB_CR_NAME_SUFFIX}:/${_PG_BASE_FOLDER}/setupdb/${WFPS_EXT_DB_NAME}.sql -c='postgres' 2>/dev/null 1>/dev/null
      if [ $? -gt 0 ]; then
        _KO=1
        echo -e "${_CLR_RED}Error copying SQL statements file if f.s. of pod '${_CLR_YELLOW}${_DB_CR_NAME}-${_DB_CR_NAME_SUFFIX}${_CLR_RED}'${_CLR_NC}"        
      fi
    fi

    if [ $_KO -eq 0 ]; then

      oc rsh -n ${CP4BA_INST_SUPPORT_NAMESPACE} -c='postgres' ${_DB_CR_NAME}-${_DB_CR_NAME_SUFFIX} chown -R postgres:postgres /${_PG_BASE_FOLDER}/setupdb 2>/dev/null 1>/dev/null

      # execute sql statements
      _retry=0
      while [[ $_retry -le 10 ]]
      do
        # echo -e "${_CLR_GREEN}... execute sql statements${_CLR_NC}"
        
        oc rsh -n ${CP4BA_INST_SUPPORT_NAMESPACE} -c='postgres' ${_DB_CR_NAME}-${_DB_CR_NAME_SUFFIX} psql -U postgres -f /${_PG_BASE_FOLDER}/setupdb/${WFPS_EXT_DB_NAME}.sql 2>/dev/null 1>/dev/null
        
        if [ $? -gt 0 ]; then
          _KO=1
          echo -e "${_CLR_RED}Error executing SQL statements in pod '${_CLR_YELLOW}${_DB_CR_NAME}-${_DB_CR_NAME_SUFFIX}${_CLR_RED}', retry...${_CLR_NC}" 
          sleep 10
        else
          _KO=0
          echo -e "${_CLR_GREEN}The SQL statements were executed successfully.${_CLR_NC}" 
          break  
        fi
        ((_retry = _retry + 1))
      done        
    fi

    if [ $_KO -eq 0 ]; then
      _NUM_DB=$(cat ${WFPS_EXT_DB_TEMPLATE} | grep "CREATE DATABASE" | wc -l)
      echo -e "${_CLR_GREEN}Created '${_CLR_YELLOW}${_NUM_DB}${_CLR_GREEN}' databases.${_CLR_NC}"
      _DONE=1
    fi
  fi

  if [[ "$_DONE" = "0" ]]; then
    echo ""
    echo -e "${_CLR_RED}[✗] DBs NOT configured, check status of pod '${_CLR_YELLOW}${_DB_CR_NAME}-${_DB_CR_NAME_SUFFIX}${_CLR_RED}'${_CLR_NC}"
    oc get pod -n ${CP4BA_INST_SUPPORT_NAMESPACE} ${_DB_CR_NAME}-${_DB_CR_NAME_SUFFIX} -o wide
    echo -e ">>> ${_CLR_RED}\x1b[5mERROR\x1b[25m${_CLR_NC} <<< DB configuration terminated in error."
    echo ""
    exit 1
  fi

}

createDatabases () {
# $1: prefix key

  _DB_CR_NAME_SUFFIX="1"
  if [[ "${CP4BA_INST_DB_USE_EDB}" = "false" ]]; then
    _DB_CR_NAME_SUFFIX="0"
  fi

  i=1
  _IDX_END=${CP4BA_INST_DB_INSTANCES}
  while [[ $i -le $_IDX_END ]]
  do
    _INST_ITEM="$1_$i"
    _INST_DB_CR_NAME="CP4BA_INST_DB_"$i"_CR_NAME"
    _INST_DB_CR_NAME_SSL="CP4BA_INST_DB_"$i"_CR_NAME_SSL"

    if [[ "${!_INST_ITEM}" = "true" ]]; then
      echo -e "Installing '${_CLR_YELLOW}${_INST_ITEM}${_CLR_NC}' "
      if [[ ! -z "${!_INST_DB_CR_NAME}" ]]; then
        _createDatabases ${!_INST_DB_CR_NAME} ${_DB_CR_NAME_SUFFIX}
        if [[ ! -z "${!_INST_DB_CR_NAME_SSL}" ]]; then
          # echo -e "${_CLR_GREEN}Installing databases into server '${_CLR_YELLOW}${!_INST_DB_CR_NAME_SSL}${_CLR_GREEN}'${_CLR_NC}"
          _createDatabases ${!_INST_DB_CR_NAME_SSL} ${_DB_CR_NAME_SUFFIX}
        fi
      else
        echo -e "${_CLR_RED}ERROR, env var '${_CLR_GREEN}${_INST_DB_CR_NAME}${_CLR_RED}' not defined, verify CP4BA_INST_DB_INSTANCES value.${_CLR_NC}"
        echo -e ">>> ${_CLR_RED}\x1b[5mERROR\x1b[25m${_CLR_NC} <<< env var '${_CLR_GREEN}${_INST_DB_CR_NAME}${_CLR_RED}' not defined, verify CP4BA_INST_DB_INSTANCES value.${_CLR_NC}"
        echo ""
        exit 1
      fi
    else
      echo -e "Warning '${_CLR_YELLOW}${_INST_ITEM}${_CLR_NC}' for db '${_CLR_YELLOW}${!_INST_DB_CR_NAME}${_CLR_NC}' is disabled, skipping configuration."
    fi
    ((i = i + 1))
  done  
}

dropAndCreateDb () {
  createDatabases "CP4BA_INST_DB_WFPS_EXT"
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
     enable: ${WFPS_FEDERATE_TEXTSEARCH}
     esStorage:
       storageClassName: ${WFPS_STORAGE_CLASS_BLOCK}
       size: 10Gi
     esSnapshotStorage:
       storageClassName: ${WFPS_STORAGE_CLASS_BLOCK}
       size: 2Gi"

 fi

  dropAndCreateDb

  createSecrets

  generateCR

#  if [[ -z "${CERTS_LIST}" ]]; then
#    deployWfPSRuntimeWithoutCerts
#  else
#    deployWfPSRuntimeWithCerts ${CERTS_LIST}
#  fi

  echo "WfPS CR generated in: "${_CR_YAML}

  if [[ "${_YAML_ONLY}" = "false" ]]; then
    oc create -f ${_CR_YAML} 2> /dev/null 1>/dev/null
  fi

}

executeExportVars () {
  $_SCRIPT_DIR/wfps-export-env-vars-to-file.sh -c ${CONFIG_FILE} -e ${TARGET_ENV_CONFIG_FILE}
}

# Wait for FIX
__workaround () {
  _HOST=$(oc get route cpd -o jsonpath='{.spec.host}') 1>/dev/null
  _PATCH_FILE="/tmp/wfps-patch-$RANDOM.yaml"
  _PROPS='<properties> 
          <server merge="mergeChildren">
            <portal merge="mergeChildren">
              <bpm-data-endpoint merge="replace">https://'${_HOST}':443/'${WFPS_NAME}'-wfps/rest/bpm/federated</bpm-data-endpoint>
              <federated-dashboards-endpoint merge="replace">https://'${_HOST}':443/'${WFPS_NAME}'-wfps/rest/bpm/federated</federated-dashboards-endpoint>
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

#==========================================
echo ""
echo "*************************************"
echo "****** WfPS Runtime Deployment ******"
echo "*************************************"
echo "Using config file: "${CONFIG_FILE}

if [[ ! -f "${_CFG}" || ! -f "${_ENV_CFG}" ]]; then
  echo "Configuration file not found -c [${_CFG}] -e [${_ENV_CFG}]"
  usage
  exit 1
fi

# Read target environment configuration, ignore error for IDP/LDAP configuration properties 
source ${TARGET_ENV_CONFIG_FILE} 2> /dev/null 1> /dev/null

# Read WfPS configuration
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
  # if [[ -z "${WFPS_ADMINUSER}" ]]; then
  #   WFPS_ADMINUSER="cpadmin"
  # fi
  deployWfPSRuntime

# Wait for FIX
# if [[ "${WFPS_FEDERATE}" = "true" ]]; then
# Only without ifix-->  __workaround
# fi

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
      #showWfPSUrls ${WFPS_NAMESPACE} ${WFPS_NAME}
      executeExportVars
    fi
  else
    echo "Success, ${WFPS_NAME} is building, you may check its status rerunning this command without -n parameter"
  fi
fi

exit 0
