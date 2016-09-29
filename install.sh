#!/bin/bash

apt-get install mc htop git unzip wget curl -y

echo
echo "====================================================="
echo "                     WELCOME"
echo "====================================================="
echo
echo "Hub"
echo "download https://www.jetbrains.com/hub/download/"
echo "read instraction https://www.jetbrains.com/hub/help/1.0/Installing-Hub-with-Zip-Distribution.html"
echo "install into /usr/jetbrains/youtrack/"
echo "====================================="
echo
echo "YouTrack"
echo "download https://www.jetbrains.com/youtrack/download/get_youtrack.html"
echo "read instraction https://confluence.jetbrains.com/display/YTD65/Installing+YouTrack+with+ZIP+Distribution#InstallingYouTrackwithZIPDistribution-InstallingNewYouTrackServer"
echo "install into /usr/jetbrains/youtrack/"
echo "====================================="
echo
echo "Upsource"
echo "download https://www.jetbrains.com/upsource/download/"
echo "read the first https://www.jetbrains.com/upsource/help/2.0/prerequisites.html"
echo "install into /usr/jetbrains/upsource/"
echo "====================================="
echo

type="y"
echo "Y - will be installing in the auto mode: download all needs, config nginx and others"
echo -n "Do you want to continue? [Y|n]: "
read type

if [ "$type" == "n" ]; then
  exit 0
fi

echo "==================================="
echo "In order to continue installing need set a few properties for nginx:"

echo -n "Base domain url: "
read base_domain

echo -n "Hub domain url: "
read hub_domain
echo -n "hub port: "
read hub_port

echo -n "Youtrack domain url: "
read yt_domain
echo -n "Youtrack port: "
read yt_port

echo -n "Upsource domain url: "
read us_domain
echo -n "Upsource port: "
read us_port

echo -n "Cron email: "
read $cron_email

print_params() {
	echo "================="
	echo
	echo "Base domain url: $base_domain"
	echo "Hub domain url: $hub_domain"
	echo "hub port: $hub_port"
	echo "Youtrack domain url: $yt_domain"
	echo "Youtrack port: $yt_port"
	echo "Upsource domain url: $us_domain"
	echo "Upsource port: $us_port"
	echo "Cron email: $cron_email"
	echo
	echo "================="
}

if [ "$base_domain" == "" ] || [ "$hub_domain" == "" ] || [ "$hub_port" == "" ] || [ "$yt_domain" == "" ] || [ "$yt_port" == "" ] || [ "$us_domain" == "" ] || [ "$us_port" == "" ]; then
  echo "You have mistake into parameters!"
  exit 1
fi

echo "Please check data"
echo "================="
echo
echo "Base domain url: $base_domain"
echo "Hub domain url: $hub_domain"
echo "hub port: $hub_port"
echo "Youtrack domain url: $yt_domain"
echo "Youtrack port: $yt_port"
echo "Cron email: $cron_email"
echo
echo "================="

echo -n "Do you continue? [Y|n]"
read type

if [ "$type" == "n" ]; then
  exit 0
fi

echo -n "Upsource domain url: "
read us_domain
echo -n "Upsource port: "
read us_port


code=`lsb_release -a | grep Codename | sed 's/[[:space:]]//g' | cut -f2 -d:`

echo
echo "debian codename:"
echo "$code"
echo

mkdir -p /var/tmp
pushd /var/tmp

echo
echo "Installing Java JDK 1.8"
echo

if [ "$code" != "jessie" ]; then
  echo "from oracle site"
  echo
  url=http://download.oracle.com/otn-pub/java/jdk/8u60-b27/
  java_version=jdk-8u60-linux-x64.tar.gz
  
  wget -c -O "$java_version" --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "$url$java_version"
  
  mkdir -p /opt/jdk
  
  tar -zxf $java_version -C /opt/jdk
  
  update-alternatives --install /usr/bin/java java /opt/jdk/jdk1.8.0_60/bin/java 100
  update-alternatives --install /usr/bin/javac javac /opt/jdk/jdk1.8.0_60/bin/javac 100
else
  apt-get install java8-jdk -y
fi;

echo
java -version
update-alternatives --display java
javac -version
update-alternatives --display javac
echo

mkdir -p /usr/jetbrains/{youtrack,hub,upsource}

wget https://download-cf.jetbrains.com/hub/2.5/hub-ring-bundle-2.5.330.zip -O /usr/jetbrains/hub/arch.zip 

wget https://download-cf.jetbrains.com/charisma/youtrack-7.0.27477.zip -O /usr/jetbrains/youtrack/arch.zip

wget https://download-cf.jetbrains.com/upsource/upsource-3.0.4421.zip -O /usr/jetbrains/upsource/arch.zip

pushd /usr/jetbrains/hub
unzip arch.zip 
popd


pushd /usr/jetbrains/youtrack
unzip arch.zip
popd

pushd /usr/jetbrains/upsource
unzip arch.zip
mv Upsource/* ../upsource/
chmod +x -R ../upsource/
popd
popd

cd  /usr/jetbrains/hub
cd hub-ring-bundle-2.5.330/
#sudo mv * ../

cd  /usr/jetbrains/upsource
cd upsource-3.0.4421/
#sudo mv * ../

cd  /usr/jetbrains/upsource
cd youtrack-7.0.27477/
#sudo mv * ../


make_initd() {
  
  echo "making init.d for $1"

  rq="hub "
  if [ "$1" == "hub" ]; then
    rq=""
  fi

  cat >/etc/init.d/$1 <<EOF
#! /bin/sh
### BEGIN INIT INFO
# Provides:          $1
# Required-Start:    $rq\$local_fs \$remote_fs \$network \$syslog \$named
# Required-Stop:     $rq\$local_fs \$remote_fs \$network \$syslog \$named
# Default-Start:     2 3 4 5
# Default-Stop:      S 0 1 6
# Short-Description: initscript for $1
# Description:       initscript for $1
### END INIT INFO

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
NAME=$1
SCRIPT=/usr/jetbrains/\$NAME/bin/\$NAME.sh

do_start() {
  \$SCRIPT start soft
}

case "\$1" in
  start)
    do_start
    ;;
  stop|restart|status|run|rerun|help)
    \$SCRIPT \$1 \$2
    ;;
  *)
    echo "Usage: sudo /etc/init.d/$1 {start|stop|restart|status|run|rerun}" >&2
    exit 1
    ;;
esac

exit 0
EOF
  
  chmod +x /etc/init.d/$1
  
  update-rc.d $1 defaults
  if [ "$1" != "hub" ]; then
    update-rc.d $1 disable
  fi
}

echo
make_initd youtrack

echo
make_initd hub-ring-bundle-2.5.330

echo
make_initd upsource

echo


mkdir -p /root/crons

cat >/root/crons/jetbrains<<EOF
#!/bin/bash

status=404
while [ \$status -eq 404 ]; do
  echo "wait hub..."
  sleep 60
  status=\`curl -s -o /dev/null -w "%{http_code}" http://$hub_domain/hub\`
  echo "hub status \$status"
done

service youtrack start
service upsource start

exit 0
EOF

chmod +x /root/crons/jetbrains

echo "MAILTO=$cron_email" > /tmp/cron_
echo "" >> /tmp/cron_
echo "@reboot /root/crons/jetbrains" > /tmp/cron_
crontab /tmp/cron_

service upsource stop
service youtrack stop
service hub stop

/usr/jetbrains/hub/bin/hub.sh configure --listen-port $hub_port --base-url http://$hub_domain
/usr/jetbrains/youtrack/bin/youtrack.sh configure --listen-port $yt_port --base-url http://$yt_domain
/usr/jetbrains/upsource/bin/upsource.sh configure --listen-port $us_port --base-url http://$us_domain

service hub start
service youtrack start
service upsource start

echo "goto setup"
echo $hub_domain
echo $yt_domain
echo $us_domain
