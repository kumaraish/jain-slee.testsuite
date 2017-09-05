#!/bin/bash

export START=1
export SUCCESS=0

echo -e "\nB2BUA Functionality Test\n"
echo -e "Start Load Balancer and Cluster\n"

export JAVA_OPTS="-Xms1024m -Xmx1024m -XX:PermSize=128M -XX:MaxPermSize=256M -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalMode -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.local.only=false -Dtelscale.license.dir=$LBPATH/license -Dtelscale.license.key.location=$LBPATH/license"
java $JAVA_OPTS -DlogConfigFile=$LBTEST/lb-log4j.xml -jar $LBPATH/sip-balancer-jar-*-jar-with-dependencies.jar -mobicents-balancer-config=$LBTEST/lb-configuration.xml &
export LB_PID="$!"
echo "Load Balancer: $LB_PID"
echo "Wait 10 seconds.."
sleep 10
export JAVA_OPTS=""

export JBOSS_HOME=$SERVER1_HOME
sh $SERVER1_HOME/bin/standalone.sh --server-config=standalone-ha.xml -b 127.0.0.1 -bmanagement=127.0.0.1 > $LOG/lb-b2bua-port-1-jboss.log 2>&1 &
export NODE1_PID="$!"
echo "NODE1: $NODE1_PID"

TIME=0
while :; do
  sleep 10
  TIME=$((TIME+10))
  echo " .. $TIME seconds"
  STARTED_IN_1=$(grep -c " started in " $LOG/lb-b2bua-port-1-jboss.log)
  if [ "$STARTED_IN_1" == 1 ]; then break; fi
  
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

cp $SERVER1/sip11-ra-DU-*.jar $SERVER1_HOME/standalone/deployments
sleep 10

export JBOSS_HOME=$SERVER2_HOME
sh $SERVER2_HOME/bin/standalone.sh --server-config=standalone-ha.xml -b 127.0.0.2 -bmanagement=127.0.0.2 > $LOG/lb-b2bua-port-2-jboss.log 2>&1 &
export NODE2_PID="$!"
echo "NODE2: $NODE2_PID"

TIME=0
while :; do
  sleep 10
  TIME=$((TIME+10))
  echo " .. $TIME seconds"
  STARTED_IN_2=$(grep -c " started in " $LOG/lb-b2bua-port-2-jboss.log)
  if [ "$STARTED_IN_2" == 1 ]; then break; fi
  
  if [ $TIME -gt 300 ]; then
    export START=0
    break
  fi
done

cp $SERVER2/sip11-ra-DU-*.jar $SERVER2_HOME/standalone/deployments
sleep 10

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

echo -e "\nStart B2BUA Functionality Test\n"
echo -e "    B2BUA Functionality Test is Started\n" >> $REPORT

cd $JSLEE/examples/sip-b2bua/sipp

$SIPP -trace_err -sf uas_DIALOG.xml -i 127.0.0.1 -p 5090 -r 1 -m 100 -l 100 -bg
UAS_PID=$(ps aux | grep '[u]as_DIALOG.xml' | awk '{print $2}')
if [ "$UAS_PID" == "" ]; then
  exit -1
fi
echo "UAS: $UAS_PID"

sleep 1
$SIPP 127.0.0.1:5060 -trace_err -sf uac_DIALOG.xml -i 127.0.0.1 -p 5050 -r 1 -m 100 -l 100 -bg
UAC_PID=$(ps aux | grep '[u]ac_DIALOG.xml' | awk '{print $2}')
if [ "$UAC_PID" == "" ]; then
  exit
fi
echo "UAC: $UAC_PID"

TIME=0
while :; do
  sleep 10
  TIME=$((TIME+10))
  echo " .. $TIME seconds"
  
  TEST=$(ps aux | grep '[u]as_DIALOG.xml' | awk '{print $2}')
  if [ "$TEST" != "$UAS_PID" ]; then
    export SUCCESS=1
    break
  fi
done

SIP_B2BUA_DIALOG_EXIT=$?
echo -e "B2BUA Functionality Test is Finished: $SIP_B2BUA_DIALOG_EXIT for $TIME seconds\n"
echo -e "    B2BUA Functionality Test is Finished: $SIP_B2BUA_DIALOG_EXIT for $TIME seconds\n" >> $REPORT

if [ "$SIP_B2BUA_DIALOG_EXIT" -ne 0 ]; then export SUCCESS=0; fi

echo "Stopping Cluster nodes and Load Balancer."
echo "Wait 20 seconds.."

pkill -TERM -P $NODE1_PID
sleep 20
rm $SERVER1_HOME/standalone/deployments/sip11-ra-DU-*.jar
pkill -TERM -P $NODE2_PID
sleep 20
rm $SERVER2_HOME/standalone/deployments/sip11-ra-DU-*.jar

kill $LB_PID
wait $LB_PID 2>/dev/null

cd $LOG
find . -name 'load-balancer.log*' -exec bash -c 'mv $0 ${0/load-balancer/lb-b2bua-func-loadbalancer}' {} \;

exit $SUCCESS
