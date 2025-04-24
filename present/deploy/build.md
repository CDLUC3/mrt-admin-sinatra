## Merritt Builds for ECS

- [Presentation](https://merritt.uc3dev.cdlib.org/present/ecs-deploy/build.html#/)
- [Presentation Source](https://github.com/CDLUC3/mrt-admin-sinatra/blob/main/present/deploy/build.md)
---

## Goal: Create a feature Branch for Merritt UI, Depoloy to ECS Dev

----

## Create feature branch `sample-feature`

----

![Create Branch Screenshot](images/create-branch.png)

----

### CodeBuild runs in the background...
- image mrt-dashboard:sample-feature pushed to ECR

----

## In the Admin Tool, view Repository Images for Merritt UI

- since this is not associated with a tag, we must view the image listing

----

![Image Listing showing branch Screenshot](images/images-branch.png)

----

### Click `Tag ecs-dev`

----

![Tag ecs-dev Screenshot](images/tag-ecs-dev.png)

----

### Reload Page

----

Note that a second tag has been assigned to the image
![Tagged ecs-dev Screenshot](images/tagged-ecs-dev.png)

---

## Goal: Tag current code in Git in prepraration for deployment to Stage

----

By Merritt conventions, only tagged branches should be deployed to stage or prod

----

## Tag Git Branch with `1.7.9`

----

```
$ git tag 1.7.9
$ git push --tags
Total 0 (delta 0), reused 0 (delta 0), pack-reused 0
To github.com:CDLUC3/mrt-dashboard
 * [new tag]           1.7.9 -> 1.7.9
```

----

### CodeBuild Runs in the background...
- mrt-dashboard:1.7.9 is pushed to ECR

----

## View Repository Tags for Merritt UI

----

![View Tags including 1.7.9 Screenshot](images/tags-1.7.9.png)

----

### Click `Tag ecs-stg`

----

![Tag 1.7.9 with ecs-stg Screenshot](images/tag-ecs-stg.png)

----

### Reload Page

----

![1.7.9 tagged with ecs-stg Screenshot](images/tagged-ecs-stg.png)

---

## Goal: Deploy to to ECS Prod

----

### Proposal: Require a documented "Release" for Production Deployments

----

Note that 1.7.9 does not have a documented release
![Tag Listing Screenshot](images/tagged-ecs-stg.png)

----

### Click `Create` to document a release on GitHub

----

![Create Release 1.7.9 Screenshot](images/create-release.png)

----

### Scroll and Click `Publish Release`

----

![Publish Release 1.7.9 Screenshot](images/publish-release.png)

----

### Return to the Repository Tag listing

----

Note the published release info
![Tag 1.7.9 has a published release Screenshot](images/1.7.9-published.png)

----

### Click `Tag ecs-prd`

----

![Tag 1.7.9 as ecs-prd Screenshot](images/tag-ecs-prd.png)

----

### Reload Page

----

Note that the ecs-prd image has migrated
![1.7.9 tagged as ecs-prd Screenshot](images/tagged-ecs-prd.png)

---

## Goal: Rebuild docker image for unchanged code (Proposal)

----

In order to stay on top of image vulnerabilities, docker images should be republished weekly or monthly

----

## Trigger a CodePipeline to rebuild images (not artifacts) for a published tag

----

## A new pipeline will be needed

- Parameters
  - tag name
  - build suffix

----

### CodeBuild runs in the background
- mrt-dashboard:1.7.9-042425 is published to ECR

----

- Merritt Admin Tool will need to know that this is an image that we derived from tag 1.7.9
- User will have the ability to re-tag the image with ecs-stg or ecs-prd
