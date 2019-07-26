#!/bin/bash

# Based on https://gist.github.com/2206527

# Be pretty
echo -e " "
echo -e " .  ____  .    ______________________________"
echo -e " |/      \|   |                              |"
echo -e "[| \e[1;31m♥    ♥\e[00m |]  | S3 Mongo Backup Script v.0.1 |"
echo -e " |___==___|  /                © B.J 2019     |"
echo -e "              |______________________________|"
echo -e " "

PATH=/usr/bin:/usr/local/bin:/bin

# configuration home path
export CONFIG_HOME=/usr/services/eyesmedia/shell/s3mongobackup.conf
echo "configuration home path ${CONFIG_HOME}"

echo "Reading s3mongobackup.conf...." >&2
if [ -f "${CONFIG_HOME}/s3mongobackup.conf" ]; then
   echo "Got ${CONFIG_HOME}/s3mongobackup.conf" >&2
   source ${CONFIG_HOME}/s3mongobackup.conf
else
   echo "${CONFIG_HOME}/s3mongobackup.conf not found." >&2
   exit 1
fi

# Timestamp (sortable AND readable)
stamp=`date +"%s-%Y%m%d%H%M%S"`

# Feedback
echo -e "Dumping to \e[1;32m$bucket/$stamp/\e[00m"

# Loop the databases
for db in ${databases[@]}; do

  # Define our filenames
  filename="$stamp-$db.gz"
  tmpfile="/data/db/backup/$filename"
  object="$bucket/$stamp/$filename"

  # Feedback
  echo -e "\e[1;34m$db\e[00m"

  # Dump and zip
  echo -e "  creating \e[0;35m$tmpfile\e[00m"
  docker exec -it "$instanceId" mongodump --archive="$tmpfile" --gzip --username root --password $passwd --db $db --authenticationDatabase admin

  # Upload
  echo -e "  uploading..."
  aws s3 cp "/usr/services/data/mongodb/backup/$filename" "$object" --region $bucketregion

  # Delete
  rm -f "/usr/services/data/mongodb/backup/$filename"

done;