FROM alpine:3.7

RUN apk add --no-cache mysql-client python py-pip && \
    pip install awscli && \
    apk del py-pip

ENV MYSQL_PORT=3306
ENV MYSQLDUMP_OPTIONS="--quote-names --quick --add-drop-table --add-locks --allow-keywords --disable-keys --extended-insert --single-transaction --create-options --comments --net_buffer_length=16384"
ENV MYSQLDUMP_DATABASE=--all-databases
ENV BACKUP_KEEP=30

ADD docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]
