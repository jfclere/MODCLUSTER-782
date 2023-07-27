while true
do
  rm -rf logs; mkdir logs
  rm -rf webapps/hello-sailor*
  while true
  do
    netstat -na | grep 8005
    if [ $? -ne 0 ]; then
      break
    fi
    sleep 1
  done

  bin/startup.sh
  while true
  do
    netstat -na | grep 8005 | grep LISTEN
    if [ $? -eq 0 ]; then
      break
    fi
    sleep 1
  done
  cp /home/jfclere/TMP/hello-sailor.war webapps/hello-sailor.war
  war=0
  while true
  do
    cp /home/jfclere/TMP/hello-sailor.war webapps/hello-sailor${war}.war
    war=`expr ${war} + 1`
    if [ ${war} -gt 1 ]; then
      break
    fi
  done
  war=`expr ${war} - 1`
  while true
  do
    grep hello-sailor${war} logs/catalina.out
    if [ $? -eq 0 ]; then
      echo "started!"
      break
    fi
  done
  while true
  do
    grep "Catalina will use" logs/catalina.out
    if [ $? -eq 0 ]; then
      echo "started!"
      break
    fi
  done
  while true
  do
    curl http://localhost:6666/mod_cluster_manager | grep "Status: OK"
    if [ $? -eq 0 ]; then
      break
    fi
    sleep 1
  done
  while true
  do
    curl http://localhost:6666/mod_cluster_manager | grep "hello-sailor${war}" | grep "Status: ENABLED"
    if [ $? -eq 0 ]; then
      break
    fi
    sleep 1
  done
  #curl -s -o /dev/null  http://localhost:8080/hello-sailor/?silence_is_golden=yes &
  ab -c10 -n50000  http://localhost:8000/hello-sailor/?silence_is_golden=yes >/dev/null &
  i=0
  while true
  do
    ab -c10 -n50000  http://localhost:8000/hello-sailor${i}/?silence_is_golden=yes >/dev/null &
    i=`expr ${i} + 1`
    if [ ${i} -eq ${war} ]; then
      break
    fi
  done
  #ab -c100 -n1000  http://localhost:8000/hello-sailor/?silence_is_golden=yes >/dev/null &
  #ab -c200 -n1000000  http://localhost:8000/hello-sailor/?silence_is_golden=yes >/dev/null &
  rm webapps/hello-sailor*.war &
  sleep 9
  bin/shutdown.sh 2>&1 >> shutdown.out
  grep "Connection refused" shutdown.out
  if [ $? -eq 0 ]; then
    echo "Shutdown failed!!!"
    bin/shutdown.sh 2>&1 | grep "Connection refused"
    if [ $? -eq 0 ]; then
      exit 1
    fi
  fi

  while true
  do
    # grep hostConfig.undeploy logs/catalina.out
    grep "valid shutdown" logs/catalina.out
    if [ $? -eq 0 ]; then
      echo "Stopping..."
      break
    fi
  done
  # ab -c100 -n1000  http://localhost:8000/hello-sailor/ >/dev/null &
  #pid=`ps -ef | grep java | grep -v grep | awk ' { print $2 } '`
  #kill -15 $pid
  i=0
  while true
  do
    ps -ef | grep java | grep -v grep
    if [ $? -ne 0 ]; then
      break
    fi
    sleep 1
    i=`expr $i + 1`
    if [ $i -eq 60 ]; then
      break
    fi
  done
  if [ $i -eq 60 ]; then
    pid=`ps -ef | grep java | grep -v grep | awk ' { print $2 } '`
    kill -15 $pid
    sleep 10
  fi
  grep Exception logs/catalina.out
  if [ $? -eq 0 ]; then
    echo "CRASHED!!!"
    break
  fi
  grep "Failed to drain" logs/catalina.out
  if [ $? -ne 0 ]; then
    echo "Drain problem!!!"
    break
  fi
done
