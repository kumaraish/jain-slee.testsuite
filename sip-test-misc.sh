#!/bin/bash

### SIP Wake Up

# Deploy
echo -e "\nDeploy SIP Wake Up Example\n"
echo -e "\nDeploy SIP Wake Up Example\n" >> $LOG/siptests-jboss.log
cd $HOME/examples/sip-wake-up
ant deploy-all
sleep 15

echo -e "\nTesting SIP Wake Up Example"

cd sipp
$SIPP 127.0.0.1:5060 -sf scenario.xml -i 127.0.0.1 -p 5050 -r 1 -m 1 -bg

UAC_PID=$(ps aux | grep '[s]cenario.xml' | awk '{print $2}')
if [ "$UAC_PID" == "" ]; then exit -1; fi
echo "UAC_PID: $UAC_PID"

#sleep 120s
TIME=0
while :; do
  sleep 1
  TIME=$((TIME+1))
  TEST=$(ps aux | grep '[s]cenatio.xml' | awk '{print $2}')
  if [ "$TEST" != "$UAC_PID" ]; then break; fi
done

SIP_WAKEUP_EXIT=$?
echo -e "SIP Wake Up Test result: $SIP_WAKEUP_EXIT for $TIME seconds\n" >> $REPORT
echo -e "\nFinish test"

# Undeploy
echo -e "\nUndeploy SIP Wake Up Example\n"
echo -e "\nUndeploy SIP Wake Up Example\n" >> $LOG/siptests-jboss.log
cd ..
ant undeploy-all
sleep 60

### SIP JDBC Registrar

# Deploy
echo -e "\nDeploy SIP JDBC Registrar Example\n"
echo -e "\nDeploy SIP JDBC Registrar Example\n" >> $LOG/siptests-jboss.log
cd $HOME/examples/sip-jdbc-registrar
ant deploy-all
sleep 15

cd sipp

echo -e "\nStart SIP Registrar Functionality Test\n"
$SIPP 127.0.0.1:5060 -sf registrar-functionality.xml -i 127.0.0.1 -p 5050 -r 1 -m 1 -bg

UAC_PID=$(ps aux | grep '[r]egistrar-functionality' | awk '{print $2}')
if [ "$UAC_PID" == "" ]; then exit -1; fi
echo "UAC_PID: $UAC_PID"

#sleep 120s
TIME=0
while :; do
  sleep 1
  TIME=$((TIME+1))
  TEST=$(ps aux | grep '[r]egistrar-functionality' | awk '{print $2}')
  if [ "$TEST" != "$UAC_PID" ]; then break; fi
done

SIP_REGFUNC_EXIT=$?
echo -e "SIP Registrar Functionality Test result: $SIP_REGFUNC_EXIT for $TIME seconds\n" >> $REPORT
echo -e "\nFinish test"

echo -e "\nStart SIP Registrar Load Test\n"
$SIPP 127.0.0.1:5060 -sf registrar-load-test.xml -i 127.0.0.1 -p 5050 -r 1 -m 200 -bg

UAC_PID=$(ps aux | grep '[r]egistrar-load-test' | awk '{print $2}')
if [ "$UAC_PID" == "" ]; then exit -1; fi
echo "UAC_PID: $UAC_PID"

#sleep 120s
TIME=0
while :; do
  sleep 1
  TIME=$((TIME+1))
  TEST=$(ps aux | grep '[r]egistrar-load-test' | awk '{print $2}')
  if [ "$TEST" != "$UAC_PID" ]; then break; fi
done

SIP_REGLOAD_EXIT=$?
echo -e "SIP Registrar Load Test result: $SIP_REGLOAD_EXIT for $TIME seconds\n" >> $REPORT
echo -e "\nFinish test"
sleep 15

# Undeploy
echo -e "\nUndeploy SIP JDBC Registrar Example\n"
echo -e "\nUndeploy SIP JDBC Registrar Example\n" >> $LOG/siptests-jboss.log
cd ..
ant undeploy-all
sleep 60
