## Merritt `docker` Stack

- [Merritt Troubleshooting](https://github.com/CDLUC3/mrt-doc-private/blob/main/docs/system-recovery/README.md)

## Stack Purpose

- This stack is intended to support iterative development of Merritt code.
- This Merritt Stack consists of a container based MySQL database and Minio Cloud storage which will be persisted in docker volumes.
- This stack runs entirely with docker compose and can only support files and objects of limited size.

## URLs

- Admin Tool 
  - http://localhost:8099
- UI 
  - http://localhost:8086
- Stack Services 
  - http://localhost:8086/docker.html

## <a href name="create-ops"></a>Create An OPS session
*[CDL session manager user guide](https://github.com/cdlib/ias-user-guides/blob/main/SessionManager-for-Devs.md)*

*This will create a read/write database connection.  No separate configuration exists for readonly access.*

```
docker compose exec -it merritt-ops /bin/bash
```

### Database Access

```
/merritt-mysql.sh
```

### Storage Bucket Access

- [Storage Configuration Details](/ops/storage/storage-config)


## Code Base
- [Admin Tool Code Base: mrt-admin-sinatra](https://github.com/CDLUC3/mrt-admin-sinatra)
- [Merritt Stack Sceptre Resources](https://github.com/CDLUC3/mrt-sceptre/tree/main/mrt-ecs)
- [Merritt Ops Container](https://github.com/CDLUC3/merritt-docker/tree/main/mrt-inttest-services/merritt-ops)
- [Admin Tool Features](/markdown/features.md)
