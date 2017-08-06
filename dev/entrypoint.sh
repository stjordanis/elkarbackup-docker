#! /bin/bash

if [ ! -n "${MYSQL_ROOT_PASSWORD}" ] && [ ! -n "${EB_DB_PASSWORD}" ] ;then
  echo >&2 'error: unknown database root password'
  echo >&2 '  You need to specify MYSQL_ROOT_PASSWORD or EB_DB_PASSWORD'
  exit 1
fi

# Check database connection
until mysqladmin ping -h "${EB_DB_HOST:=db}" --silent; do
  >&2 echo "MySQL is unavailable - sleeping"
  sleep 1
done

EB_PATH=${EB_PATH:=/usr/local/elkarbackup}

if [ ! -d "$EB_PATH/app" ];then
  bash -c "$(curl -s https://raw.githubusercontent.com/elkarbackup/elkarbackup/master/install/eb-installer.sh)" -s \
    -v "${EB_VERSION:=dev}" \
    -h "${MYSQL_HOST:=db}" \
    -u "${MYSQL_EB_USER:=elkarbackup}" \
    -p "${MYSQL_EB_PASSWORD:=elkarbackup}" \
    -U "${EB_DB_USERPASSWORD:=root}" \
    -P "${EB_DB_PASSWORD:=changeme}" \
    -y \
    -d
  echo "Restarting apache..."
  service apache2 stop
  
  #Workaround to fix permissions issues (not ready for production)
  cd $EB_PATH
  sed -i '7s/^/umask(000);\n/' app/console
  sed -i '6s/^/umask(000);\n/' web/app.php
  sed -i '10s/^/umask(000);\n/' web/app_dev.php
  $EB_PATH/app/console cache:clear --env=prod
fi

/usr/sbin/cron && /usr/sbin/apache2ctl -D FOREGROUND
