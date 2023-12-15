#!/bin/bash

_me=$(basename "$0")

_POD_NAME=""
_NS=""

#--------------------------------------------------------
# read command line params
while getopts p:n:c: flag
do
    case "${flag}" in
        p) _POD_NAME=${OPTARG};;
        n) _NS=${OPTARG};;
        c) _CTR_NAME=${OPTARG};;
    esac
done

if [[ -z "${_POD_NAME}" ]] || [[ -z "${_NS}" ]] || [[ -z "${_CTR_NAME}" ]]; then
  echo "-p pod-name -c container-name -n namespace"
  exit 1
fi

source ./oc-utils.sh


waitContainerStatus ${_NS} ${_POD_NAME} ${_CTR_NAME} "ready" true 2