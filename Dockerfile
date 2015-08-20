FROM ubuntu:14.04
MAINTAINER jerome.petazzoni@docker.com

# Let's start with some basic stuff.
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        lxc \
        iptables \
        && \
    apt-get clean
    
# Install Docker from Docker Inc. repositories.
RUN curl -sSL https://get.docker.com/ubuntu/ | sh

# Install the magic wrapper.
ADD ./wrapdocker /usr/local/bin/wrapdocker
RUN chmod +x /usr/local/bin/wrapdocker

# Define additional metadata for our image.
VOLUME /var/lib/docker
CMD ["wrapdocker"]

