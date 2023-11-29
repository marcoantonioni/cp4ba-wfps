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
  if [ $(oc get $2 -n $1 $3 | grep $3 | wc -l) -lt 1 ];
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

showWfPSUrls() {
    URL_EXPLORER=$(oc get wfps -n $1 $2 -o jsonpath="{.status.endpoints}" | jq ".[].uri" | grep explorer | sed 's/\"//g')
    URL_OPS=$(echo ${URL_EXPLORER} | sed 's/\/explorer//g')
    URL_WORKPLACE=$(oc get wfps -n $1 $2 -o jsonpath="{.status.endpoints}" | jq ".[].uri" | grep Workplace | sed 's/\"//g')
    echo "  operations url: "${URL_OPS}
    echo "  explorer url: "${URL_EXPLORER}
    echo "  Workplace url: "${URL_WORKPLACE}

}

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

isParamSet ${WFPS_ADMINUSER}
if [ $? -eq 0 ]; then
    echo "ERROR: WFPS_ADMINUSER not set"
    exit 1
fi

isParamSet ${WFPS_ADMINPASSWORD}
if [ $? -eq 0 ]; then
    echo "ERROR: WFPS_ADMINPASSWORD not set"
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

getUserPasswordFromLocalLdif () {

TNS=cp4ba
USER_NAME=user1
USER_PASSWORD=$(oc get secrets -n ${TNS} | grep openldap-customldif | awk '{print $1}' | xargs oc get secret -n ${TNS} -o jsonpath='{.data.ldap_user\.ldif}' | base64 -d | grep "dn: uid=${USER_NAME}," -A5 | grep userpassword | sed 's/userpassword: //g')
echo ${USER_NAME}" / "${USER_PASSWORD}

}