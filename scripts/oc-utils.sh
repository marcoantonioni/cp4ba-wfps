#!/bin/bash

#set -euo pipefail


#--------------------------------------------------------
_CLR_RED="\033[0;31m"   #'0;31' is Red's ANSI color code
_CLR_GREEN="\033[0;32m"   #'0;32' is Green's ANSI color code
_CLR_YELLOW="\033[1;33m"   #'1;32' is Yellow's ANSI color code
_CLR_BLUE="\033[0;34m"   #'0;34' is Blue's ANSI color code
_CLR_NC="\033[0m"


CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

#-------------------------------
checkPrereqTools () {
  which jq &>/dev/null
  if [[ $? -ne 0 ]]; then
    log_debug "[✗] Error, jq not installed, cannot proceed.${_CLR_NC}"
    exit 1
  fi
  which openssl &>/dev/null
  if [[ $? -ne 0 ]]; then
    log_warning "${_CLR_YELLOW}[✗] Warning, openssl not installed, some activities may fail.${_CLR_NC}"
  fi
}

#-------------------------------
isParamSet () {
    if [[ -z "$1" ]];
    then
      return 0
    fi
    return 1
}

#-------------------------------
storageClassExist () {
    if [ $(oc get sc $1 2>/dev/null | grep $1 | wc -l) -lt 1 ];
    then
        return 0
    fi
    return 1
}

#-------------------------------
resourceExist () {
#    echo "namespace name: $1"
#    echo "resource type: $2"
#    echo "resource name: $3"
  if [ $(oc get $2 -n $1 $3 2> /dev/null | grep $3 | wc -l) -lt 1 ];
  then
      return 0
  fi
  return 1
}

#-------------------------------
waitForResourceCreated () {
#    echo "namespace name: $1"
#    echo "resource type: $2"
#    echo "resource name: $3"
#    echo "time to wait: $4"

  log_info "${_CLR_GREEN}Wait for resource '${_CLR_YELLOW}$3${_CLR_GREEN}' in namespace '${_CLR_YELLOW}$1${_CLR_GREEN}' to be created"
  while true 
  do
      resourceExist $1 $2 $3
      if [ $? -eq 0 ]; then
          sleep $4
      else
          break
      fi
  done
}

#-------------------------------
waitForWfPSReady () {
#    echo "namespace name: $1"
#    echo "resource name: $2"
#    echo "time to wait: $3"

    log_info "${_CLR_GREEN}Wait for WfPS '${_CLR_YELLOW}$2${_CLR_GREEN}' in namespace '${_CLR_YELLOW}$1${_CLR_GREEN}' to be ready${_CLR_NC}"
    while true 
    do
        _READY=$(oc get wfps -n $1 $2 --no-headers 2>/dev/null | awk '{print $2}')
        if [ "${_READY}" = "True" ]; then
            log_info "${_CLR_GREEN}WfPS '${_CLR_YELLOW}$2${_CLR_GREEN}' in namespace '${_CLR_YELLOW}$1${_CLR_GREEN}' is ready${_CLR_NC}"
            return 1
        else
            sleep $3
        fi
    done
    return 0
}

#-------------------------------
getWfPSUrls() {
    export WFPS_URL_EXPLORER=$(oc get wfps -n $1 $2 -o jsonpath="{.status.endpoints}" 2>/dev/null | jq ".[].uri" | grep explorer | sed 's/\"//g')
    export WFPS_URL_OPS=$(echo ${WFPS_URL_EXPLORER} | sed 's/\/explorer//g')
    export WFPS_EXTERNAL_BASE_URL=$(echo ${WFPS_URL_OPS} | sed 's/\/ops//g')
    export WFPS_URL_WORKPLACE=$(oc get wfps -n $1 $2 -o jsonpath="{.status.endpoints}" 2>/dev/null | jq ".[].uri" | grep Workplace | sed 's/\"//g')
    export WFPS_URL_PROCESSADMIN=$(echo ${WFPS_URL_WORKPLACE} | sed 's/Workplace/ProcessAdmin/g')
    export WFPS_PAK_BASE_URL=$(echo ${WFPS_EXTERNAL_BASE_URL} | sed 's/\/'${WFPS_NAME}'-wfps//g')
}

#-------------------------------
showWfPSUrls() {
    getWfPSUrls $1 $2
    log_info "  Operations url: ${_CLR_YELLOW}${WFPS_URL_OPS}${_CLR_NC}"
    log_info "  Explorer url: ${_CLR_YELLOW}${WFPS_URL_EXPLORER}${_CLR_NC}"
    log_info "  Workplace url: ${_CLR_YELLOW}${WFPS_URL_WORKPLACE}${_CLR_NC}"
    log_info "  ProcessAdmin url: ${_CLR_YELLOW}${WFPS_URL_PROCESSADMIN}${_CLR_NC}"
    log_info "  REST url: ${_CLR_YELLOW}${WFPS_EXTERNAL_BASE_URL}${_CLR_NC}"
    log_info "  Pak console url: ${_CLR_YELLOW}${WFPS_PAK_BASE_URL}${_CLR_NC}"
    log_info "  Admin user: ${_CLR_YELLOW}${WFPS_ADMINUSER}${_CLR_NC}"
    log_info "  Admin password: ${_CLR_YELLOW}${WFPS_ADMINPASSWORD}${_CLR_NC}"

}

#-------------------------------
verifyAllParams () {

  isParamSet ${WFPS_STORAGE_CLASS}
  if [ $? -eq 0 ]; then
      log_debug "ERROR: WFPS_STORAGE_CLASS not set${_CLR_NC}"
      exit 1
  fi

  isParamSet ${WFPS_NAME}
  if [ $? -eq 0 ]; then
      log_debug "ERROR: WFPS_NAME not set${_CLR_NC}"
      exit 1
  fi

  isParamSet ${WFPS_NAMESPACE}
  if [ $? -eq 0 ]; then
      log_debug "ERROR: WFPS_NAMESPACE not set${_CLR_NC}"
      exit 1
  fi

  isParamSet ${WFPS_APP_VER}
  if [ $? -eq 0 ]; then
      log_debug "ERROR: WFPS_APP_VER not set${_CLR_NC}"
      exit 1
  fi

  isParamSet ${WFPS_APP_TAG}
  if [ $? -eq 0 ]; then
      log_debug "ERROR: WFPS_APP_TAG not set${_CLR_NC}"
      exit 1
  fi

  isParamSet ${WFPS_ADMINUSER}
  if [ $? -eq 0 ]; then
      log_debug "ERROR: WFPS_ADMINUSER not set${_CLR_NC}"
      exit 1
  fi



}

#--------------------------------------------------------
getAdminInfo () {
  # $1: boolean skip urls 
  if [[ -z "${WFPS_ADMINUSER}" || "${WFPS_ADMINUSER}" = "cpadmin" ]]; then
    WFPS_ADMINUSER=$(oc get secrets -n ${WFPS_NAMESPACE} platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' 2>/dev/null | base64 -d)
    WFPS_ADMINPASSWORD=$(oc get secrets -n ${WFPS_NAMESPACE} platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' 2>/dev/null | base64 -d)
    if [[ -z "${WFPS_ADMINUSER}" ]]; then
      log_debug "ERROR cannot get admin user name from secret${_CLR_NC}"
      exit 1
    fi
    if [[ -z "${WFPS_ADMINPASSWORD}" ]]; then
      log_debug "ERROR cannot get admin password from secret${_CLR_NC}"
      exit 1
    fi
  fi

  if [[ ! "$1" = "true" ]]; then
    resourceExist ${WFPS_NAMESPACE} wfps ${WFPS_NAME}
    if [ $? -eq 1 ]; then
      getWfPSUrls ${WFPS_NAMESPACE} ${WFPS_NAME}
    else
      log_warning "WARNING: wfps '${_CLR_YELLOW}${WFPS_NAME}${_CLR_NC}' not present in namespace '${_CLR_YELLOW}${WFPS_NAMESPACE}${_CLR_NC}'"
    fi
  fi
}

#--------------------------------------------------------
getCsrfToken() {
# $1 admin user
# $2 admin password
# $3 url ops
  CRED="-u $1:$2"
  LOGIN_URI="$3/system/login"

  _retries=0
  _max_retries=10

  # echo -n "Getting csrf token"
  until CSRF_TOKEN=$(curl -ks -X POST ${CRED} -H 'accept: application/json' -H 'Content-Type: application/json' ${LOGIN_URI} -d '{}' | jq .csrf_token 2>/dev/null | sed 's/"//g') && [[ -n "$CSRF_TOKEN" ]]
  do
    # echo -n "."
    ((_retries=_retries+1))
    if [[ $_retries -gt $_max_retries ]]; then
      log_error "Error getting CSRF token"
      exit 1
    fi
    sleep 1
  done
  # echo ""
  export WFPS_CSRF_TOKEN=${CSRF_TOKEN}
}

#----------------------------------
getContainerStatus () {
# $1 namespace
# $2 pod-name
# $3 container-name
# $4 status
# $5 true|false (show message)

  resourceExist $1 pod $2
  if [ $? -eq 1 ]; then

    CTR_PHASE=$(oc get pod -n $1 $2 -o jsonpath='{.status.phase}')
    if [[ "$5" = "true" ]]; then
      log_info "Pod phase: $CTR_PHASE"
    fi
    if [[ "${CTR_PHASE}" = "Running" ]]; then
      CTR_STATUSES=$(oc get pod -n $1 $2 -o jsonpath='{.status.containerStatuses}' 2>/dev/null )
      _STATE=$(echo $CTR_STATUSES | jq '.[] | select(.name | IN("'$3'"))' | jq .$4)
      if [[ -z "${_STATE}" ]]; then
          return 2
      else
        if [[ "${_STATE}" = "true" ]]; then
          return 1
        else
          return 0
        fi
      fi
    else
      return 3
    fi
  else
    return 0
  fi

}

#----------------------------------
waitContainerStatus () {
# $1 namespace
# $2 pod-name
# $3 container-name
# $4 status
# $5 true|false (show message)
# $6 delay in seconds

  _RESULT=0
  while [ $_RESULT -ne 1 ] 
  do
    getContainerStatus $1 $2 $3 $4 $5
    _RESULT=$?
    if [ $_RESULT -eq 1 ]; then
      _SUFFIX="is $4"
    else
      if [ $_RESULT -eq 0 ]; then
        _SUFFIX="is NOT $4"
      else
        if [ $_RESULT -eq 3 ]; then
          _SUFFIX="is NOT running"
        else
          _SUFFIX="not found"
        fi
      fi
    fi
    if [[ "$5" = "true" ]]; then
      log_info "${_CLR_GREEN}Container '${_CLR_YELLOW}$3${_CLR_GREEN}' of pod '${_CLR_YELLOW}$2${_CLR_GREEN}' ${_SUFFIX}"
    fi
    if [ $_RESULT -ne 1 ]; then
      sleep $6
    fi 
  done
}


