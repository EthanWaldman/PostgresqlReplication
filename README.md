Postgresql Setup
	
	1. Install postgresql-server on master and slave (postgresha-01 & postgresha-02, as root)
		a. yum install -y https://download.postgresql.org/pub/repos/yum/9.6/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm -y
		b. yum install -y postgresql96-server postgresql96 postgresql96-libs postgresql96-contrib
	2. Create DB on master (postgresha-01, as root) using initdb
		mkdir /apps
		mkdir -p /apps/pgsql/9.6/data
		chown -R postgres:postgres /apps
		cp /lib/systemd/system/postgresql-9.6.service /etc/systemd/system/postgresql-9.6.service
		Edit new file to set: Environment=PGDATA=/var/lib/pgsql/9.6/data-secondary
		/usr/pgsql-9.6/bin/postgresql96-setup initdb postgresql-9.6
		systemctl enable postgresql-9.6
		systemctl start postgresql-9.6 
	3. Perform the same steps as above on secondary (postgresha-02, as root) except for the initdb step and service start step
	4. Open port 5432 on host firewall postgresha-01 & postgresha-02, as root)
		a. firewall-cmd --add-port=5432/tcp --permanent
		b. firewall-cmd --reload
	5. Disable SELInux enforcement (just to keep things simple for POC) (postgresha-01 & postgresha-02, as root)
		a. setenforce permissive
	6. Ensure all servers can resolve to each other (DNS or /etc/hosts)

repmgr Setup
1. Install repmgr (postgresha-01 & postgresha-02, as root)
	a. yum -y install repmgr96
2. Add postgres to sudoers (postgresha-01 & postgresha-02, as root)
	a. Create /etc/sudoers.d/postgres
		i. postgres        ALL=(ALL)       NOPASSWD: ALL
	b. chmod 440 /etc/sudoers.d/postgres
3. Exchange ssh keys between postgres users on all nodes (postgresha-01 & postgresha-02, as postgres)
4. Make sure pg_ctl, pg_rewind and repmgr are in the PATH for postgres (and root?) (postgresha-01 & postgresha-02, as root)
	a. ln -s /usr/pgsql-9.6/bin/pg_ctl /bin/pg_ctl
	b. ln -s /usr/pgsql-9.6/bin/pg_rewind /bin/pg_rewind
	c. ln -s /usr/pgsql-9.6/bin/repmgr /bin/repmgr
5. Set up .pgpass (postgresha-01 & postgresha-02, as postgres)
	a. Create .pgpass file in ~postgres
		postgresha-01:*:*:repmgr:mirror
		postgresha-02:*:*:repmgr:mirror
		i. chmod 600 .pgpass
6. Configure postgresql.conf (postgresha-01, as postgres)
	a. listen_address = '*'
	b. shared_preload_libraries = 'repmgr'
	c. hot_standby = on
	d. wal_log_hints = on
	e. wal_level = hot_standby
	f. max_wal_senders = X (try 5)
	g. wal_keep_segments = Y (try 32)
	h. …then restart postgresql
	
7. Create repmgr user and database (postgresha-01, as postgres)
	[ in psql ]
	create user repmgr with superuser encrypted password 'mirror';
	create database repmgr with owner repmgr;
	
8. Add repmgr entries into pg_hba.conf (postgresha-0-1, as postgres)
	local   repmgr         repmgr                                           md5
	host    repmgr         repmgr          172.16.66.0/24     md5
	host    replication   repmgr          172.16.66.0/24     md5
	
	… and restart or reload
	
9. Create repmgr_*.conf (postgresha-01, as postgres)
	a. mv /etc/repmgr/96 /etc/repmgr/9.6
	b. mv /etc/repmgr/9.6/repmgr.conf /etc/repmgr/9.6/repmgr.conf.original
	c. Create new  /etc/repmgr/9.6/repmgr_local.conf
	node_id=1
	node_name=postgresha-01
	conninfo='host=postgresha-01 user=repmgr password=mirror dbname=repmgr connect_timeout=2'
	data_directory='/apps/pgsql/9.6/data/'
	log_facility=USER
	failover=automatic
	promote_command='/usr/pgsql-9.6/bin/repmgr standby promote -f /etc/repmgr/9.6/repmgr_local.conf --log-to-file'
	follow_command='/usr/pgsql-9.6/bin/repmgr standby follow -f /etc/repmgr/9.6/repmgr_local.conf --upstream-node-id=%n'
	reconnect_interval=3
	reconnect_attempts=2
	
	service_start_command='/etc/repmgr/9.6/db_start.sh'
	service_stop_command='sudo systemctl stop postgresql-9.6'
	service_restart_command='sudo systemctl restart postgresql-9.6'
	service_reload_command='sudo systemctl reload postgresql-9.6'
	d. Create new /etc/repmgr/9.6/repmgr_remote.conf
	node_id=1
	node_name=postgresha-01
	conninfo='host=postgresha-02 user=repmgr password=mirror dbname=repmgr connect_timeout=2'
	data_directory='/apps/pgsql/9.6/data/'
	
10. Register primary node to repmgr (postgresha-01, as postgres)
	repmgr -f /etc/repmgr/9.6/repmgr_local.conf primary register
	[To check status: repmgr -f /etc/repmgr/9.6/repmgr_local.conf cluster show ]
11. Prepare repmgr.conf for slave(s) (postgresha-02, as postgres)
	a. mv /etc/repmgr/96 /etc/repmgr/9.6
	b. mv /etc/repmgr/9.6/repmgr.conf /etc/repmgr/9.6/repmgr.conf.original
	c. Create new  /etc/repmgr/9.6/repmgr_local.conf
	node_id=2
	node_name=postgresha-02
	conninfo='host=postgresha-02 user=repmgr password=mirror dbname=repmgr connect_timeout=2'
	data_directory='/apps/pgsql/9.6/data/'
	log_facility=USER
	failover=automatic
	promote_command='/usr/pgsql-9.6/bin/repmgr standby promote -f /etc/repmgr/9.6/repmgr_local.conf --log-to-file'
	follow_command='/usr/pgsql-9.6/bin/repmgr standby follow -f /etc/repmgr/9.6/repmgr_local.conf --upstream-node-id=%n'
	reconnect_interval=3
	reconnect_attempts=2
	
	service_start_command='/etc/repmgr/9.6/db_start.sh'
	service_stop_command='sudo systemctl stop postgresql-9.6'
	service_restart_command='sudo systemctl restart postgresql-9.6'
	service_reload_command='sudo systemctl reload postgresql-9.6'
	d. Create new /etc/repmgr/9.6/repmgr_remote.conf
	node_id=2
	node_name=postgresha-02
	conninfo='host=postgresha-01 user=repmgr password=mirror dbname=repmgr connect_timeout=2'
	data_directory='/apps/pgsql/9.6/data/'
	
12. Clone secondary (postgresha-02, as postgres)
	export PGPASSFILE=~/.pgpass
	[ Do not be in the same directory with the repmgr.conf file ]
	repmgr  -h posgresha-01 -U repmgr -d repmgr -f /etc/repmgr/9.6/repmgr_local.conf standby clone
13. Register secondary (postgresha-02. as postgres)
	systemctl enable postgresql-9.6
	systemctl start postgresql-9.6
	repmgr -f /etc/repmgr/9.6/repmgr_local.conf standby register
14. Start automated failover daemon (postgresha-01 & postgresha-02, as root)
	a. Create pid directory:
		sudo mkdir /run/repmgr
		sudo chown postgres:postgres /run/repmgr
	b. Prepare the service file
		sudo cp /usr/lib/systemd/system/repmgr96.service /etc/systemd/system
		Edit /etc/systemd/system/repmgr96.service to set: Environment=REPMGRDCONF=/etc/repmgr/9.6/repmgr_local.conf
		sudo systemctl daemon-reload
	c. Enable and start service
		sudo systemctl enable repmgr96
		sudo systemctl start repmgr96
15. Set up shutdown and restart logic (postgresha-01 & postgresha-02, as root)
	a. Create under /etc/repmgr/9.6 the file db_start.sh (owned by postgres with mode 755) with:
		#!/bin/bash
		#
		        OOMScoreAdjust=-1000
		        export PGDATA=/apps/pgsql/9.6/data/
		        export PG_OOM_ADJUST_FILE=/proc/self/oom_score_adj
		        export PG_OOM_ADJUST_VALUE=0
		
		        /usr/pgsql-9.6/bin/postgresql96-check-db-dir ${PGDATA}
		        /usr/pgsql-9.6/bin/pg_ctl start -D ${PGDATA}
		
	b. Create under /etc/repmgr/9.6 the file switch_and_start.sh (owned by postgres with mode 755) with:
			#!/bin/bash
			#
			        CONFIG_FILE_REMOTE=repmgr_remote.conf
			        CONFIG_FILE_LOCAL=repmgr_local.conf
			        PGDATA=/apps/pgsql/9.6/data
			        DIRNAME=`dirname $0`
			
			        repmgr -f ${DIRNAME}/${CONFIG_FILE_REMOTE} cluster show \
			                | grep `hostname` | tr -d '|' | tr -s ' ' \
			                | grep -q "`hostname` primary - failed"
			        if [ $? -eq 0 ]
			        then
			                PRIMARY=`repmgr -f ${DIRNAME}/${CONFIG_FILE_REMOTE} cluster show \
			                        | grep primary | grep running | cut -d'|' -f2 \
			                        | tr -d ' '`
			                PRIMARY_ID=`repmgr -f ${DIRNAME}/${CONFIG_FILE_REMOTE} cluster show \
			                        | grep primary | grep running | cut -d'|' -f1 \
			                        | tr -d ' '`
			                repmgr -f ${DIRNAME}/${CONFIG_FILE_LOCAL} node rejoin \
			                        -d "postgres://repmgr@${PRIMARY}:5432/repmgr" \
			                        --force-rewind
			                if [ $? -ne 0 ]
			                then
			                        echo "First recovery failed - trying clean shutdown first"
			                        pg_ctl -D ${PGDATA} start
			                        sleep 3
			                        pg_ctl -D ${PGDATA} stop
			                        repmgr -f ${DIRNAME}/${CONFIG_FILE_LOCAL} node rejoin \
			                                -d "postgres://repmgr@${PRIMARY}:5432/repmgr" \
			                                --force-rewind
			                fi
			                repmgr -f ${DIRNAME}/${CONFIG_FILE_LOCAL} standby register \
			                        --force --upstream-node-id=${PRIMARY_ID}
			        else
			                ${DIRNAME}/db_start.sh
			        fi
			
	c. Edit /etc/systemd/system/postgresql-9.6.service:
		i. Change Type=notify  …to… Type=forking
		ii. Change ExecStart=/usr/pgsql-9.6/bin/postmaster -D ${PGDATA} …to… ExecStart=/etc/repmgr/9.6/switch_and_start.sh
		iii. Add: ExecStop=/usr/pgsql-9.6/bin/pg_ctl stop -D ${PGDATA}
systemctl daemon-reload
