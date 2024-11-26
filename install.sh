### set custom PS1 ###
vi ~/.bashrc
    # add the below
    export PS1="\[$(tput bold)\]\[$(tput setaf 3)\]\u\[$(tput setaf 7)\]@\[$(tput setaf 1)\]\h\[$(tput setaf 7)\]:\[$(tput setaf 2)\]\w\[$(tput setaf 7)\]:\[$(tput sgr0)\]"
source ~/.bashrc
### initial updates after install ###
dnf update -y

### set selinux to permissive ###
vi /etc/selinux/config
#change the below from
SELINUX=enforcing
# to
SELINUX=permissive
# then also run a setenforce so we dont have to restart
setenforce 0

### install zabbix server
# install the zabbix server, frontend and agent
rpm -Uvh https://repo.zabbix.com/zabbix/7.0/centos/9/x86_64/zabbix-release-latest.el9.noarch.rpm
dnf clean all
dnf install -y zabbix-server-pgsql zabbix-web-pgsql zabbix-apache-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent
# install the postgres server
dnf install postgresql-server.x86_64 -y
# initialise the database
/usr/bin/postgresql-setup --initd
# start and enable the postgres service
systemctl start postgresql.service && systemctl enable postgresql.service
# change to the postgres user and set the PS1
sudo su postgres
vi ~/.bashrc
    # add the below, blue is non root user for me
    export PS1="\[$(tput bold)\]\[$(tput setaf 3)\]\u\[$(tput setaf 7)\]@\[$(tput setaf 6)\]\h\[$(tput setaf 7)\]:\[$(tput setaf 2)\]\w\[$(tput setaf 7)\]:\[$(tput sgr0)\]"
source ~/.bashrc
# connect to postgres and create the user and database for zabbix
psql
CREATE ROLE zabbix LOGIN PASSWORD 'password' SUPERUSER;
CREATE DATABASE zabbix WITH OWNER = zabbix;
GRANT CONNECT ON DATABASE zabbix TO zabbix;
\q
# update the pg_hba.conf to trust the local connections
vi /var/lib/pgsql/data/pg_hba.conf
    # change these three lines from
    local   all             all                                     ident
    host    all             all             127.0.0.1/32            ident
    host    all             all             ::1/128                 ident
    # to these three lines, its just replacing ident with md5
    local   all             all                                     md5
    host    all             all             127.0.0.1/32            md5
    host    all             all             ::1/128                 md5
# restart the postgres service for the change to take effect
systemctl restart postgresql.service        # will need the root password as we are stil on the postgres user
# change back to the root user
exit
# import the initial zabbix database and data
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql zabbix
# configure the db password for the zabbix user in the zabbix conf
vi /etc/zabbix/zabbix_server.conf
# uncomment the # DBPassword= and set the password
DBPassword=password
# restart and enable the zabbix components
systemctl restart zabbix-server zabbix-agent httpd php-fpm
systemctl enable zabbix-server zabbix-agent httpd php-fpm
# open firewalld for port 80 so that you can browse the zabbix UI
firewall-cmd --permanent --add-port=80/tcp
# ope the zabbix agent port 10050 aswell
firewall-cmd --permanent --add-port=10050/tcp
firewall-cmd --reload
# add a host record for the activemq server
vi /etc/hosts
    192.168.3.200   activemq.local.lab activemq

### browse the zabbix URL and complete installation ###
http://zabbix.local.lab/zabbix
# default login after install
user: Admin
password: zabbix 

### Install the zabbix agent on the activemq.local.lab server ###
# add the zabbix rpm for 7 LTS that we installed
rpm -Uvh https://repo.zabbix.com/zabbix/7.0/centos/9/x86_64/zabbix-release-latest.el9.noarch.rpm
dnf clean all
dnf install zabbix-agent
# set the hostname in the zabbix conf file
vi /etc/zabbix/zabbix_agentd.conf
# update the zabbix conf with the zabbix servers hostname
Server=zabbix.local.lab
# make sure the DNS resolves and edit hosts if needed
vi /etc/hosts
# resetat and enable zabbix service
systemctl restart zabbix-agent
systemctl enable zabbix-agent
# open the port 10050 for zabbix on the activemq server firewalld
firewall-cmd --permanent --add-port=10050/tcp
firewall-cmd --reload

### Add the activemq server on zabbix UI ###
Link Template: Linux by Zabbix agent