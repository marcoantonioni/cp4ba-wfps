# README-POSTGRES-BAN

```

seguire punti:
https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=ban-creating-databases-without-running-provided-scripts
  3. Create a table space in your database.
  The FileNet Content Manager documentation provides some information on creating table spaces, on Db2, Oracle, and Microsoft SQL Server. Note that for Navigator, the sizing requirements are less than other uses, such as object stores. When you create the table space for Navigator, use "REGULAR" as the type or size.
  
  4. Create a database user.
  You can choose to use your dbadmin user, or create another database user for your Navigator database.
  For details about the kind of privileges this user needs, see Creating database accounts.

  This user that you create is included in the Business Automation Navigator secret as the navigatorDBUsername.

  5. Optionally create a schema.
  The operator can detect whether a schema exists in the database and creates one if a schema does not exist. If you want to select a schema name in advance, specify the name of your schema in the custom resource file in the icn_production_setting.icn_schema parameter. If you plan to use Task Manager, the schema name must be ICNDB.
  If you don't specify a value for the icn_production_setting.icn_schema parameter, the operator creates the following schema name:
  Oracle database: The schema is named the same as the navigatorDBUsername from the Business Automation Navigator secret.
  All other databases: The schema keeps the default name, ICNDB.

!!!!!!
When the Navigator deployment first starts, Navigator checks whether the configuration database schema and tables are present. If not, Navigator runs the necessary SQL commands to create them.


  (no volumes...?? ... https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=ban-creating-volumes-folders-deployment-kubernetes)


# Postgres CRD: clusters.postgresql.k8s.enterprisedb.io

CP4BA_AUTO_NAMESPACE=cp4ba-federated-wfps

ICN_CR_NAME=my-postgres-ban
ICN_DB_OWNER=postgres

ICN_HOST_NAME="${ICN_CR_NAME}-rw.${CP4BA_AUTO_NAMESPACE}.svc.cluster.local"
ICN_HOST_PORT=5432
ICN_DB_SCHEMA="ICNDB"
ICN_DB_TS_NAME="ICNDB"
ICN_DB_NAME="ICNDB"

cat <<EOF | oc create -f -
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Cluster
metadata:
  name: ${ICN_CR_NAME}
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
      database: ${ICN_DB_NAME}
      encoding: UTF8
      localeCType: C
      localeCollate: C
      owner: ${ICN_DB_OWNER}
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


echo "Forwarding local port ${ICN_HOST_PORT} to ${ICN_CR_NAME}-1 pod..."
PSQL_POD_NAME=$(oc get pod -n ${CP4BA_AUTO_NAMESPACE} | grep ${ICN_CR_NAME}-1 | grep Running | grep -v deploy | grep -v hook | awk '{print $1}')
if [ ! -z ${PSQL_POD_NAME} ]; then oc port-forward -n ${CP4BA_AUTO_NAMESPACE} ${PSQL_POD_NAME} ${ICN_HOST_PORT}:${ICN_HOST_PORT}; fi & 

DB_USER=$(oc get secret -n ${CP4BA_AUTO_NAMESPACE} ${ICN_CR_NAME}-app -o jsonpath='{.data.username}' | base64 -d)
DB_PASSWORD=$(oc get secret -n ${CP4BA_AUTO_NAMESPACE} ${ICN_CR_NAME}-app -o jsonpath='{.data.password}' | base64 -d)
DB_PGPASS=$(oc get secret -n ${CP4BA_AUTO_NAMESPACE} ${ICN_CR_NAME}-app -o jsonpath='{.data.pgpass}' | base64 -d)
echo $DB_USER / $DB_PASSWORD / $DB_PGPASS

export PGPASSFILE='/home/'$USER'/.pgpass'
echo "${DB_PGPASS}" | sed 's/'${ICN_CR_NAME}'-rw:/localhost:/g' > ${PGPASSFILE}
chmod 0600 ${PGPASSFILE}

psql -h localhost -U ${DB_USER} -d ${ICN_DB_NAME}


\l            # list db
\c ICNDB      # connect
\dn+          # list schema
\dt+ icndb.*  # list tables in schema


#----------------------

oc delete cluster -n ${CP4BA_AUTO_NAMESPACE} ${ICN_CR_NAME}



```

