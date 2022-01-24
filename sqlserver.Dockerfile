## Source: https://github.com/Microsoft/mssql-docker/blob/master/linux/preview/examples/mssql-agent-fts-ha-tools/Dockerfile

FROM ubuntu:16.04

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -yq curl apt-transport-https && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/16.04/mssql-server-2017.list | tee /etc/apt/sources.list.d/mssql-server.list && \
    apt-get update

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y mssql-server

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y mssql-server-ha

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y mssql-server-fts

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists

ENTRYPOINT [ "/opt/mssql/bin/sqlservr" ]
