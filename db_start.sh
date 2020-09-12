#!/bin/bash
#
        OOMScoreAdjust=-1000
        export PGDATA=/apps/pgsql/9.6/data/
        export PG_OOM_ADJUST_FILE=/proc/self/oom_score_adj
        export PG_OOM_ADJUST_VALUE=0

        /usr/pgsql-9.6/bin/postgresql96-check-db-dir ${PGDATA}
        /usr/pgsql-9.6/bin/pg_ctl start -D ${PGDATA}

