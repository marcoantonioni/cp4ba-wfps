#!/bin/bash

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
    if [ $(oc get sc $1 | grep $1 | wc -l) -lt 1 ];
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

  echo -n "Wait for resource '$3' in namespace '$1' created"
  while [ true ]
  do
      resourceExist $1 $2 $3 $4
      if [ $? -eq 0 ]; then
          echo -n "."
          sleep $4
      else
          echo ""
          break
      fi
  done
}

#-------------------------------
waitForWfPSReady () {
#    echo "namespace name: $1"
#    echo "resource name: $2"
#    echo "time to wait: $3"

    echo -n "Wait for WfPs '$2' in namespace '$1' to be READY"
    while [ true ]
    do
        _READY=$(oc get wfps -n $1 $2 --no-headers | awk '{print $2}')
        if [ "${_READY}" = "True" ]; then
            echo ""
            echo "WfPS '$2' in namespace '$1' is READY"
            return 1
        else
            echo -n "."
            sleep $3
        fi
    done
    return 0
}

#-------------------------------
getWfPSUrls() {
    export WFPS_URL_EXPLORER=$(oc get wfps -n $1 $2 -o jsonpath="{.status.endpoints}" | jq ".[].uri" | grep explorer | sed 's/\"//g')
    export WFPS_URL_OPS=$(echo ${WFPS_URL_EXPLORER} | sed 's/\/explorer//g')
    export WFPS_EXTERNAL_BASE_URL=$(echo ${WFPS_URL_OPS} | sed 's/\/ops//g')
    export WFPS_URL_WORKPLACE=$(oc get wfps -n $1 $2 -o jsonpath="{.status.endpoints}" | jq ".[].uri" | grep Workplace | sed 's/\"//g')
    export WFPS_URL_PROCESSADMIN=$(echo ${WFPS_URL_WORKPLACE} | sed 's/Workplace/ProcessAdmin/g')
}

#-------------------------------
showWfPSUrls() {
    getWfPSUrls $1 $2
    echo "  operations url: "${WFPS_URL_OPS}
    echo "  explorer url: "${WFPS_URL_EXPLORER}
    echo "  Workplace url: "${WFPS_URL_WORKPLACE}
    echo "  ProcessAdmin url: "${WFPS_URL_PROCESSADMIN}
    echo "  REST url: "${WFPS_EXTERNAL_BASE_URL}
}

#-------------------------------
verifyAllParams () {

  isParamSet ${WFPS_STORAGE_CLASS}
  if [ $? -eq 0 ]; then
      echo "ERROR: WFPS_STORAGE_CLASS not set"
      exit 1
  fi

  isParamSet ${WFPS_NAME}
  if [ $? -eq 0 ]; then
      echo "ERROR: WFPS_NAME not set"
      exit 1
  fi

  isParamSet ${WFPS_NAMESPACE}
  if [ $? -eq 0 ]; then
      echo "ERROR: WFPS_NAMESPACE not set"
      exit 1
  fi

  isParamSet ${WFPS_APP_VER}
  if [ $? -eq 0 ]; then
      echo "ERROR: WFPS_APP_VER not set"
      exit 1
  fi

  isParamSet ${WFPS_APP_TAG}
  if [ $? -eq 0 ]; then
      echo "ERROR: WFPS_APP_TAG not set"
      exit 1
  fi

}

#--------------------------------------------------------
getAdminInfo () {
  WFPS_ADMINUSER=$(oc get secrets -n ${WFPS_NAMESPACE} platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 -d)
  WFPS_ADMINPASSWORD=$(oc get secrets -n ${WFPS_NAMESPACE} platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d)
  if [[ -z "${WFPS_ADMINUSER}" ]]; then
    echo "ERROR cannot get admin user name from secret"
    exit 1
  fi
  if [[ -z "${WFPS_ADMINPASSWORD}" ]]; then
    echo "ERROR cannot get admin password from secret"
    exit 1
  fi
}

#--------------------------------------------------------
getCsrfToken() {
# $1 admin user
# $2 admin password
# $3 url ops
  CRED="-u $1:$2"
  LOGIN_URI="$3/system/login"
  echo -n "Getting csrf token"
  until CSRF_TOKEN=$(curl -ks -X POST ${CRED} -H 'accept: application/json' -H 'Content-Type: application/json' ${LOGIN_URI} -d '{}' | jq .csrf_token | sed 's/"//g') && [[ -n "$CSRF_TOKEN" ]]
  do
  echo $CSRF_TOKEN
    echo -n "."
    sleep 1
  done
  echo ""
  export WFPS_CSRF_TOKEN=${CSRF_TOKEN}
}

# ????
getUserPasswordFromLocalLdif () {

  TNS=cp4ba
  USER_NAME=user1
  USER_PASSWORD=$(oc get secrets -n ${TNS} | grep openldap-customldif | awk '{print $1}' | xargs oc get secret -n ${TNS} -o jsonpath='{.data.ldap_user\.ldif}' | base64 -d | grep "dn: uid=${USER_NAME}," -A5 | grep userpassword | sed 's/userpassword: //g')
  echo ${USER_NAME}" / "${USER_PASSWORD}

}

