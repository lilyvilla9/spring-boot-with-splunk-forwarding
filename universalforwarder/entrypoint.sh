#!/bin/bash

set -e

if [ "$1" = 'splunk' ]; then
  shift
  sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME}/bin/splunk "$@"
elif [ "$1" = 'start-service' ]; then
  # If user changed SPLUNK_USER to root we want to change permission for SPLUNK_HOME
  if [[ "${SPLUNK_USER}:${SPLUNK_GROUP}" != "$(stat --format %U:%G ${SPLUNK_HOME})" ]]; then
    chown -R ${SPLUNK_USER}:${SPLUNK_GROUP} ${SPLUNK_HOME}
  fi

  # If these files are different override etc folder (possible that this is upgrade or first start cases)
  # Also override ownership of these files to splunk:splunk
  if ! $(cmp --silent /var/opt/splunk/etc/splunk.version ${SPLUNK_HOME}/etc/splunk.version); then
    cp -fR /var/opt/splunk/etc ${SPLUNK_HOME}
    chown -R ${SPLUNK_USER}:${SPLUNK_GROUP} $SPLUNK_HOME/etc
    chown -R ${SPLUNK_USER}:${SPLUNK_GROUP} $SPLUNK_HOME/var
  fi

  sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME}/bin/splunk start --accept-license --answer-yes --no-prompt
  trap "sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME}/bin/splunk stop" SIGINT SIGTERM EXIT

  chown -R ${SPLUNK_USER}:${SPLUNK_GROUP} $SPLUNK_HOME
  chmod -R 777 $SPLUNK_HOME
  chmod -R 777 /sbin
  #sudo -HEu ${SPLUNK_USER} touch ${SPLUNK_HOME}/all.log
  #sudo -HEu ${SPLUNK_USER} touch ${SPLUNK_HOME}/all_json.log
  #sudo -HEu ${SPLUNK_USER} touch ${SPLUNK_HOME}/spring-boot.log
  #sudo -HEu ${SPLUNK_USER} touch ${SPLUNK_HOME}/spring.log
  #sudo -HEu ${SPLUNK_USER} java -jar /sbin/flower.jar &
  sudo -HEu ${SPLUNK_USER} nohup java -jar /sbin/flower.jar > /nohup.out 2>&1 &

  if [[ -n ${SPLUNK_FORWARD_SERVER} ]]; then
    if ! sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME}/bin/splunk list forward-server -auth admin:changeme | grep -q "${SPLUNK_FORWARD_SERVER}"; then
      sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME}/bin/splunk add forward-server "${SPLUNK_FORWARD_SERVER}" -auth admin:changeme
      sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME}/bin/splunk add monitor /var/log/lili_log.log
      #sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME}/bin/splunk add monitor ${SPLUNK_HOME}/all.log
      #sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME}/bin/splunk add monitor ${SPLUNK_HOME}/spring-boot.log
      #sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME}/bin/splunk add monitor ${SPLUNK_HOME}/spring.log
      sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME}/bin/splunk add monitor /nohup.out
    fi
  fi

  sudo -HEu ${SPLUNK_USER} tail -n 0 -f ${SPLUNK_HOME}/var/log/splunk/splunkd_stderr.log &
  wait
else
  "$@"
fi
