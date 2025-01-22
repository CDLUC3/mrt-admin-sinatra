ARG ECR_REGISTRY=ecr_registry_not_set

# This image has been built from an image that matches the Lambda Ruby runtime
# MySql binary dependencies have been embedded into the image

FROM ${ECR_REGISTRY}/mysql-ruby-lambda

ENV RACK_CONFIG=app/config_mrt.ru

RUN dnf -y update && \
    dnf -y install gcc-c++ make tar patch && \
    dnf clean all

# Add Admin Tool Code to the image
COPY . /var/task/
COPY .bundle/config.docker /var/task/.bundle/config

# Bundle dependencies
WORKDIR /var/task/
RUN bundle install