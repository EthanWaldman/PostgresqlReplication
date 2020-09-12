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

