# Merritt Admin Tool

The Merritt Admin Tool supports a stack of microservices running within a Merritt Stack.

- [Merritt Stack Links and Troubleshooting Documentation](https://github.com/CDLUC3/mrt-doc-private/blob/main/docs/system-recovery/README.md)

## NOTE: For live stacks, this will be replaced with a support page

## Merritt Admin Tool Features
- Query the Merritt Inventory and Billing Databases
  - Generate and save "large" reports to a report bucket
- Trigger updates to the Merritt Billing Database to generate daily statistics and to peform daily consistency checks
- View ZooKeeper Queue Items
- View Merritt LDAP Users and Permissions
- Create Merritt Owners and Collections
  - Generate Merritt Collection Profiles
  - Merritt Collection Profiles are managed in GitHub and then published to S3 for runtime use
  - Configure storage nodes associated with a collection
- View Merritt resources in AWS ECR and AWS CodeArtifact (Dev Stack Only)
  - Delete obsolete images and artifacts
- View services running within an ECS Stack
  - Restart services
  - Trigger auto-scaling of services
  - Initiate ECS Tasks to perform discrete actions (vs long-running services)
  - View AWS resources associated with a stack (Dev Stack Only)
- Merritt Operational Actions
  - Make service calls to Merritt microservices
  - Requeue Audit and Replication Tasks
  - Re-queue and delete ZooKeeper Queue Items
- In a Development Environment, trigger particular test cases in a Merritt Stack
  - Create a baseline set of collections in an empty Merritt Stack
  - Trigger the ingestion of test data into multiple Merritt collections
  - Force ingest queue job failures
  - Force a fixity error
  - Force a storage scan error

## Code Base
- [Admin Tool Code Base: mrt-admin-sinatra](https://github.com/CDLUC3/mrt-admin-sinatra)
- [Merritt Stack Sceptre Resources](https://github.com/CDLUC3/mrt-sceptre/tree/main/mrt-ecs)
- [Merritt Ops Container](https://github.com/CDLUC3/merritt-docker/tree/main/mrt-inttest-services/merritt-ops)



