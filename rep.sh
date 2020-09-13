#!/bin/bash
#
        REPMGR_CONF_DIR=/etc/repmgr/9.6
        PGDATA=/apps/pgsql/9.6/data

        pg_ctl -D ${PGDATA} status | grep -q 'is running'
        if [ $? -eq 0 ]
        then
                CONF_OPT=local
        else
                CONF_OPT=remote
        fi

        repmgr -f ${REPMGR_CONF_DIR}/repmgr_${CONF_OPT}.conf $*

