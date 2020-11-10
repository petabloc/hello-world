# Hello World

For use as a test bed when working on CircleCi deployments. Can be extended to act as a reference application.

Currently this just uses the latest nginx container and copies any files in src/html into the html/ folder on the image.

# Details

Once published the site should be available to you for


# CircleCi

## Overview

Circle CI will do the following actions:

* build-pr - builds any branch not labelled "master"
* build-dev - builds only branch labelled "master"
* build-prod - builds anything tagged with the prefix "prod"


If you reference .circleci/config.yml you will find various stanzas


NOTE circleci filters are inclusive rather than exclusive so if you have a filter that says only if x only if y and one is true circleci will still perform the action (or think of it as OR instead of AND).

### Filtering

filtering is used to determine when to build and where to deploy to.

In this example only something tagged with "prod" will build

```yaml
filters:
  tags:
    only: /^prod.*/
  branches:
    ignore: /.*/
```
### Deploying

In order to deploy a ECS service you will need to have pre-requisites in place.  These are created via Terraform and you can find examples for this application

Module:
Service:

Additionally a manually created route53 DNS name was made for this application

Once pre-reqs are done you will need to produce via CircleCi:

* A docker container uploaded to an ECR repository
* A new ECS Task Definition
* A call to AWS Code Deploy to use the new task definition

This is performed in three distinct blocks:

```yaml
build_prod:
  docker:
    - image: 'circleci/python:latest'
  steps:
    - checkout
    - setup_remote_docker:
        docker_layer_caching: true
    - aws-ecr/build-and-push-image:
        create-repo: true
        repo: ${APP_NAME}
        path: .
        dockerfile: Dockerfile
        tag: 'prod-latest,${CIRCLE_SHA1},${CIRCLE_TAG}'
        aws-access-key-id: SHARED_KEY_ID
        aws-secret-access-key: SHARED_ACCESS_KEY

update-service-prod-hello-world:
  docker:
    - image: 'circleci/python:latest'
  steps:
    - aws-cli/install
    - aws-cli/setup:
        aws-access-key-id: PROD_KEY_ID
        aws-secret-access-key: PROD_ACCESS_KEY
        aws-region: PROD_REGION
    - aws-ecs/update-service:
        family: ${APP_NAME}
        cluster-name: ${PROD_ECS_CLUSTER}
        service-name: ${APP_NAME}
        deployment-controller: CODE_DEPLOY
        codedeploy-application-name: ${APP_NAME}
        codedeploy-deployment-group-name: ${APP_NAME}
        codedeploy-load-balanced-container-name: ${APP_NAME}

update-task-json-prod-hello-world:
  docker:
    - image: 'circleci/python:latest'
  steps:
    - checkout
    - run: sudo apt-get install -y sed
    - run: sed -i "s/CIRCLECIGIT/${CIRCLE_TAG}/" prod-hello-world.json
    - aws-cli/install
    - aws-cli/setup:
        aws-access-key-id: PROD_KEY_ID
        aws-secret-access-key: PROD_ACCESS_KEY
        aws-region: PROD_REGION
    - aws-ecs/update-task-definition-from-json:
        task-definition-json: prod-${APP_NAME}.json
```