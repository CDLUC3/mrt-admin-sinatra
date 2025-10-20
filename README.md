# Merritt Admin Sinatra

This lambda is part of the [Merritt Preservation System](https://github.com/CDLUC3/mrt-doc). 

## Purpose

This web application allows members of the Merritt Team to manage the Merritt Digital Preservation System.

## Application Framework

This application is built on the [sinatra framework](https://sinatrarb.com/intro.html).
- HTTP requests are made to the application
- Requests are matched to a ["route"](app/lib/routes)

Sinatra apps are typically run inside a puma webserver using rack.

Application Configuration
- [Merritt Admin Rack Config](app/config_mrt.ru)
  - [Initialization Code](app/admin_mrt.rb)
- [Main Acct Rack Config](app/config_uc3.ru)
  - [Initialization Code](app/admin_uc3.rb)

### Merritt Admin Tool Framework
- Request handling utilizes an [admin tool client](lib/client) to satisify the request
  - query client: queries the Merritt inventory and billing databases
  - zookeeper client: queries the Merritt queuing system
  - ldap client: queries the Merritt user permission directory
  - code client: queries GitHub, CodeArtifact and Elastic Container Registry for information about Merritt code
- Response are returned to the user
  - some responses are returned to the user in JSON format
  - most responses are returned in the user as HTML, preferable containing a table of data

### Merritt Admin Tool Config Files

#### Menu File

The menu system for the Merritt Admin Tool is configured in a yaml file: [menu.yml](app/config/mrt/menu.yml).

The hierarchy of the menu entries is used to generate breadcrumbs for each page that is displayed in the application.

#### Lookup Files

Merritt configuration is resloved using a lookup file.

The top level keys of the yaml file allow different application configurations to be defined (ecs-prd, ecs-dev, docker).

Lookup values can be resolved in 3 ways
- ssm: ssm lookup, note that this is not appropriate for a docker compose stack
- env: env lookup
- val: hard coded

When running in docker-compose, most values are resolved to a simple hard-coded value.

#### Query Files

- All of the SQL run by the Merritt Admin Tool is defined in a [query yaml file](app/config/mrt/query/).
- Where possible, the keys within the yaml file match the route paths for the application.
- To reduce code repetition, some queries are assembled using [mustache templates](https://github.com/mustache/mustache)
- Some query columns have a special properties that are tied to the [column name](app/config/mrt/query/query.sql.cols.yml)
  - these properties are used to format the column, to create hyperlinks, and to assign CSS classes
- Other queries have a special [query resolver](app/lib/client/query/query_resolvers.rb) that can combine columns or generate action buttons
- The Query definitions map named url parameters to positional parameters in an SQL prepared statement
- A query definition might contain a markdown section that defines the purpose of a particular query

## Admin Tool Deployments

- This application is deployed as a web applications to the 5 Merritt ECS stacks.
  - Merritt team members must authenticate with AWS cognito to access the application.
- This application can be run on a developer desktop using [docker-compose](https://github.com/CDLUC3/merritt-docker/blob/main/README.md).
- A pared down version of this application is also deployed to the CDL "main account" as a lambda.
  - Merritt team members must authenticate with AWS cognito to access the application.
  - Because of the mysql dependency within the application, the lambda code is deployed as a docker image.

## Local Testing

The Merritt Admin tool can be run as a standalone ruby application although the standalone application 
will not be able to connect to other Merritt microservices.

### Merritt app
```
MERRITT_ECS=desktop bundle exec puma app/config_mrt.ru
```

### UC3-focuesed app
```
MERRITT_ECS=desktop bundle exec puma app/config_uc3.ru
```
