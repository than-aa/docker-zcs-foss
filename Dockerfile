FROM ubuntu:16.04

# Install Basic Packages
# Set tzdata info to UTC (Etc/UTC) for image.
# Runtime will reconfigure to match what is in environment
RUN apt-get update && \
    apt-get install -y \
    curl \
    dnsutils \
    gettext \
    linux-tools-common \
    openssh-client \
    netbase \
    net-tools \
    rsyslog \
    software-properties-common \
    vim \
    wget && \
    apt-get install -y man psutils psmisc ruby-dev gcc && \
    echo "tzdata tzdata/Areas select Etc" > /tmp/tzdata.txt && \
    echo "tzdata tzdata/Zones/Etc select UTC" >> /tmp/tzdata.txt && \
    export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
    debconf-set-selections /tmp/tzdata.txt && \
    apt-get install -y tzdata && \
    apt-get clean

# ************************************************************************
# The following is required for Genesis tests to be run.
# NOTE: Work is in progress to allow for remote test execution
# 1. Disable setting that prevents users from writing to current terminal device 
# 2. Symlink in /bin/env (some genesis tests expect it to be there)
# 3. Pre-create the zimbra user with known uid/gid so that IF a user wants to mount a host
# 4. directory into the container, the permissions will be correct.
# ************************************************************************
RUN sed -i.bak 's/^mesg/# mesg/' /root/.profile && \
    ln -s /usr/bin/env /bin/env && \
    groupadd -r -g 1000 zimbra && \
    useradd -r -g zimbra -u 1000 -b /opt -s /bin/bash zimbra

# ************************************************************************
# Download and do a package-only install of Zimbra
# Trick build into skipping resolvconf as docker overrides for DNS
# This is currently required by our installer script. Hopefully be
# fixed soon.  The `zimbra-os-requirements` packages depends
# on the `resolvconf` package, and configuration of that is what
# was breaking install.sh
# ************************************************************************
COPY ./slash-zimbra /zimbra
RUN curl -s -k -o /tmp/zcs.tgz 'https://files.zimbra.com.s3.amazonaws.com/downloads/8.8.3_GA/zcs-8.8.3_GA_1872.UBUNTU16_64.20170905143325.tgz' && \
    mkdir -p /tmp/release && \
    tar xzvf /tmp/zcs.tgz -C /tmp/release --strip-components=1 && \
    rm /tmp/zcs.tgz && \
    echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections

WORKDIR /tmp/release
RUN sed -i.bak 's/checkRequired/# checkRequired/' install.sh && \
    ./install.sh -s -x --skip-upgrade-check < /zimbra/software-install-responses && \
    apt-get clean && \
    rm -rf /tmp/release

EXPOSE 22 25 80 110 143 443 465 587 993 995 7071 8443
