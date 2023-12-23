# README-POSTGRES-AE

```

# Postgres CRD: clusters.postgresql.k8s.enterprisedb.io

CP4BA_AUTO_NAMESPACE=cp4ba-federated-wfps

AE_CR_NAME=my-postgres-ae
AE_DB_OWNER=postgres

AE_HOST_NAME="${AE_CR_NAME}-rw.${CP4BA_AUTO_NAMESPACE}.svc.cluster.local"
AE_HOST_PORT=5432
AE_DB_SCHEMA="AEDB"
AE_DB_TS_NAME="AEDB"
AE_DB_NAME="AEDB"

cat <<EOF | oc create -f -
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Cluster
metadata:
  name: ${AE_CR_NAME}
  namespace: ${CP4BA_AUTO_NAMESPACE}
spec:
  logLevel: info
  startDelay: 30
  stopDelay: 30
  imagePullSecrets:
    - name: ibm-entitlement-key
  resources:
    limits:
      cpu: '1'
      memory: 2Gi
    requests:
      cpu: '1'
      memory: 2Gi
  imageName: >-
    icr.io/cpopen/edb/postgresql:13.10-4.14.0@sha256:0064d1e77e2f7964d562c5538f0cb3a63058d55e6ff998eb361c03e0ef7a96dd
  enableSuperuserAccess: true
  bootstrap:
    initdb:
      database: ${AE_DB_NAME}
      encoding: UTF8
      localeCType: C
      localeCollate: C
      owner: ${AE_DB_OWNER}
  postgresql:
    parameters:
      log_truncate_on_rotation: 'false'
      archive_mode: 'on'
      log_filename: postgres
      archive_timeout: 5min
      max_replication_slots: '32'
      log_rotation_size: '0'
      work_mem: 20MB
      shared_preload_libraries: ''
      logging_collector: 'on'
      wal_receiver_timeout: 5s
      log_directory: /controller/log
      log_destination: csvlog
      wal_sender_timeout: 5s
      max_worker_processes: '32'
      max_parallel_workers: '32'
      log_rotation_age: '0'
      shared_buffers: 512MB
      max_prepared_transactions: '100'
      shared_memory_type: mmap
      dynamic_shared_memory_type: posix
      wal_keep_size: 512MB
    pg_hba:
      - host all all 0.0.0.0/0 md5
    syncReplicaElectionConstraint:
      enabled: false
  minSyncReplicas: 0
  maxSyncReplicas: 0
  postgresGID: 26
  postgresUID: 26
  primaryUpdateMethod: switchover
  switchoverDelay: 40000000
  storage:
    resizeInUseVolumes: true
    size: 16Gi
    storageClass: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
  primaryUpdateStrategy: unsupervised
  instances: 1
EOF


# If you deploy the CR before the ICP4ACluster, don't worry if don't see any activity about you postgres db.
# The deployment of your db will start when the CR ICP4ACluster will create the pod 'postgresql-operator-controller-manager-...' into used namespace.
# Operator: EDB Postgres for Kubernetes
# oc apply -f https://get.enterprisedb.io/cnp/postgresql-operator-1.21.0.yaml
# https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/interactive_demo/
#----------------------


echo "Forwarding local port ${AE_HOST_PORT} to ${AE_CR_NAME}-1 pod..."
PSQL_POD_NAME=$(oc get pod -n ${CP4BA_AUTO_NAMESPACE} | grep ${AE_CR_NAME}-1 | grep Running | grep -v deploy | grep -v hook | awk '{print $1}')
if [ ! -z ${PSQL_POD_NAME} ]; then oc port-forward -n ${CP4BA_AUTO_NAMESPACE} ${PSQL_POD_NAME} ${AE_HOST_PORT}:${AE_HOST_PORT}; fi & 

DB_USER=$(oc get secret -n ${CP4BA_AUTO_NAMESPACE} ${AE_CR_NAME}-app -o jsonpath='{.data.username}' | base64 -d)
DB_PASSWORD=$(oc get secret -n ${CP4BA_AUTO_NAMESPACE} ${AE_CR_NAME}-app -o jsonpath='{.data.password}' | base64 -d)
DB_PGPASS=$(oc get secret -n ${CP4BA_AUTO_NAMESPACE} ${AE_CR_NAME}-app -o jsonpath='{.data.pgpass}' | base64 -d)
echo $DB_USER / $DB_PASSWORD / $DB_PGPASS

export PGPASSFILE='/home/'$USER'/.pgpass'
echo "${DB_PGPASS}" | sed 's/'${AE_CR_NAME}'-rw:/localhost:/g' > ${PGPASSFILE}
chmod 0600 ${PGPASSFILE}

psql -h localhost -U ${DB_USER} -d ${AE_DB_NAME}

\l            # list db
\c AEDB       # connect
\dn+          # list schema
\dt+ dbasb.*  # list tables in schema


#----------------------

oc delete cluster -n ${CP4BA_AUTO_NAMESPACE} ${AE_CR_NAME}



```

