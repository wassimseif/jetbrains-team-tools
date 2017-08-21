#! /bin/sh

error() {
  test -n "${1}" && echo "${1}"
  exit 1
}

## Adjust the values to the desired version and architecture
hub_version="2017.3"
hub_build="6757" # On the site, this should be visible under the "Version"

youtrack_version="2017.3"
youtrack_build="35488" # On the site, this should be visible under the "Version"

upsource_version="2017.2"
upsource_build="2197" # On the site, this should be visible under the "Version"

jre_version="8u144" # If the version changes, you might need to also change the "base_url"
#jre_arch=arm32-vfp-hflt
#jre_arch=arm64-vfp-hflt
#jre_arch=i586
jre_arch=x64

download_destination="/tmp"
mkdir -p "${download_destination}" || error

apt-get install mc htop git unzip wget curl cron -y || error "Please make sure you have rights to install packages"

echo
echo "====================================================="
echo "                     WELCOME"
echo "====================================================="
echo
echo "Hub"
echo "download https://www.jetbrains.com/hub/download/#section=linux"
echo "read instraction https://www.jetbrains.com/hub/help/1.0/Installing-Hub-with-Zip-Distribution.html"
echo "install into /home/jetbrains/hub/"
echo "====================================="
echo
echo "YouTrack"
echo "download https://www.jetbrains.com/youtrack/download/get_youtrack.html"
echo "read instraction https://confluence.jetbrains.com/display/YTD65/Installing+YouTrack+with+ZIP+Distribution#InstallingYouTrackwithZIPDistribution-InstallingNewYouTrackServer"
echo "install into /home/jetbrains/youtrack/"
echo "====================================="
echo
echo "Upsource"
echo "download https://www.jetbrains.com/upsource/download/#section=linux"
echo "read the first https://www.jetbrains.com/upsource/help/2.0/prerequisites.html"
echo "install into /home/jetbrains/upsource/"
echo "====================================="
echo

type="y"
echo "Y - will be installing in the auto mode: download all needs, config nginx and others"
echo -n "Do you want to continue? [Y|n]: "
read type

if [ "$type" = "n" ]; then
  exit 0
fi

adduser jetbrains --disabled-password --quiet

echo "==================================="
echo "In order to continue installing need set a few properties for nginx:"

# $1 - the default value that will be returned if '$2' is empty
unwrap_or() {
  test -z "${1}" && error "Script Logic Error: Please pass the default value"
  test -n "${2}" && echo "${2}" || echo "${1}"
}

default_base_domain="127.0.0.1"
echo -n "Base domain url [${default_base_domain}]: "
read base_domain
base_domain="$(unwrap_or "${default_base_domain}" "${base_domain}")"

# Hub Domain
default_hub_domain="${base_domain}"
echo -n "Hub domain url [${default_hub_domain}]: "
read hub_domain
hub_domain="$(unwrap_or "${default_hub_domain}" "${hub_domain}")"

# Hub Port
default_hub_port="8112"
echo -n "hub port [${default_hub_port}]: "
read hub_port
hub_port="$(unwrap_or ${default_hub_port} ${hub_port})"

# YouTrack Domain
default_yt_domain="${base_domain}"
echo -n "Youtrack domain url [${default_yt_domain}]: "
read yt_domain
yt_domain="$(unwrap_or "${default_yt_domain}" "${yt_domain}")"

# YouTrack Port
default_yt_port="$(( ${hub_port} + 1 ))"
echo -n "Youtrack port [${default_yt_port}]: "
read yt_port
yt_port="$(unwrap_or ${default_yt_port} ${yt_port})"

# Upsource Domain
default_us_domain="${base_domain}"
echo -n "Upsource domain url [${default_us_domain}]: "
read us_domain
us_domain="$(unwrap_or "${default_us_domain}" "${us_domain}")"

# Upsource Port
default_us_port="$(( ${yt_port} + 1 ))"
echo -n "Upsource port [${default_us_port}]: "
read us_port
us_port="$(unwrap_or ${default_us_port} ${us_port})"

echo -n "Cron email: "
read cron_email

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

if [ "$base_domain" = "" ] \
   || [ "$hub_domain" = "" ] \
   || [ "$hub_port" = "" ] \
   || [ "$yt_domain" = "" ] \
   || [ "$yt_port" = "" ] \
   || [ "$us_domain" = "" ] \
   || [ "$us_port" = "" ]; then
  error "Script Logic Error: Empty parameter slipped through!"
fi

print_params

echo -n "Do you want to continue? [Y|n]"
read type

if [ "$type" = "n" ]; then
  exit 0
fi

code=$(lsb_release -a | grep Codename | sed 's/[[:space:]]//g' | cut -f2 -d:)

echo
echo "debian codename: $code"
echo

(
  cd "${download_destination}" || error

  echo
  echo "Installing Java JRE 1.8"
  echo

  base_url=http://download.oracle.com/otn-pub/java/jdk/${jre_version}-b01/090f390dda5b47b9b721c7dfaa008135/
  jdk_archive=jdk-${jre_version}-linux-${jre_arch}.tar.gz

  wget -c -O "$jdk_archive" \
    --no-check-certificate \
    --no-cookies \
    --header "Cookie: oraclelicense=accept-securebackup-cookie" \
    "${base_url}${jdk_archive}" \
    || error "Failed to download the Java SDK, please make sure the 'base_url' is correct"

  mkdir -p /opt/jdk

  tar -zxf "${jdk_archive}" -C /opt/jdk || error
  mv /opt/jdk/jdk*/jre /opt/jre

  rm -rf /opt/jdk "${jdk_archive}"

  update-alternatives --install /usr/bin/java java /opt/jre/bin/java 100

  echo
  java -version
  update-alternatives --display java
  echo

  mkclean() {
    test -z "${1}" && error "Please pass a component"

    _path="/home/jetbrains/${1}"

    rm -rf "${_path}"
    mkdir -p "${_path}"
  }

  mkclean youtrack
  mkclean hub
  mkclean upsource

  archive_location="${download_destination}/arch.zip"
  download_and_unpack() {
    test -z "${1}" && error "Please pass a component"
    test -z "${2}" && error "Please pass a link"

    _component="${1}" # {hub, youtrack, upsource}
    _link="${2}"      # {hub, youtrack, upsource} download link

    wget "${_link}" -O "${archive_location}"

    unzip "${archive_location}" -d "/home/jetbrains/${_component}"
    mv /home/jetbrains/${_component}/${_component}*/* "/home/jetbrains/${_component}/"

    rm -rf \
      "${archive_location}" \
      /home/jetbrains/${_component}/internal/java/mac-x64 \
      /home/jetbrains/${_component}/internal/java/windows-amd64
  }

  download_and_unpack  hub       "https://download.jetbrains.com/hub/${hub_version}/hub-ring-bundle-${hub_version}.${hub_build}.zip"
  download_and_unpack  youtrack  "https://download.jetbrains.com/charisma/youtrack-${youtrack_version}.${youtrack_build}.zip"
  download_and_unpack  upsource  "https://download.jetbrains.com/upsource/upsource-${upsource_version}.${upsource_build}.zip"

  chmod +x -R /home/jetbrains/upsource # ??
)

make_initd() {

  echo "making init.d for $1"

  rq="hub "
  if [ "$1" = "hub" ]; then
    rq=""
  fi

  cat >"/etc/init.d/${1}" <<EOF
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
SCRIPT=/home/jetbrains/\$NAME/bin/\$NAME.sh

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

  chmod +x "/etc/init.d/${1}"

  update-rc.d "${1}" defaults
  if [ "$1" != "hub" ]; then
    update-rc.d "${1}" disable
  fi
}

echo
make_initd youtrack

echo
make_initd hub

echo
make_initd upsource

echo


mkdir -p /root/crons

cat >/root/crons/jetbrains<<EOF
#!/bin/bash

status=404
while [ \$status -eq 404 ]; do
  echo "Waiting Hub to start..."
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

/home/jetbrains/hub/bin/hub.sh configure \
  --listen-port "${hub_port}" \
  --base-url "http://${hub_domain}" || error "Failed to reconfigure Hub"

/home/jetbrains/youtrack/bin/youtrack.sh configure \
  --listen-port "${yt_port}" \
  --base-url "http://${yt_domain}" || error "Failed to reconfigure YouTrack"
/home/jetbrains/upsource/bin/upsource.sh configure \
  --listen-port "${us_port}" \
  --base-url "http://${us_domain}" || error "Failed to reconfigure Upsource"

# "linux-x64" is exactly the same in all the projects
rm -rf /home/jetbrains/youtrack/internal/java/linux-x64
rm -rf /home/jetbrains/upsource/internal/java/linux-x64
ln -sf /home/jetbrains/hub/internal/java/linux-x64 /home/jetbrains/youtrack/internal/java/linux-x64
ln -sf /home/jetbrains/hub/internal/java/linux-x64 /home/jetbrains/upsource/internal/java/linux-x64

chown :jetbrains -R /home/jetbrains
chmod u+rw -R /home/jetbrains

service hub start
service youtrack start
service upsource start

echo "goto setup"
echo "$hub_domain"
echo "$yt_domain"
echo "$us_domain"
