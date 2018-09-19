#!/bin/sh

set -e

time_start=`date +%s`

if [ "${S3_BUCKET}" == "" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi
if [ "${MYSQL_HOST}" == "" ]; then
  echo "You need to set the MYSQL_HOST environment variable."
  exit 1
fi
if [ "${MYSQL_USER}" == "" ]; then
  echo "You need to set the MYSQL_USER environment variable."
  exit 1
fi

MYSQL_HOST_OPTS="-h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER"
DUMP_START_TIME=$(date +"%Y-%m-%dT%H%M%SZ")

if [ "${MYSQL_PASSWORD}" != "" ]; then
  MYSQL_HOST_OPTS="$MYSQL_HOST_OPTS -p$MYSQL_PASSWORD"
fi

if [ "${S3_ENDPOINT}" == "" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi

mysqldump="nice -n 10 ionice -c2 -n7 /usr/bin/mysqldump"
gzip="nice -n +10 ionice -c3 gzip"

copy_s3 () {
  SRC_FILE=$1
  DEST_FILE=$2

  echo "Uploading ${DEST_FILE} on S3..."
  cat $SRC_FILE | aws $AWS_ARGS s3 cp - s3://$S3_BUCKET/$S3_PREFIX/$DEST_FILE

  if [ $? != 0 ]; then
    >&2 echo "Error uploading ${DEST_FILE} on S3"
  fi

  rm $SRC_FILE
}

clean_s3 () {
  PREFIX=$1

  files=$(aws $AWS_ARGS s3 ls s3://$S3_BUCKET/$S3_PREFIX/$PREFIX | awk '{print $4}' | sort)
  filesToKeep=$(echo "$files" | tail -n $BACKUP_KEEP)

  echo "$files" | while read -r line;  do
    if [ "${line}" == "" ]; then
      continue
    fi

    if echo $filesToKeep | grep -w $line > /dev/null; then
      echo "Backup to keep: $line"
    else
      echo "Backup to delete: $line"
      aws $AWS_ARGS s3 rm s3://$S3_BUCKET/$S3_PREFIX/$PREFIX$line
    fi
  done;
}

# Multi file: yes
if [ ! -z "$(echo $MULTI_FILES | grep -i -E "(yes|true|1)")" ]; then
  if [ "${MYSQLDUMP_DATABASE}" == "--all-databases" ]; then
    DATABASES=`mysql $MYSQL_HOST_OPTS -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys|innodb)"`
  else
    DATABASES=$MYSQLDUMP_DATABASE
  fi

  for DB in $DATABASES; do
    echo "Creating individual dump of ${DB} from ${MYSQL_HOST}:${MYSQL_PORT}..."

    DUMP_FILE_TMP="/tmp/${DB}.sql"
    DUMP_FILE="$DUMP_FILE_TMP.gz"

    $mysqldump $MYSQL_HOST_OPTS $MYSQLDUMP_OPTIONS --databases $DB > $DUMP_FILE_TMP
    du -sh $DUMP_FILE_TMP
    if [ "${DISABLE_GZIP}" == "" ]; then
      cat $DUMP_FILE_TMP | $gzip > $DUMP_FILE
    else
      cp $DUMP_FILE_TMP $DUMP_FILE
    fi
    du -sh $DUMP_FILE

    if [ $? == 0 ]; then
      S3_FILE="${DB}/${DUMP_START_TIME}.${DB}.sql"
      if [ "${DISABLE_GZIP}" == "" ]; then
        S3_FILE="$S3_FILE.gz"
      fi

      copy_s3 $DUMP_FILE $S3_FILE
      clean_s3 "${DB}/"
    else
      >&2 echo "Error creating dump of ${DB}"
    fi
  done
# Multi file: no
else
  echo "Creating dump for ${MYSQLDUMP_DATABASE} from ${MYSQL_HOST}:${MYSQL_PORT}..."

  DUMP_FILE_TMP="/tmp/dump.sql"
  DUMP_FILE="$DUMP_FILE_TMP.gz"

  $mysqldump $MYSQL_HOST_OPTS $MYSQLDUMP_OPTIONS $MYSQLDUMP_DATABASE > $DUMP_FILE_TMP
  du -sh $DUMP_FILE_TMP
  if [ "${DISABLE_GZIP}" == "" ]; then
    cat $DUMP_FILE_TMP | $gzip > $DUMP_FILE
  else
    cp $DUMP_FILE_TMP $DUMP_FILE
  fi
  du -sh $DUMP_FILE

  if [ $? == 0 ]; then
    S3_FILE="${DUMP_START_TIME}.dump.sql"
    if [ "${DISABLE_GZIP}" == "" ]; then
      S3_FILE="$S3_FILE.gz"
    fi

    copy_s3 $DUMP_FILE $S3_FILE
    clean_s3
  else
    >&2 echo "Error creating dump of all databases"
  fi
fi

time_end=`date +%s`
time_diff=`expr $time_end - $time_start`

echo "SQL backup finished in $time_diff seconds"
