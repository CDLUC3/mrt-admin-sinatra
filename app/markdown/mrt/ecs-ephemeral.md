## Merritt `ecs-ephemeral` Stack

## Stack Purpose

- This Merritt Stack consists of a container based MySQL database and Minio Cloud storage that is recreated on every restart.
- The primary purpose of this stack is to test initialization and recovery of a Merritt instance.
- The user interface for this stack requires Merritt Team AWS SSO access.
- This stack is only started on demand is infrequenty used.

## Code Base
- [Admin Tool Code Base: mrt-admin-sinatra](https://github.com/CDLUC3/mrt-admin-sinatra)
- [Merritt Stack Sceptre Resources](https://github.com/CDLUC3/mrt-sceptre/tree/main/mrt-ecs)
- [Merritt Ops Container](https://github.com/CDLUC3/merritt-docker/tree/main/mrt-inttest-services/merritt-ops)
- [Admin Tool Features](/markdown/features.md)
