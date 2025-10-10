# Merritt Admin Sinatra

This lambda is part of the [Merritt Preservation System](https://github.com/CDLUC3/mrt-doc). 

## Purpose

Sinatra based admin tool for the new Merritt AWS account.

## Execution Options

- Local ruby app (bundle exec, NO AWS auth)
  - NO AWS API support
  - NO local database
  - NO VPC database connections (uc3)
- Local ruby app (bundle exec, WITH AWS auth)
  - NO AWS API support
  - NO local database
  - NO VPC database connections (uc3)
- Local docker-compose stack (AWS auth does not transfer to containers)
  - NO AWS API support
  - HAS local database
  - NO VPC database connections (uc3)
- ECS Stack
  - HAS local database or VPC database connection (vpc)
  - HAS AWS API support
- Lambda (VPC + NonVPC)
  - NO local databse
  - HAS VPC database connection (main account)

## Local Testing

### Merritt app
```
MERRITT_ECS=x bundle exec puma app/config_mrt.ru
```

Resources for deploying as a lambda
- https://github.com/CDLUC3/mrt-sceptre/tree/main/mrt-admin-sinatra
- Because this application uses mysql, it must be packaged as a docker image
- `ENV RACK_CONFIG=app/config_mrt.ru`

### UC3-focuesed app
```
MERRITT_ECS=x bundle exec puma app/config_uc3.ru
```

Resources for deploying as a lambda
- a new sceptre deploy will need to be created to grant a different SSO group access
- this could be deployed as a zip or as an image
- `ENV RACK_CONFIG=app/config_uc3.ru`

Building on EC2 in the main account... warning, this may break lambda deployment
```
bundle config set force_ruby_platform true
```

## Domains
- PROD: 
  - RDS: prod; S3: prod; ZK: prod; ZFS: prod
  - Stack: prod (includes auto-scaling group services)
- Stage: 
  - RDS: stage; S3: prod; ZK: stage; ZFS: stage
  - Stack: stage (includes auto-scaling group services)
- Dev: new dev environment - daily deploy - daily CI/CD
  - RDS: dev; S3: dev; ZK: dev; ZFS: dev
  - Stack: dev (containers)
- Dev DB: uses clone of RDS prod
  - RDS: dev (prod clone); S3: docker volume; ZK: docker volume; ZFS: docker volume
  - Stack: dev (containers)
- Docker
  - RDS: dev docker volume; S3: docker volume; ZK: docker volume; ZFS: docker volume
  - Stack: dev (containers)

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


