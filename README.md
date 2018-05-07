# mysql-backup-s3

Backup MySQL to S3

### Env variables:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION`
- `S3_BUCKET`
- `S3_PREFIX`
- `S3_ENDPOINT`

- `MYSQL_HOST`
- `MYSQL_PORT` (default: 3306)
- `MYSQL_USER`
- `MYSQL_PASSWORD`

- `MYSQLDUMP_DATABASE` (default: `--all-databases`) : list of databases you want to backup
- `MYSQLDUMP_OPTIONS` (default: see Dockerfile) : mysqldump options

- `MULTI_FILES` (default: `no`) : Allow to have one file per database if set yes
- `BACKUP_KEEP` (default: `30`) : Number of backup files to keep


### Test and develop:

```bash
docker build -t docker-mysql-backup . && \
docker run --rm -it \
  -e MYSQL_HOST=10.3.29.57 \
  -e MYSQL_PORT=3308 \
  -e MYSQL_USER=root \
  -e MYSQL_PASSWORD="" \
  -e S3_BUCKET=test \
  -e S3_PREFIX=test-server \
  -e AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | awk '/aws_access_key_id = (.*)/{ print $3 }') \
  -e AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | awk '/aws_secret_access_key = (.*)/{ print $3 }') \
  -e MULTI_FILES=true \
  docker-mysql-backup
```

### Credits

- Heavily inspired by https://github.com/schickling/dockerfiles/tree/master/mysql-backup-s3
