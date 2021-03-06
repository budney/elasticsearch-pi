FROM debian:latest
LABEL maintainer="Len Budney (len.budney@gmail.com)"

USER root

# Working directory
WORKDIR /tmp

# Copy the enytrypoint script over
COPY entrypoint.sh /
COPY elasticsearch-classpath-patch.txt elasticsearch.yml.append ./

# Intall utilities
RUN \
    apt update && \
    apt install -y --autoremove wget apt-transport-https gnupg patch openjdk-11-jre-headless && \
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -

# Fetch the files we need
RUN \
    wget -q https://repo1.maven.org/maven2/net/java/dev/jna/jna/5.5.0/jna-5.5.0.jar && \
    wget -q https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.10.1-no-jdk-amd64.deb

# Install and patch elasticsearch
RUN \
    addgroup --system --gid 1001 elasticsearch && \
    adduser --system --no-create-home --home / --shell /bin/true --uid 1001 --disabled-password elasticsearch && \
    ( dpkg -i --force-all --ignore-depends=libc6 elasticsearch*.deb || /bin/true ) && \
    sed -i -e '/^Depends:.*libc6,/s/libc6, //' /var/lib/dpkg/status && \
    ln -s $(dirname $(dirname $(readlink -f $(which java)))) /usr/share/elasticsearch/jdk && \
    dpkg --configure elasticsearch && \
    ( cd /usr/share/elasticsearch; patch -p0 < /tmp/elasticsearch-classpath-patch.txt; ) && \
    cp jna-5.5.0.jar /usr/share/elasticsearch/lib/ && \
    sed --in-place -e '/^9/s/^/#/' /etc/elasticsearch/jvm.options && \
    cat elasticsearch.yml.append >> /etc/elasticsearch/elasticsearch.yml && \
    mkdir -p /var/share/elasticsearch/data && \
    chown -R elasticsearch /etc/default/elasticsearch /etc/elasticsearch /var/share/elasticsearch

# Clean up! Remove stuff we used for the build, and some packages we can survive without
RUN \
    apt purge -y --autoremove wget apt-transport-https gnupg patch \
        iproute2 libelf1 dbus krb5-locales libapparmor1 libxtables12 \
        iputils-ping libcap2-bin libcap2 libmnl0 && \
    apt clean


# Run docker on startup
WORKDIR /
EXPOSE 9200
EXPOSE 9300
ENTRYPOINT ["/entrypoint.sh"]

