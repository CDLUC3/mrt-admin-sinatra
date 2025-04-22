## Ruby Services - Git Tagging Conventions
Merritt Ruby code is published to ECR. CodeArtifact is not utilized.

- `main` branch
  - tagged as `subservice:dev` in ECR
  - auto deployed to DEV ECS
- `branch` branch
  - tagged as `subservice:branch` in ECR
- `tag` tag
  - tagged as `subservice:tag` in ECR

## Ruby Serivces - Image Tagging Conventions
_⚠️ This is not yet implemented_

When the underlying image for a published service is updated, the following will be created in ECR.

- Docker Image Patched After Code Deployment of tag `tag`
  - `subservice:tag-MMDD`
- Docker Image Tagged for ECS Deployment
  - `subservice:ecs-dev`
  - `subservice:ecs-stg`
  - `subservice:ecs-prd`

