# Merritt Admin Sinatra

This lambda is part of the [Merritt Preservation System](https://github.com/CDLUC3/mrt-doc). 

## Purpose

Sinatra based admin tool for the new Merritt AWS account.

## Local Testing

### Merritt app
```
bundle exec puma app/config_mrt.ru
```

Resources for deploying as a lambda
- https://github.com/CDLUC3/mrt-sceptre/tree/main/mrt-admin-sinatra
- Because this application uses mysql, it must be packaged as a docker image
- `ENV RACK_CONFIG=app/config_mrt.ru`

### UC3-focuesed app
```
bundle exec puma app/config_uc3.ru
```

Resources for deploying as a lambda
- a new sceptre deploy will need to be created to grant a different SSO group access
- this could be deployed as a zip or as an image
- `ENV RACK_CONFIG=app/config_uc3.ru`

Building on EC2 in the main account... warning, this may break lambda deployment
```
bundle config set force_ruby_platform true
```

## Resources needed
- GitHub API token with read permission for our repos
- https://github.com/CDLUC3/mrt-sceptre/tree/main/mrt-admin-sinatra
- Gems
  - GitHub octokit
  - AWS code artifact
  - AWS ecr
  - AWS lambda

## Features
- https://github.com/CDLUC3/mrt-doc/issues/2123

## Design Ideas

### Assumptions
- Application should be fully-testable with a desktop run of sinatra
  - AWS credentials will grant access to resources
  - some core components will be used for a UC3 admin tool
    - code could be cloned or packaged as a library for re-use
- Collection Admin
  - eliminate SLA
  - eliminate admin objects
  - object/collection creation via inventory endpoints
- Clean sinatra routing
  - should each of the following be a separate module?
  - place generic classes into a library/gem?
  - import library/modules into the UC3 admin tool
  - place as much config as possible into yaml
    - SQL
    - tag queries
    - ssm queries

### Widget Types
- text
- list
- hyperlink
    - url provided
    - url derived from column type
- button
- disabled-button
- row class

### AdminClient
- process routes
- generate breadcrumbs
- generate menu items
- access to generic resources such as table
  - need button generation classes

### Endpoints
-  code (SourceCodeClient)
  - Subclasses: GithubClient, CodeArtifactClient, ECRImageClient
  - tags
  - tag-obsolete
  - artifact-delete
  - image-tag-obsolete
  - deploy*
- infra (DevOpsClient)
  - Subclasses: AwsTagClient, SSMParamClient, EC2TagClient
  - list-ssm
  - list-instances
  - list-lambdas
  - list-load-balancers*
  - service-state
  - instance-state
  - lambda-service-state
- system-state (SystemStateClient)
  - Subclasses: ConsistencyReportClient, S3InputClient, BillingUpdateClient
  - consistency-check
  - ldap-certs
  - report-cleanup
  - billing-update
- opensearch* (OpenSearchClient)
  - list-opensearch-fields
  - count-errors*
  - update-data-index* (billing counts viz)
- zookeeper (ZookeeperClient)
  - lock (access, ingest, audit*, replic*)
  - unlock
  - list-locks
  - list-nodes
  - delete node*
  - update-node*
  - orphan-report
- queue (MerrittQueueClient)
  - list-batches
  - list-jobs
  - list-jobs-by-profile
  - list-assemblies
  - delete-queue-item
  - requeue-queue-item
  - lock-collection
  - unclock-collection
  - release-held-items-for-collection
  - cleanup-queue
- Ingest (MerrittIngestClient)
  - list-ingest-folder-files
  - display-ingest-manifest
- database (QueryClient)
  - report
    - content
    - storage
    - ingest
    - replication
    - audit
  - search (by keyword)
  - large-report
  - iterative-report
- collection-config (CollectionConfigClient)
  - profiles
  - storage-nodes
  - create-owner
  - create-collection
  - update-owner
  - update-collection
  - remove-storage-node
  - delete-batch-of-objects-from-node
  - change-primary-node*
- storage-scan (StorageScanClient)
  - get-csv
  - bulk-update-from-csv
  - get-scan-results-by-state
  - start-scan
  - pause-scan
  - resume-scan
  - cancel-scan
  - stop-all-scans
  - resume-all-scans
  - clear-scan-result-for-ark
  - mark-scan-result-hold
  - mark-scan-result-delete
  - mark-scan-result-review
  - initiate-scan-result-deletes
- object-maint (MerrittObjectClient)
  - Subclasses: MerrittStorageClient, MerrittReplicClient, MerrittIngentoryClient
  - get-manifest
  - get-manifest-as-yaml
  - get-collection-manifest
  - requeue-replic
  - requeue-audit
  - rebuild-inventory
  - delete-object*
  - delete-object-from-node
- ldap (LdapClient)
  - list-users
  - list-groups
  - list-permissions
  - report-invalid-users
  - report-invalid-groups
  - report-invalid-collection-map
  - create-user*
  - create-group*
- audit (MerrittAuditClient)
  - release-audit-batches

### Fields
- string
- number
    - byte
- date
    - datetime
- ark
    - object-ark
    - collection-ark
    - owner-ark
    - ldap-ark
    - local-id
- zk-id
    - batch-id
    - job-id
    - assembly-id
- ingest-uuid
    - jid
    - bid
- mysql-id
    - collection-id
    - node-id
- file-path
- mime
    - mimetype
    - mimegroup
- campus
- ldap
    - ldap-user
    - ldap-group
    - ldap-collection
- mnemonic
    - profle-name
