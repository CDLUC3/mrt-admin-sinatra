## Merritt Builds for ECS

- [View as Slides](https://merritt.uc3dev.cdlib.org/present/ecs-deploy/build.html#/)
- [Presentation Source](https://github.com/CDLUC3/mrt-admin-sinatra/blob/main/present/deploy/build.md)
---

## Goal: Create a feature Branch for Merritt UI, Depoloy to ECS Dev

----

## Create feature branch `sample-feature`

----

![Screenshot of the GitHub website showing that a branch named 'sample-feature' exists for the repository 'CDLUC3/mrt-dashboard'](images/create-branch.png)

----

### CodeBuild runs in the background...
- image mrt-dashboard:sample-feature pushed to ECR

----

## In the Admin Tool, view Repository Images for Merritt UI

- since this is not associated with a tag, we must view the image listing

----

![Merritt Admin Tool Screenshot listing the images associated with the 'UI' Service.  Within this list are tags named 'dev', 'sample-feature' and 'ecs-prd'.  Next to the imaged named 'sample-feature' is a button with the name 'Tag ecs-dev'.](images/images-branch.png)

----

### Click `Tag ecs-dev`

----

![Merritt Admin Tool Screenshot that was previously described.  Overlaying that screenshot is a popup message that reads 'Regagged: mrt-dashbord for tag sample-feature --> ecs-dev'.](images/tag-ecs-dev.png)

----

### Reload Page

----

Note that a second tag has been assigned to the image
![Merritt Admin Tool Screenshot listing the images associated with the 'UI' Service.  Within this list are tags named 'dev', 'sample-feature', 'ecs-dev' and 'ecs-prd'.](images/tagged-ecs-dev.png)

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

![Merritt Admintool Screenshot listing Git Tags associated with the service 'UI'.  Tags are listed in descending order.  The list of tags incluces '1.7.9', '1.7.8', '1.7.7', '1.7.6', '1.7.5'.  Tags 1.7.9 and 1.7.8 have an associated ECR Image named 'mrt-dashboard'.  The tag named '1.7.9' has Actions buttons named 'Delete images', 'Tag ecs-dev', and 'Tag ecs-stg'.](images/tags-1.7.9.png)

----

### Click `Tag ecs-stg`

----

![Merritt Admin Tool screenshot previously described along with a popup message that reads 'Retagged: mrt-dashboard for tag 1.7.9 --> ecs-stg'.](images/tag-ecs-stg.png)

----

### Reload Page

----

![Merritt Admintool Screenshot listing Git Tags associated with the service 'UI'. The entry for tag 1.7.9 now has a Matching Tag named 'ecs-stg'.  The associate d Actions buttons now read 'Tag ecs-dev' and 'Untag ecs-stg'](images/tagged-ecs-stg.png)

---

## Goal: Deploy to to ECS Prod

----

### Proposal: Require a documented "Release" for Production Deployments

----

Note that 1.7.9 does not have a documented release
![Merritt Admintool Screenshot listing Git Tags associated with the service 'UI'.  Tags are listed in descending order.  The list of tags incluces '1.7.9', '1.7.8', '1.7.7', '1.7.6'.  For tag 1.7.9 under the column named 'Documented Release', a button 'Create' exists.](images/tagged-ecs-stg.png)

----

### Click `Create` to document a release on GitHub

----

![Screenshot of the GitHub website page to create and describe a Release for tag '1.7.9' for the repository 'CDLUC3/mrt-dashboard'.  A description field contains the text 'Sample Release for Documentation Purposes'.](images/create-release.png)

----

### Scroll and Click `Publish Release`

----

![PScreenshot of the GitHub website page for release tag '1.7.9' for the repository 'CDLUC3/mrt-dashboard'.  The release has a title that reads 'Sample Release for Documentation Purposes'.](images/publish-release.png)

----

### Return to the Repository Tag listing

----

Note the published release info
![Merritt Admintool Screenshot listing Git Tags associated with the service 'UI'.  Tags are listed in descending order.  The list of tags incluces '1.7.9', '1.7.8', '1.7.7', '1.7.6'.  For tag 1.7.9 under the column named 'Documented Release', a hyperlink with the title 'Sample Release for Documentation Purposes' exists.  The Actions column of the table now contains an additional button named 'Tag ecs-prd'](images/1.7.9-published.png)

----

### Click `Tag ecs-prd`

----

![Overlaying the prior screenshot, there is now a popup message that reads 'Retagged: mrt-dashboard for tag 1.7.9 --> ecs-prd'](images/tag-ecs-prd.png)

----

### Reload Page

----

Note that the ecs-prd image has migrated
![Merritt Admintool Screenshot listing Git Tags associated with the service 'UI'.  Tags are listed in descending order.  The list of tags incluces '1.7.9', '1.7.8', '1.7.7', '1.7.6'.  For tag 1.7.9, the associated Actions buttons now read 'Tag ecs-dev', 'Untag ecs-stg' and 'Untag ecs-prd'.](images/tagged-ecs-prd.png)

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
- mrt-dashboard:1.7.9-docker-250424 is published to ECR

----

- Merritt Admin Tool will need to know that this is an image that we derived from tag 1.7.9
- User will have the ability to re-tag the image with ecs-stg or ecs-prd
