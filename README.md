# Merritt Admin Sinatra

This lambda is part of the [Merritt Preservation System](https://github.com/CDLUC3/mrt-doc). 

## Purpose

Sinatra based admin tool for the new Merritt AWS account.

## Local Testing

```
bundle exec puma app/config.ru
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