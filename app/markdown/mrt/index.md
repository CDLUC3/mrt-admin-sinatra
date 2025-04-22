# Merritt Admin Tool

This version of the Merritt Admin Tool is designed to run in the CDL UC3 account.

How does this differ from the original Merritt Admin Tool?

- The original admin tool was originally developed to deliver static reports.
  - The original tool only ran as a lambda.
- This tool has been build as a web service alongside other Merritt services.
- This tool can be run in multiple ways
  - Web service running in an ECS stack of Merritt services
  - Web service running in a Docker compose stack of Merritt services
  - As a lambda (will be deprecated in the future, features depend on VPC placement)
  - As a standanlone ruby web service running on a desktop (AWS authentication required)

What Merritt features are required to run this application?
- For collection creation
  - Collection profiles will be accesible to the Admin Tool via an S3 bucket
  - Submission of Admin objects will no longer be supported.  Direct calls will be made to inventory endpoints.

## Code Base
- [mrt-admin-sinatra](https://github.com/CDLUC3/mrt-admin-sinatra)
- [sceptre resources](https://github.com/CDLUC3/mrt-sceptre/tree/main/mrt-admin-sinatra)

