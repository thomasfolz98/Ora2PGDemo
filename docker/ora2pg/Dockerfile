FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Grundlegende Pakete und PostgreSQL-Treiber installieren
RUN apt-get update && apt-get install -y \
    perl \
    libdbi-perl \
    libdbd-pg-perl \
    make \
    wget \
    unzip \
    curl \
    gcc \
    libaio1 \
    systemtap-sdt-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Oracle Instant Client (Linux x64) installieren
WORKDIR /opt/oracle
RUN wget https://download.oracle.com/otn_software/linux/instantclient/2112000/instantclient-basiclite-linux.x64-21.12.0.0.0dbru.zip && \
    wget https://download.oracle.com/otn_software/linux/instantclient/2112000/instantclient-sdk-linux.x64-21.12.0.0.0dbru.zip && \
    unzip instantclient-basiclite-linux.x64-21.12.0.0.0dbru.zip && \
    unzip instantclient-sdk-linux.x64-21.12.0.0.0dbru.zip && \
    rm *.zip && \
    echo /opt/oracle/instantclient_21_12 > /etc/ld.so.conf.d/oracle-instantclient.conf && \
    ldconfig

# Umgebungsvariablen für Oracle setzen
ENV ORACLE_HOME=/opt/oracle/instantclient_21_12
ENV LD_LIBRARY_PATH=/opt/oracle/instantclient_21_12

# 3. Oracle Perl DBD und Ora2Pg (sicher über Source) installieren
RUN cpan -T DBD::Oracle && \
    curl -L -o ora2pg.tar.gz https://github.com/darold/ora2pg/archive/refs/tags/v24.0.tar.gz && \
    tar xzf ora2pg.tar.gz && \
    cd ora2pg-24.0 && \
    perl Makefile.PL && \
    make && make install && \
    cd .. && rm -rf ora2pg*

WORKDIR /config

# Container am Leben erhalten, damit wir Befehle darin ausführen können
CMD ["tail", "-f", "/dev/null"]