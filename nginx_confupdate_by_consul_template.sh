#!/bin/bash
service_path="xx/proxy/nginx"
consul_instance="ip:8500"
tpl_file=in.tpl
bak_nginx_path="/etc/nginx/conf.d.bak"
nginx_path="/etc/nginx"
log_location="/etc/nginx/configuration.log"
time_output=$(date +"%Y%m%d%H%M%S")
test_net()
{
   nc -nz -w 1 consul_instance_ip 8500
}

produce_tpl ()
{
	echo "{{ key \"$1\" }}" >$bak_nginx_path/$tpl_file	
}

run ()
{
echo $1
timestamp=$(date +"%Y%m%d%H%M%S")
output=`/usr/bin/consul-template -dry -consul=$consul_instance -log-level=ERR -syslog -once -template "$bak_nginx_path/$tpl_file:$nginx_path/conf.d/$1.conf"`
if [ ! -z "$output" ]
then
	echo $1" is not emptp"
	cp $nginx_path/conf.d/$1.conf $bak_nginx_path/bk.$1.conf.$timestamp
fi
}


execute ()
{
timestamp=$(date +"%Y%m%d%H%M%S")
/usr/bin/consul-template -consul=$consul_instance -log-level=ERR -syslog -once -template "$bak_nginx_path/$tpl_file:$nginx_path/conf.d/$1.conf:/sbin/service nginx reload"
}
main ()
{ 
  if [ $? -eq 0 ];then
	break
  fi 
  for path in `/usr/bin/consul kv get -recurse -keys $service_path/`
  do
     if [ -z "$path" ];then
	      echo $time_output":Empty service:"$path >>$log_location
     fi
     for dpath in `/usr/bin/consul kv get -recurse -keys $path/`
     do
                        service=`echo $dpath |cut -d "/" -f 6|cut -d ":" -f1`
                        dpath=`echo $dpath|cut -d ":" -f1`
                        produce_tpl $dpath
			if [ ! -z "$service" ];then
				run $service
			else
				echo $time_output":Empty service:"$dpath$service >>$log_location
			fi
     done
  done
  /sbin/service nginx configtest
  if [ $? -eq 0 ]
  then
     for path in `/usr/bin/consul kv get -recurse -keys $service_path/`
     do
     		for dpath in `/usr/bin/consul kv get -recurse -keys $path/`
     		do
			service=`echo $dpath |cut -d "/" -f 6|cut -d ":" -f1`
                        dpath=`echo $dpath|cut -d ":" -f1`
			produce_tpl $dpath
			if [ ! -z "$service" ];then
				execute $service
			else
				echo $time_output":Empty service:"$dpath$service >>$log_location
			fi
     		done
      done 
  else
     echo "configtest is error, please check"
  fi
  /bin/ps aux |grep "worker process is shutting down"|grep -v grep |awk {"print \$2"}|xargs -r kill
}
#while true
#do
test_net
if [ $? -eq 0 ];then
	main
fi
#	sleep 30
#done
