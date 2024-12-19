ARG ECR_REGISTRY=ecr_registry_not_set

# This image has been built from an image that matches the Lambda Ruby runtime
# MySql binary dependencies have been embedded into the image

FROM ${ECR_REGISTRY}/mysql-ruby-lambda 

RUN yum -y update && yum clean all

# Add Admin Tool Code to the image
COPY . /var/task/

# Bundle dependencies
RUN bundle install 