#!/bin/bash

# From lb-test.sh
#export JSLEE=/opt/mobicents/mobicents-slee-2.8.14.40
#export JBOSS_HOME=$JSLEE/jboss-5.1.0.GA
#export JAVA_OPTS="-Xms1024m -Xmx1024m -XX:PermSize=128M -XX:MaxPermSize=256M -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalMode"
#export SIPP=$PWD/sipp

#export LBVERSION=2.0.17
#rm -rf logs
#mkdir logs

export START=1
export SUCCESS=0

echo -e "\nB2BUA Confirmed Dialog Failover Test\n"
echo -e "Start Load Balancer and Cluster\n"

export JAVA_OPTS="-Xms1024m -Xmx1024m -XX:PermSize=128M -XX:MaxPermSize=256M -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalMode -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.local.only=false"
java $JAVA_OPTS -DlogConfigFile=$LBTEST/lb-log4j.xml -jar $LBPATH/sip-balancer-jar-$LBVERSION-jar-with-dependencies.jar -mobicents-balancer-config=$LBTEST/lb-configuration.xml &
export LB_PID="$!"
echo "Load Balancer: $LB_PID"
echo "Wait 10 seconds.."
sleep 10

$JBOSS_HOME/bin/run.sh -c port-1 -Djboss.service.binding.set=ports-01 -Djboss.messaging.ServerPeerID=0 -Dsession.serialization.jboss=false > $LOG/lb-b2bua-confirmed-failover-port-1-jboss.log 2>&1 &
export NODE1_PID="$!"
echo "NODE1: $NODE1_PID"

#sleep 10
TIME=0
while :; do
  sleep 10
  TIME=$((TIME+10))
  echo " .. $TIME seconds"
  STARTED_IN_1=$(grep -c " Started in " $LOG/lb-b2bua-confirmed-failover-port-1-jboss.log)
  if [ "$STARTED_IN_1" -eq 1 ]; then break; fi
  
  if [ $TIME -gt 300 ]; then
    export START=0
    break
  fi
done

if [ "$START" -eq 0 ]; then
  echo "There is a problem with starting Load Balancer and Cluster!"
  echo "Wait 10 seconds.."
  
  pkill -TERM -P $NODE1_PID
  sleep 10
  
  kill $LB_PID
  wait $LB_PID 2>/dev/null
  exit $SUCCESS
fi

$JBOSS_HOME/bin/run.sh -c port-2 -Djboss.service.binding.set=ports-02 -Djboss.messaging.ServerPeerID=1 -Dsession.serialization.jboss=false > $LOG/lb-b2bua-confirmed-failover-port-2-jboss.log 2>&1 &
export NODE2_PID="$!"
echo "NODE2: $NODE2_PID"

#sleep 60
TIME=0
while :; do
  sleep 10
  TIME=$((TIME+10))
  echo " .. $TIME seconds"
  STARTED_IN_2=$(grep -c " Started in " $LOG/lb-b2bua-confirmed-failover-port-2-jboss.log)
  if [ "$STARTED_IN_2" -eq 1 ]; then
    export START=1
    break
  fi
  
  if [ $TIME -gt 300 ]; then
    export START=0
    break
  fi
done

if [ "$START" -eq 1 ]; then
  echo "Load Balancer and Cluster are ready!"
else
  echo "There is a problem with starting Load Balancer and Cluster!"
  echo "Wait 20 seconds.."
    
  pkill -TERM -P $NODE1_PID
  sleep 10
  pkill -TERM -P $NODE2_PID
  sleep 10
  
  kill $LB_PID
  wait $LB_PID 2>/dev/null
  exit $SUCCESS
fi

####
#exit 1

echo -e "\nStart B2BUA Confirmed Dialog Failover Test\n"
echo -e "    B2BUA Confirmed Dialog Failover Test is Started\n" >> $REPORT

cd $JSLEE/examples/sip-b2bua/sipp

$SIPP -trace_err -nd -sf uas_DIALOG.xml -i 127.0.0.1 -p 5090 -r 1 -m 5 -l 5 -bg
#UAS_PID=$!
UAS_PID=$(ps aux | grep '[u]as_DIALOG.xml' | awk '{print $2}')
if [ "$UAS_PID" == "" ]; then
  exit -1
fi
echo "UAS: $UAS_PID"

sleep 1
$SIPP 127.0.0.1:5060 -nd -trace_err -sf uac_DIALOG.xml -i 127.0.0.1 -p 5050 -r 1 -m 5 -l 5 -bg
#UAC_PID=$!
UAC_PID=$(ps aux | grep '[u]ac_DIALOG.xml' | awk '{print $2}')
if [ "$UAC_PID" == "" ]; then
  exit
fi
echo "UAC: $UAC_PID"

#sleep 120s
TIME=0
while :; do
  sleep 10
  TIME=$((TIME+10))
  echo " .. $TIME seconds"
  
  # stop Node1 after 20 seconds
  if [ "$TIME" -eq 20 ]
  then
    echo "     .. Stop Node1: pkill -TERM -P $NODE1_PID"
    pkill -TERM -P $NODE1_PID
    sleep 10
  fi
  
  TEST=$(ps aux | grep '[u]as_DIALOG.xml' | awk '{print $2}')
  if [ "$TEST" != "$UAS_PID" ]; then
    export SUCCESS=1
    break
  fi
done

SIP_B2BUA_DIALOG_EXIT=$?
echo -e "SIP B2BUA Confirmed Dialog Failover Test is Finished: $SIP_B2BUA_DIALOG_EXIT for $TIME seconds\n"
echo -e "    SIP B2BUA Confirmed Dialog Failover Test is Finished: $SIP_B2BUA_DIALOG_EXIT for $TIME seconds\n" >> $REPORT

if [ "$SIP_B2BUA_DIALOG_EXIT" -ne 0 ]; then export SUCCESS=0; fi

# error handling
UAS_ERRORS=$JSLEE/examples/sip-b2bua/sipp/uas_DIALOG_"$UAS_PID"_errors.log
if [ -f $UAS_ERRORS ]; then
  NUMOFLINES=$(wc -l < $UAS_ERRORS)
  WATCHDOG=$(grep -c "Overload warning: the minor watchdog timer" $UAS_ERRORS)
  TEST=$((NUMOFLINES-1-WATCHDOG))
  if [ "$TEST" -gt 0 ]
  then
    export SUCCESS=0
    echo "WATCHDOG: $WATCHDOG of NUMOFLINES: $NUMOFLINES"
    echo -e "There are errors. See ERRORs in $UAS_ERRORS\n"
    echo -e "        There are errors. See ERRORs in $UAS_ERRORS\n" >> $REPORT
  fi
fi
UAC_ERRORS=$JSLEE/examples/sip-b2bua/sipp/uac_DIALOG_"$UAC_PID"_errors.log
if [ -f $UAC_ERRORS ]; then
  NUMOFLINES=$(wc -l < $UAC_ERRORS)
  WATCHDOG=$(grep -c "Overload warning: the minor watchdog timer" $UAC_ERRORS)
  TEST=$((NUMOFLINES-1-WATCHDOG))
  if [ "$TEST" -gt 0 ]
  then
    export SUCCESS=0
    echo "WATCHDOG: $WATCHDOG of NUMOFLINES: $NUMOFLINES"
    echo -e "There are errors. See ERRORs in $UAC_ERRORS\n"
    echo -e "        There are errors. See ERRORs in $UAC_ERRORS\n" >> $REPORT
  fi
fi

echo "Stopping Cluster nodes and Load Balancer."
echo "Wait 20 seconds.."

#pkill -TERM -P $NODE1_PID
#sleep 10
pkill -TERM -P $NODE2_PID
sleep 10

#kill -9 $LB_PID
kill $LB_PID
wait $LB_PID 2>/dev/null

cd $LOG
find . -name 'load-balancer.log*' -exec bash -c 'mv $0 ${0/load-balancer/lb-b2bua-confirmed-failover-loadbalancer}' {} \;

sleep 10
exit $SUCCESS
