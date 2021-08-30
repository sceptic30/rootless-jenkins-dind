FROM adoptopenjdk/openjdk11:jdk-11.0.11_9-alpine

RUN set -eux \
  && apk --no-cache update \
  && apk --no-cache upgrade --available \
  && apk --no-cache add \
  bash \
  coreutils \
  curl \
  git \
  openssh-client \
  tini \
  ttf-dejavu \
  tzdata \
  unzip \
  docker

ARG TARGETARCH
ARG GIT_LFS_VERSION=2.13.3

# required for multi-arch support, revert to package cloud after:
# https://github.com/git-lfs/git-lfs/issues/4546
RUN GIT_LFS_ARCHIVE="git-lfs-linux-$TARGETARCH-v$GIT_LFS_VERSION.tar.gz" \
    GIT_LFS_RELEASE_URL="https://github.com/git-lfs/git-lfs/releases/download/v$GIT_LFS_VERSION/$GIT_LFS_ARCHIVE"\
    set -x; curl --fail --silent --location --show-error --output "/tmp/$GIT_LFS_ARCHIVE" "$GIT_LFS_RELEASE_URL" && \
    mkdir -p /tmp/git-lfs && \
    tar xzvf "/tmp/$GIT_LFS_ARCHIVE" -C /tmp/git-lfs && \
    bash -x /tmp/git-lfs/install.sh && \
    rm -rf /tmp/git-lfs*

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1001
ARG http_port=8080
ARG agent_port=50000
ARG JENKINS_HOME=/var/jenkins_home
ARG REF=/usr/share/jenkins/ref

ENV JENKINS_HOME $JENKINS_HOME
ENV JENKINS_SLAVE_AGENT_PORT $agent_port
ENV REF $REF

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
RUN set -eux \
  && mkdir -p $JENKINS_HOME \
  && chown $uid:$gid $JENKINS_HOME \
  && addgroup -g $gid $group \
  && adduser -h "$JENKINS_HOME" -u $uid -G $group -s /bin/bash -D $user
  #&& chmod +x install-plugins.sh jenkins-support jenkins.sh tini-shim.sh jenkins-plugin-cli.sh

# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
VOLUME $JENKINS_HOME

# $REF (defaults to `/usr/share/jenkins/ref/`) contains all reference configuration we want
# to set on a fresh new installation. Use it to bundle additional plugins
# or config file with your custom jenkins Docker image.
RUN mkdir -p $REF/init.groovy.d

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.308}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=6a5897ac7e8e16a3eecef5fa372b40789e4d34380284eb16980a5d1140c93e43
# Obtained from https://updates.jenkins-ci.org/download/war/ (SHA-256)

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL $JENKINS_URL -o /usr/share/jenkins/jenkins.war \
  && echo "$JENKINS_SHA  /usr/share/jenkins/jenkins.war" | sha256sum -c -

ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
ENV JENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementals
RUN chown -R $user "$JENKINS_HOME" "$REF"

ARG PLUGIN_CLI_VERSION=2.10.2
ARG PLUGIN_CLI_URL=https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/${PLUGIN_CLI_VERSION}/jenkins-plugin-manager-${PLUGIN_CLI_VERSION}.jar


COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
COPY tini-shim.sh /bin/tini
COPY jenkins-plugin-cli.sh /bin/jenkins-plugin-cli
COPY install-plugins.sh /usr/local/bin/install-plugins.sh

RUN curl -fsSL ${PLUGIN_CLI_URL} -o /opt/jenkins-plugin-manager.jar \
    && chown $uid:$gid /usr/local/bin/jenkins-support \
    && chown $uid:$gid /usr/local/bin/jenkins.sh \
    && chown $uid:$gid /bin/tini \
    && chown $uid:$gid /bin/jenkins-plugin-cli \
    && chown $uid:$gid /usr/local/bin/install-plugins.sh

# for main web interface:
EXPOSE ${http_port}

# will be used by attached agents:
EXPOSE $agent_port
ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log
USER $user
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]
