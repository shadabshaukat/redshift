Redshift Queries
~~~~~~~~~~~~~~~~

psql -h easyoradba.c2nh0wlf4z7g.ap-southeast-2.redshift.amazonaws.com -p 5439 -U awsuser dev
postgres-> \l
postgres-> \c myproddb


--http://raghavt.blogspot.com.au/2011/11/deadlocks-in-postgresql.html
SELECT = AcessShareLock : It acquired automatically by a SELECT statement on the table or tables it retrieves from. This mode blocks ALTER TABLE, DROP TABLE, and  VACUUM (AccessExclusiveLock) on the same table
INSERT = ShareRowExclusiveLock: This lock mode nearly identical to the ExclusiveLock, but which allows concurrent RowShareLock to be acquired.
COPY = ShareRowExclusiveLock: This lock mode nearly identical to the ExclusiveLock, but which allows concurrent RowShareLock to be acquired.
Both will be locking each other

-- Running queries
select pid, user_name, starttime, query
from stv_recents
where status='Running';

-- Join the superuser query_group 
set query_group to 'superuser'; 

-- Confirm current user is superuser 




-- Confirm appropriate query_group 
show query_group; 

-- Gather running query information 
select * from stv_inflight; 

-- Gather locks information 
select current_time, 
c.relname, 
l.database, 
l.transaction, 
l.pid, 
a.usename, 
l.mode, 
l.granted 
from pg_catalog.pg_locks l 
join pg_catalog.pg_class c on c.oid = l.relation 
join pg_catalog.pg_stat_activity a on a.procpid = l.pid; 

select l.pid, a.usename, d.datname, c.relname, l.mode, l.granted
from pg_catalog.pg_locks l
join pg_catalog.pg_class c on c.oid = l.relation
join pg_catalog.pg_stat_activity a on a.procpid = l.pid
left join pg_catalog.pg_database d on d.oid = l.database
order by c.relname,l.mode;

-- Pending transations in order (you can see the locking order)

select p.table,t.* from svv_transactions t, svv_table_info p where  t.relation=p.table_id and t.relation=108379 order by t.txn_start;

-- STV_LOCKS

select * from stv_locks

-- Cancel the stuck query 
select pg_terminate_backend(pid); 

select pg_cancel_backend(pid);

-- Check locks again 
select current_time, 
l.pid,
c.relname, 
l.database, 
l.transaction, 
l.pid, 
a.usename, 
l.mode, 
l.granted 
from pg_catalog.pg_locks l 
join pg_catalog.pg_class c on c.oid = l.relation 
join pg_catalog.pg_stat_activity a on a.procpid = l.pid; 

-- Check inflight again 
select * from stv_inflight;

-- Please use this query to find any other existing processes which are holding a lock on the table:

select current_time,
       c.relname,
       l.database,
       l.transaction,
       l.pid,
       a.usename,
       l.mode,
       l.granted
from pg_catalog.pg_locks l
join pg_catalog.pg_class c on c.oid = l.relation
join pg_catalog.pg_stat_activity a on a.procpid = l.pid;

-- Once you identify the offending process you can forcefully terminate that process once you deem it is safe to do so, this will free up the lock and the TRUNCATE table command will be able to proceed. Terminate the blocking process with:

SELECT pg_terminate_backend(pid);

-- Find blocking process

SELECT 
bl.pid AS blocked_pid,a.usename AS blocked_user,
ka.current_query AS blocking_statement,now() - ka.query_start AS blocking_duration,
kl.pid AS blocking_pid,ka.usename AS blocking_user,
a.current_query AS blocked_statement,now() - a.query_start AS blocked_duration
FROM 
pg_catalog.pg_locks bl
LEFT JOIN pg_catalog.pg_stat_activity a ON a.procpid = bl.pid
LEFT JOIN pg_catalog.pg_locks kl ON kl.transaction = bl.transaction AND kl.pid != bl.pid
LEFT JOIN pg_catalog.pg_stat_activity ka ON ka.procpid = kl.pid
WHERE NOT bl.granted;

-- Queue time

SELECT 
userid, xid, query, service_class, queue_start_time, 
exec_start_time, total_queue_time/1000000::DECIMAL queue_seconds, total_exec_time/1000000::DECIMAL exec_seconds 
FROM stl_wlm_query 
WHERE query = <REPLACE_WITH_QUERY_ID_HERE>;

-- Cancel a query
select pid, trim(user_name), starttime, substring(query,1,20) 
from stv_recents
where status='Running';
cancel 18764;

-- last queries
select query, pid, elapsed, substring from svl_qlog
where userid = 100
order by starttime desc
limit 5;

-- users
select * from pg_user;

-- dist Keys, analyze, usorted region
select * from svv_table_info t where t.table = ‘users’;

-- Cancel a query
select pid, trim(user_name), starttime, substring(query,1,20) 
from stv_recents
where status='Running';
cancel 18764;

-- last queries
select query, pid, elapsed, substring from svl_qlog
where userid = 100
order by starttime desc
limit 5;

-- users
select * from pg_user;

-- Keys
select * from svv_table_info t where t.table = ‘users’;

-- Records an alert when the query optimizer identifies conditions that might indicate performance issues.

SELECT 
query, substring(event,0,25) as event,  substring(solution,0,25) as solution,  trim(event_time) as event_time 
from stl_alert_event_log 
order by query;

-- Logs information about network activity during execution of query steps that broadcast data. Network traffic is captured by numbers of rows, bytes, and packets that are sent over the network during a given step on a given slice.

select 
query, slice, step, rows, bytes, packets, 
datediff(seconds, starttime, endtime) 
from stl_bcast
 where packets>0 and 
datediff(seconds, starttime, endtime)>0;

-- Provides metrics related to commit performance, including the timing of the various stages of commit and the number of blocks committed. 

select 
node, datediff(ms,startqueue,startwork) as queue_time,  
datediff(ms, startwork, endtime) as commit_time, queuelen 
from stl_commit_stats 
where xid = 2574 
order by node;  

-- Analyzes aggregate execution steps for queries. These steps occur during execution of aggregate functions and GROUP BY clauses.

select 
query, segment, bytes, slots, occupied, maxlength, 
is_diskbased, workmem, type 
from stl_aggr 
where slice=1 and 
tbl=239 
order by rows limit 10;

-- Records all errors that occur while running queries.

select 
process, errcode, file, linenum as line,  trim(error) as err 
from stl_error 
where pid=pg_backend_pid();

-- explain plan break down by node

explain select distinct eventname from event order by 1;  

select * from stl_plan_info where query=240 order by nodeid desc;  

-- query details

select query, datediff(seconds, starttime, endtime), trim(querytxt) as sqlquery from stl_query where starttime >= '2013-02-15';


-- Disk space distribution, used, free

select owner, host, diskno, used, capacity, capacity-used free,(used-tossed)/capacity::numeric *100 as pctused  from stv_partitions order by owner;

-- Table columns

select * 
from pg_table_def pgtd
where 
pgtd.column like '%wait%'
;

-- Break down 

select * from svl_query_summary where query = MyQueryID order by stm, seg, step;

-- search tables
select * from pg_tables where tablename like '%infli%';

-- search columns
select * from pg_table_def td where td.column like '%tomb%';

-- Query REPORT - Replace with query id

select 
query, segment, step, label ,is_rrscan as rrS, is_diskbased as disk, 
is_delayed_scan as DelayS,  min(start_time) as starttime, max(end_time) as endtime, 
datediff(ms, min(start_time), max(end_time))  as "elapsed_msecs", sum(rows) as row_s , 
sum(rows_pre_filter) as rows_pf, 
CASE WHEN sum(rows_pre_filter) = 0 THEN 100 ELSE sum(rows)::float/sum(rows_pre_filter)::float*100 END as pct_filter, 
SUM(workmem)/1024/1024 as "Memory(MB)", SUM(bytes)/1024/1024 as "MB_produced" 
from 
svl_query_report where 
query in (1966867) 
group by 
query, segment, step, label , 
is_rrscan, is_diskbased , is_delayed_scan 
order by query, segment, step, label;

-- Blocks Distribution

select 
slice/2 as node, CASE 
WHEN tbl > 0 THEN 'User_Table' 
WHEN tbl = 0 THEN 'Freed_Blocks' 
WHEN tbl = -2 THEN 'Catalog_File_Store' 
WHEN tbl = -3 THEN 'Metadata' 
WHEN tbl = -4 THEN 'Temp_Delete_Blocks' 
WHEN tbl = -6 THEN 'Query_Spill_To_Disk' 
ELSE 'Stage_blocks_For_Real_Table_DML' END as Block_type, 
CASE when tombstone > 0 THEN 'Tombstoned' ELSE 'Not Tombstoned' END as tombstone, count(*) 
from 
stv_blocklist 
group by 1, 2, 3 order by 1, 3, 2;

-- QUERY CONCURRENCY
*_WLM_*
select * from stv_wlm_query_state order by query;

Column
Description
query
The query ID.
queue
The queue number.
slot_count
The number of slots allocated to the query.
start_time
The time that the query started.
state
The state of the query, such as executing.
queue_time
The number of microseconds that the query has spent in the queue.
exec_time
The number of microseconds that the query has been executing.

-- Queue state

select (config.service_class-5) as queue
, trim (class.condition) as description
, config.num_query_tasks as slots
, config.query_working_mem as mem
, config.max_execution_time as max_time
, config.user_group_wild_card as "user_*"
, config.query_group_wild_card as "query_*"
, state.num_queued_queries queued
, state.num_executing_queries executing
, state.num_executed_queries executed
from
STV_WLM_CLASSIFICATION_CONFIG class,
STV_WLM_SERVICE_CLASS_CONFIG config,
STV_WLM_SERVICE_CLASS_STATE state
where
class.action_service_class = config.service_class 
and class.action_service_class = state.service_class 
and config.service_class > 4
order by config.service_class;

-- long queue time queries
select trim(database) as DB , w.query, 
substring(q.querytxt, 1, 100) as querytxt,  w.queue_start_time, 
w.service_class as class, w.slot_count as slots, 
w.total_queue_time/1000000 as queue_seconds, 
w.total_exec_time/1000000 exec_seconds, (w.total_queue_time+w.total_Exec_time)/1000000 as total_seconds 
from stl_wlm_query w 
left join stl_query q on q.query = w.query and q.userid = w.userid 
where w.queue_start_Time >= dateadd(day, -7, current_Date) 
and w.total_queue_Time > 0  and w.userid >1   
and q.starttime >= dateadd(day, -7, current_Date) 
order by w.total_queue_time desc, w.queue_start_time desc limit 35;

--View Average Query Time in Queues and Executing 
select service_class as svc_class, count(*),
avg(datediff(microseconds, queue_start_time, queue_end_time)) as avg_queue_time,
avg(datediff(microseconds, exec_start_time, exec_end_time )) as avg_exec_time,
max(datediff(microseconds, queue_start_time, queue_end_time)) as max_queue_time,
max(datediff(microseconds, exec_start_time, exec_end_time )) as max_exec_time
from stl_wlm_query
where service_class > 4
group by service_class
order by service_class;

--View Maximum Query Time in Queues and Executing 
select service_class as svc_class, count(*),
max(datediff(microseconds, queue_start_time, queue_end_time)) as max_queue_time,
max(datediff(microseconds, exec_start_time, exec_end_time )) as max_exec_time
from stl_wlm_query
where svc_class > 5  
group by service_class
order by service_class;

-- Query advisor
Select * from stl_alert_event_log where query = <qid>
select * from svl_query_summary where query = MyQueryID order by stm, seg, step;
select * from svl_query_report where query = MyQueryID order by segment, step, elapsed_time, rows;

--Tables , stats, skew, unsort

select trim(pgn.nspname) as schema, 
trim(a.name) as table, id as tableid, 
decode(pgc.reldiststyle,0, 'even',1,det.distkey ,8,'all') as distkey, dist_ratio.ratio::decimal(10,4) as skew, 
det.head_sort as "sortkey", 
det.n_sortkeys as "#sks", b.mbytes,  
decode(b.mbytes,0,0,((b.mbytes/part.total::decimal)*100)::decimal(5,2)) as pct_of_total, 
decode(det.max_enc,0,'n','y') as enc, a.rows, 
decode( det.n_sortkeys, 0, null, a.unsorted_rows ) as unsorted_rows , 
decode( det.n_sortkeys, 0, null, decode( a.rows,0,0, (a.unsorted_rows::decimal(32)/a.rows)*100) )::decimal(5,2) as pct_unsorted 
from (select db_id, id, name, sum(rows) as rows, 
sum(rows)-sum(sorted_rows) as unsorted_rows 
from stv_tbl_perm a 
group by db_id, id, name) as a 
join pg_class as pgc on pgc.oid = a.id
join pg_namespace as pgn on pgn.oid = pgc.relnamespace
left outer join (select tbl, count(*) as mbytes 
from stv_blocklist group by tbl) b on a.id=b.tbl
inner join (select attrelid, 
min(case attisdistkey when 't' then attname else null end) as "distkey",
min(case attsortkeyord when 1 then attname  else null end ) as head_sort , 
max(attsortkeyord) as n_sortkeys, 
max(attencodingtype) as max_enc 
from pg_attribute group by 1) as det 
on det.attrelid = a.id
inner join ( select tbl, max(mbytes)::decimal(32)/min(mbytes) as ratio 
from (select tbl, trim(name) as name, slice, count(*) as mbytes
from svv_diskusage group by tbl, name, slice ) 
group by tbl, name ) as dist_ratio on a.id = dist_ratio.tbl
join ( select sum(capacity) as  total
from stv_partitions where part_begin=0 ) as part on 1=1
where mbytes is not null 
order by  mbytes desc;

-- copy Load Errors

select distinct tbl, trim(name) as table_name, query, starttime,
trim(filename) as input, line_number, trim(colname) coluname, err_code,
trim(err_reason) as reason
from stl_load_errors sl, stv_tbl_perm sp
where sl.tbl = sp.id
order by sl.starttime;

-- PSQL Auto login - Extract data

ec2-user@ip-172-31-42-235 ~]$ cat ~/.pgpass 
rs-demo-cluster.cwruxt5jfc6m.us-west-2.redshift.amazonaws.com:5439:dev:master:Master11

[ec2-user@ip-172-31-42-235 ~]$ psql -h rs-demo-cluster.cwruxt5jfc6m.us-west-2.redshift.amazonaws.com -p 5439 -U master dev -F -A -c 'select * from stv_recents' | sed "s/   *//g" >> recents.txt


-- compile 

select 
--compile,count(1)
*
from svl_qlog ql, svl_compile c
where ql.substring like 'EXEC%'
and ql.query=c.query
group by c.compile
;

-- Using variables

CAT <<EOF | psql -h <endpoint> -p 5439 -U master dev -f -
PREPARE prep_insert_plan (int,int,int) as select count(1) from users
where userid in (\$1,\$2,\$3);
EXECUTE prep_insert_plan ($RAND1,$RAND2,$RAND3);
DEALLOCATE prep_insert_plan;
select compile,count(1)
from svl_qlog ql, svl_compile c
where ql.substring like 'EXEC%'
and ql.query=c.query
group by c.compile
;
EOF

-- Current pid

select pg_backend_pid();
select * FROM pg_stat_activity where procpid = pg_backend_pid();
SELECT * FROM pg_stat_activity WHERE usename = 'master';

-- Every time a lock conflict occurs, Amazon Redshift writes an entry to the below

SELECT 
  n.nspname,
  c.relname,
  t.xact_id,
  t.process_id,
  t.xact_start_ts,
  t.abort_time
FROM stl_tr_conflict t,
  pg_class c,
  pg_namespace n
WHERE 
    c.oid = t.table_id
AND c.relnamespace = n.oid;

-- UDF
-- https://aws.amazon.com/blogs/aws/user-defined-functions-for-amazon-redshift/

--NOTE: Supported on versions begger or equal than 1.0.991

dev=# SELECT lanname, lanispl, lanpltrusted, lanplcallfoid, lanvalidator, lanacl FROM pg_language;
  lanname  | lanispl | lanpltrusted | lanplcallfoid | lanvalidator |     lanacl      
-----------+---------+--------------+---------------+--------------+-----------------
 internal  | f       | f            |             0 |         2246 | 
 c         | f       | f            |             0 |         2247 | 
 sql       | f       | t            |             0 |         2248 | {=U/rdsdb}
 plpgsql   | t       | t            |        100058 |       100059 | 
 plpythonu | t       | f            |        100056 |       100055 | {rdsdb=U/rdsdb}
(5 rows)

CREATE FUNCTION week_starting_sunday (date_col TIMESTAMP)
RETURNS VARCHAR
STABLE
AS $$
from datetime import datetime, timedelta
day = str(date_col)
dt = datetime.strptime(day, '%Y-%m-%d %H:%M:%S')
week = dt - timedelta((dt.weekday() + 1) % 7)
return week.strftime('%Y-%m-%d')
$$ LANGUAGE plpythonu;



dev=# select week_starting_sunday ('2015-08-01 23:59:45');
 week_starting_sunday 
----------------------
 2015-07-26
(1 row)

CREATE FUNCTION f_hostname(url VARCHAR)
RETURNS varchar
IMMUTABLE AS $$
import urlparse
return urlparse.urlparse(url).hostname
$$ LANGUAGE plpythonu;

dev=# select f_hostname('http://www.google.com');
   f_hostname   
----------------
 www.google.com
(1 row)

-- http://docs.aws.amazon.com/redshift/latest/dg/udf-security-and-privileges.html
UDF Security and Privileges
Superusers have all privileges by default. Users must have the following privileges to work with UDFs:
    To create a UDF or a UDF library, you must have USAGE ON LANGUAGE plpythonu.
    To replace or drop a UDF or library, you must be the owner or a superuser.
    To execute a UDF, you must have EXECUTE ON FUNCTION for each function. By default, the PUBLIC user group has execute permission for new UDFs. To restrict usage, revoke EXECUTE from PUBLIC, then grant the privilege to specific individuals or groups.


dev=# grant USAGE ON LANGUAGE plpythonu to riccic;
GRANT

dev=> CREATE FUNCTION f_hostname(url VARCHAR)
dev-> RETURNS varchar
dev-> IMMUTABLE AS $$
dev$> import urlparse
dev$> return urlparse.urlparse(url).hostname
dev$> $$ LANGUAGE plpythonu;CREATE FUNCTION f_hostname1(url VARCHAR)
ERROR:  function "f_hostname" already exists with same argument types
dev-> RETURNS varchar
dev-> IMMUTABLE AS $$
dev$> import urlparse
dev$> return urlparse.urlparse(url).hostname
dev$> $$ LANGUAGE plpythonu;
CREATE FUNCTION
dev=> select f_hostname('http://www.amazon.com');
   f_hostname   
----------------
 www.amazon.com
(1 row)


-- Create User
dev=# CREATE USER riccic with password 'Riccic1234';
dev=# grant USAGE ON LANGUAGE plpythonu to riccic;

-- Security

-- grant superuser -> http://docs.aws.amazon.com/redshift/latest/dg/r_superusers.html

dev=# alter user riccic createuser;
ALTER USER
dev=# select * from pg_user;
 usename | usesysid | usecreatedb | usesuper | usecatupd |  passwd  | valuntil | useconfig 
---------+----------+-------------+----------+-----------+----------+----------+-----------
 rdsdb   |        1 | t           | t        | t         | ******** | infinity | 
 master  |      100 | t           | t        | f         | ******** |          | 
 guest   |      102 | f           | f        | f         | ******** |          | 
 riccic  |      103 | f           | t        | f         | ******** |          | 
(4 rows)

dev=# show all;
         name         |    setting    
----------------------+---------------
 datestyle            | ISO, MDY
 extra_float_digits   | 0
 query_group          | default
 search_path          | $user, public
 statement_timeout    | 0
 wlm_query_slot_count | 1
(6 rows)

dev=# set search_path = '$user', public;

-- Query UDF

dev=# CREATE FUNCTION f_hostname1(url VARCHAR)
RETURNS varchar
IMMUTABLE AS $$
import urlparse
return urlparse.urlparse(url).hostname
$$ LANGUAGE plpythonu;
CREATE FUNCTION

dev=# select * from pg_proc where proname = 'f_hostname';
  proname   | pronamespace | proowner | prolang | proisagg | prosecdef | proisstrict | proretset | provolatile | pronargs | prorettype | proargtypes | proargnames |                 prosrc                 | probin | pro
acl 
------------+--------------+----------+---------+----------+-----------+-------------+-----------+-------------+----------+------------+-------------+-------------+----------------------------------------+--------+----
----
 f_hostname |         2200 |      103 |  100057 | f        | f         | f           | f         | i           |        1 |       1043 | 1043        | {url}       |                                       +| -1:-1  | 
            |              |          |         |          |           |             |           |             |          |            |             |             | import urlparse                       +|        | 
            |              |          |         |          |           |             |           |             |          |            |             |             | return urlparse.urlparse(url).hostname+|        | 
            |              |          |         |          |           |             |           |             |          |            |             |             |                                        |        | 
(1 row)

dev=# SELECT pp.proname,pl.lanname
  FROM pg_proc pp
 INNER JOIN pg_namespace pn on (pp.pronamespace = pn.oid)
 INNER JOIN pg_language pl on (pp.prolang = pl.oid)
 WHERE pl.lanname NOT IN ('c','internal') 
   AND pn.nspname NOT LIKE 'pg_%'
   AND pn.nspname <> 'information_schema';

  proname   |  lanname  
------------+-----------
 f_hostname | plpythonu
(1 row)

--- Find query with BEGIN / SAVEPOINT
http://docs.aws.amazon.com/redshift/latest/mgmt/connecting-incomplete-query-issues.html




-- status of LOAD

select * from STV_LOAD_STATE where pid = 40516; 
select * from STL_LOAD_ERRORS where pid = 40516;

-- Clear space

http://docs.aws.amazon.com/redshift/latest/dg/r_SVV_TABLE_INFO.html for more information about columns.

size		Size of the table, in 1 MB data blocks.
pct_used  	Percent of available space that is used by the table.
empty		Number of 1 MB blocks that have been marked for deletion, or tombstoned.

If empty column is very high, You can also try running vacuum http://docs.aws.amazon.com/redshift/latest/dg/r_VACUUM_command.html and claim space occupied and deleted rows.

VACUUM DELETE ONLY <TABLE>;
or
VACUUM DELETE ONLY;

Reclaims disk space occupied by rows that were marked for deletion by previous UPDATE and DELETE operations, and compacts the table to free up the consumed space. A DELETE ONLY vacuum operation does not sort the data. This option reduces the elapsed time for vacuum operations when reclaiming disk space is important but resorting new rows is not important. This option might also apply when your query performance is already optimal, such that resorting rows to optimize query performance is not a requirement.

-- Sleep UDF

CREATE FUNCTION sleep(vtime integer)
returns integer
IMMUTABLE AS $$
import time
time.sleep(vtime)
return vtime
$$ LANGUAGE plpythonu;

select i.database,i.schema,i.table,c.process_id,c.abort_time from stl_tr_conflict c,svv_table_info i where c.table_id=i.table_id;

-- UNLOAD Example
unload ('select * from users') to 's3://riccic-oregon/users.csv' credentials 'aws_access_key_id=AKIAIQAUQ2UBXLX4GUJQ;aws_secret_access_key=---' allowoverwrite;
copy users_stg from 's3://riccic-oregon/users.csv0001_part_00' credentials 'aws_access_key_id=AKIAIQAUQ2UBXLX4GUJQ;aws_secret_access_key=---';
copy users_stg from 's3://riccic-oregon/users.csv0000_part_00' credentials 'aws_access_key_id=AKIAIQAUQ2UBXLX4GUJQ;aws_secret_access_key=---';


copy rawdata from 's3://ivabucket/load/po.txt'
credentials 'aws_access_key=AKIAJOOSKCWF5MEP2OHA;aws_secret_access_key=---' 
delimiter '\t' IGNOREHEADER 1; 

copy rawdata from 's3://ivabucket/load/po.txt' credentials 'aws_access_key_id=AKIAJOOSKCWF5MEP2OHA;aws_secret_access_key=---' delimiter '\t' IGNOREHEADER 1;

-- Space distribution per slice

SELECT		b.slice		
		,TRIM(pgdb.datname) AS dbase_name
		,TRIM(pgn.nspname) as schemaname
		,TRIM(a.name) AS tablename
		,id AS tbl_oid
		,b.mbytes AS megabytes
		,a.rows AS rowcount
		,a.unsorted_rows AS unsorted_rowcount
		,CASE WHEN a.rows = 0 then 0
			ELSE ROUND((a.unsorted_rows::FLOAT / a.rows::FLOAT) * 100, 5)
		END AS pct_unsorted
		,CASE WHEN a.rows = 0 THEN 'n/a'
			WHEN (a.unsorted_rows::FLOAT / a.rows::FLOAT) * 100 >= 20 THEN 'VACUUM recommended'
			ELSE 'n/a'
		END AS recommendation
FROM       (
       SELECT
              db_id
              ,id
              ,name
              ,SUM(rows) AS rows
              ,SUM(rows)-SUM(sorted_rows) AS unsorted_rows 
       FROM stv_tbl_perm
       GROUP BY db_id, id, name
       ) AS a 
INNER JOIN
       pg_class AS pgc 
              ON pgc.oid = a.id
INNER JOIN
       pg_namespace AS pgn 
              ON pgn.oid = pgc.relnamespace
INNER JOIN
       pg_database AS pgdb 
              ON pgdb.oid = a.db_id
LEFT OUTER JOIN
       (
       SELECT              
	      tbl
              ,COUNT(*) AS mbytes 
              ,slice
       FROM stv_blocklist
       WHERE slice != 0 
       GROUP BY slice,tbl
       ) AS b 
              ON a.id=b.tbl
ORDER BY 1,3,2,4;

-- Default ACL privileged

 At some point the default behavior of the public schema was changed, as we can see here clearly

 that this user doesn’t have permission to access this table by default:

SELECT
* 
FROM 
(
SELECT 
schemaname
,objectname
,usename
,HAS_TABLE_PRIVILEGE(usrs.usename, fullobj, 'select') AS sel
,HAS_TABLE_PRIVILEGE(usrs.usename, fullobj, 'insert') AS ins
,HAS_TABLE_PRIVILEGE(usrs.usename, fullobj, 'update') AS upd
,HAS_TABLE_PRIVILEGE(usrs.usename, fullobj, 'delete') AS del
,HAS_TABLE_PRIVILEGE(usrs.usename, fullobj, 'references') AS ref
FROM
(
SELECT schemaname, 't' AS obj_type, tablename AS objectname, schemaname + '.' + tablename AS fullobj FROM pg_tables
WHERE schemaname not in ('pg_internal')
UNION
SELECT schemaname, 'v' AS obj_type, viewname AS objectname, schemaname + '.' + viewname AS fullobj FROM pg_views
WHERE schemaname not in ('pg_internal')
) AS objs
,(SELECT * FROM pg_user) AS usrs
ORDER BY fullobj
)
WHERE usename='pgadam' and schemaname='public' and objectname='test_1';

 schemaname | objectname | usename | sel | ins | upd | del | ref
------------+------------+---------+-----+-----+-----+-----+-----
 public     | test_1     | pgadam  | f   | f   | f   | f   | f
(1 row)

If you are interested in restoring the default behavior of the public schema you would want to use http://docs.aws.amazon.com/redshift/latest/dg/r_ALTER_DEFAULT_PRIVILEGES.html to do so. 

--- Check privilege on the table

SELECT has_table_privilege('myschema.mytable', 'select');

-- Space:
select owner, host, diskno, used, capacity,
(used-tossed)/capacity::numeric *100 as pctused 
from stv_partitions order by owner;

select ti.database,ti.schema,ti.table,ti.size,ti.pct_used,ti.unsorted,ti.stats_off,ti.skew_rows,ti.skew_sortkey1 from svv_table_info ti order by size desc;

-- Most common queries by hour

select * from stl_error 
where 
recordtime between '2016-04-03 03:12:00' and '2016-04-03 03:28:00';

select * from stl_querytext
where
text ilike 'copy%agg_avails_zone_compress%'
; 

select substring(querytxt,1,60),starttime,aborted,xid,pid,query,label from stl_query 
where 
recordtime between '2016-04-03 03:12:00' and '2016-04-03 03:28:00';
and querytxt ilike 'copy%agg_avails_zone_compress%';

-- groups (only used for WLM)

http://docs.aws.amazon.com/redshift/latest/dg/t_user_group_examples.html 

dev=# create group readonlygroup;
CREATE GROUP

dev=# select * from pg_group;
         groname         | grosysid | grolist 
-------------------------+----------+---------
 grp_slow_query          |      100 | {102}
 services_group          |      101 | {108}
 tableau_reporting_group |      102 | 
 readonlygroup           |      103 | 
(4 rows)

dev=# alter group admin_group add user dwuser;

--- Privileges - check
Look into https://github.com/awslabs/amazon-redshift-utils/tree/master/src/AdminViews
search for *priv* scripts

--- Create a readonly group and assing select to a view
\dn+ schemas
\l+ databases
\du+ roles/users
\dg+
\dp     [PATTERN]      list table, view, and sequence access privileges


dev=# \c cases

cases=# set search_path to 1677362131,1679987651,'$user',public;

-- Count of statements
select count(1),upper(regexp_substr(querytxt,'\[a-zA-Z\]* ')),trunc(starttime) from stl_query group by upper(regexp_substr(querytxt,'\[a-zA-Z\]* ')),trunc(starttime) order by 3;
select userid,process,recordtime,pid,errcode,trim(file),linenum,trim(context),trim(error) from stl_error where recordtime between getdate()-1 and getdate();

-- Space

select sum(used) as used,sum(capacity) as capacity,sum(capacity)/1024 as capacity_gbytes, 
sum(used)/1024 as used_gbytes,sum(used-tossed)/sum(capacity)::numeric *100 as pctused
from 
stv_partitions where part_begin=0;

 used  | capacity | capacity_gbytes | used_gbytes |        pctused        
-------+----------+-----------------+-------------+-----------------------
 16340 |   381266 |             372 |          15 | 4.2851972113957184700
(1 row)

select                                                                                                                                                  
  sum(used)/1024 as used_gbytes, 
  (sum(capacity) - sum(used))/1024 as free_gbytes 
from 
  stv_partitions where part_begin=0;

 capacity_gbytes | used_gbytes | free_gbytes 
-----------------+-------------+-------------
             558 |          18 |         540
(1 row)
--- General Abort query troubleshooting

1) STL_QUERY abort copies

select userid,query,label,xid,pid,database,starttime,endtime,aborted,insert_pristine,trim(querytxt) from stl_query where aborted=1 and querytxt ilike '%copy tblunifiedlog %'; 

2) Review WLM Queuing for above queries. Ref: 

SELECT TRIM(DATABASE) AS DB,
       w.query,
       SUBSTRING(q.querytxt,1,100) AS querytxt,
       w.queue_start_time,
       w.service_class AS class,
       w.slot_count AS slots,
       w.total_queue_time / 1000000 AS queue_seconds,
       w.total_exec_time / 1000000 exec_seconds,
       (w.total_queue_time + w.total_exec_time) / 1000000 AS total_seconds
FROM stl_wlm_query w
  LEFT JOIN stl_query q
         ON q.query = w.query
        AND q.userid = w.userid
WHERE w.queue_start_time >= DATEADD (day,-7,CURRENT_DATE)
AND   w.total_queue_time > 0
AND   w.userid > 1
AND   q.starttime >= DATEADD (day,-7,CURRENT_DATE)
AND   w.query in (select query from stl_query where querytxt ilike '%copy <TBALE> %')
--AND   w.query in (select query from stl_query where querytxt ilike '%copy tblunifiedlog %')
ORDER BY w.total_queue_time DESC,
         w.queue_start_time DESC;

3) Get information about commit stats

select startqueue,node, datediff(ms,startqueue,startwork) as queue_time, datediff(ms, startwork, endtime) as commit_time, queuelen 
from stl_commit_stats 
where startqueue >=  dateadd(day, -2, current_Date)
order by queuelen desc , queue_time desc;

4) Understand other operations within the same PID

select userid,xid,pid,label,starttime,endtime,sequence,type,trim(text) from svl_statementtext where pid in (select pid from stl_query where aborted=1 and querytxt ilike '%copy tblunifiedlog %');

5) Review query work

select * from STL_PLAN_INFO where query in (select query from stl_query where aborted=1 and querytxt ilike '%copy tblunifiedlog %' limit 2);
select * from svl_query_report where query in (select query from stl_query where aborted=1 and querytxt ilike '%copy tblunifiedlog %' limit 2);
select * from svl_query_summary where query in (select query from stl_query where aborted=1 and querytxt ilike '%copy tblunifiedlog %' limit 2);

6) Get Errors from LOAD and ERROR tables

select * from STL_LOAD_ERRORS where query in (select query from stl_query where aborted=1 and querytxt ilike 'COPY options FROM
%' limit 2);

-- statement work per day
select count(1),upper(regexp_substr(querytxt,'\[a-zA-Z\]* ')),trunc(starttime) from stl_query group by upper(regexp_substr(querytxt,'\[a-zA-Z\]* ')),trunc(starttime) order by 3;
-- statement work per hour
select count(1),upper(regexp_substr(querytxt,'\[a-zA-Z\]* ')),to_char(starttime,'dd-mm-yyyy hh24') from stl_query group by upper(regexp_substr(querytxt,'\[a-zA-Z\]* ')),to_char(starttime,'dd-mm-yyyy hh24') order by 3;

-- Stl error
select userid,process,recordtime,pid,errcode,trim(file),linenum,trim(context),trim(error) from stl_error where recordtime between getdate()-1 and getdate();


\timing on
\o case_1744339091.txt
\conninfo
\set vpattern '\'COPY %\''
--STL_QUERY abort copies
select userid,query,label,xid,pid,database,starttime,endtime,aborted,insert_pristine,trim(querytxt) from stl_query where aborted=1 and querytxt ilike :vpattern; 
--Review WLM Queuing for above queries. Ref: 
SELECT TRIM(DATABASE) AS DB,
       w.query,
       SUBSTRING(q.querytxt,1,100) AS querytxt,
       w.queue_start_time,
       w.service_class AS class,
       w.slot_count AS slots,
       w.total_queue_time / 1000000 AS queue_seconds,
       w.total_exec_time / 1000000 exec_seconds,
       (w.total_queue_time + w.total_exec_time) / 1000000 AS total_seconds
FROM stl_wlm_query w
  LEFT JOIN stl_query q
         ON q.query = w.query
        AND q.userid = w.userid
WHERE w.queue_start_time >= DATEADD (day,-7,CURRENT_DATE)
AND   w.total_queue_time > 0
AND   w.userid > 1
AND   q.starttime >= DATEADD (day,-7,CURRENT_DATE)
AND   w.query in (select query from stl_query where querytxt ilike :vpattern)
ORDER BY w.total_queue_time DESC,
         w.queue_start_time DESC;
--Get information about commit stats
select startqueue,node, datediff(ms,startqueue,startwork) as queue_time, datediff(ms, startwork, endtime) as commit_time, queuelen 
from stl_commit_stats 
where startqueue >=  dateadd(day, -2, current_Date)
order by queuelen desc , queue_time desc;
--Understand other operations within the same PID
select userid,xid,pid,label,starttime,endtime,sequence,type,trim(text) from svl_statementtext where pid in (select pid from stl_query where aborted=1 and querytxt ilike :vpattern);
--Review query work
select * from STL_PLAN_INFO where query in (select query from stl_query where aborted=1 and querytxt ilike :vpattern limit 2);
select * from svl_query_report where query in (select query from stl_query where aborted=1 and querytxt ilike :vpattern limit 2);
select * from svl_query_summary where query in (select query from stl_query where aborted=1 and querytxt ilike :vpattern limit 2);
--Get Errors from LOAD and ERROR tables
select * from STL_LOAD_ERRORS where query in (select query from stl_query where aborted=1 and querytxt ilike :vpattern limit 2);
select userid,process,recordtime,pid,errcode,trim(file),linenum,trim(context),trim(error) from stl_error where recordtime between getdate()-1 and getdate();
\q

--- Disk Full Queries

** This is what show in the performance tab
select node_num,value from stv_fdisk_stats where name='blocks_allocated_total'


**Estimated disk capacity consumption

select
  sum(capacity)/1024 as capacity_gbytes, 
  sum(used)/1024 as used_gbytes, 
  (sum(capacity) - sum(used))/1024 as free_gbytes 
from 
  stv_partitions where part_begin=0;

** Total distribution skew for a particular table

SELECT tbl, name, MIN(Mbytes), MAX(Mbytes) FROM
    (
    SELECT tbl, name, slice, COUNT(*) AS Mbytes
    FROM svv_diskusage
    WHERE name='TABLE_NAME_HERE'
    GROUP BY tbl, name, slice
    )
    GROUP BY tbl, name
    ORDER BY MIN(Mbytes)/MAX(Mbytes);

** Total distribution skew per table (for all tables), sorted alphabetically

SELECT tbl, name, MIN(Mbytes), MAX(Mbytes) FROM
    (
    SELECT tbl, name, slice, COUNT(*) AS Mbytes
    FROM svv_diskusage
    GROUP BY tbl, name, slice
    )
    GROUP BY tbl, name
    ORDER BY name;

** Total distribution skew per table (for all tables), sorted by skew

SELECT tbl, name, MIN(Mbytes), MAX(Mbytes) FROM
    (
    SELECT tbl, name, slice, COUNT(*) AS Mbytes
    FROM svv_diskusage
    GROUP BY tbl, name, slice
    )
    GROUP BY tbl, name
    ORDER BY MIN(Mbytes)/MAX(Mbytes)::DECIMAL;

** Detailed (per node, per slice) data distribution for a given table ID

SELECT tbl, name, s.node, s.slice, COUNT(*) AS blocks_total, SUM(unsorted) AS blocks_unsorted, SUM(tombstone) AS block_deleted FROM stv_slices s, svv_diskusage d WHERE s.slice=d.slice AND d.tbl = TABLE_ID_HERE GROUP BY name, tbl, node, s.slice;

** Detailed (per node, per slice) data distribution for a given table name

SELECT tbl, name, s.node, s.slice, COUNT(*) AS blocks_total, SUM(unsorted) AS blocks_unsorted, SUM(tombstone) AS block_deleted FROM stv_slices s, svv_diskusage d WHERE s.slice=d.slice AND d.name = 'TABLE_NAME_HERE' GROUP BY name, tbl, node, s.slice;

---

unload ('select * from users') to 's3://riccic-oregon/Water/users.csv' credentials 'aws_access_key_id=AKIAIAJTPMTWK4SIOD6A;aws_secret_access_key=---' allowoverwrite;

copy users_stg from 's3://riccic-oregon/users.csv0001_part_00' credentials '

            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:PutObject",
                "s3:GetObjectAcl",
                "s3:GetObjectVersionAcl",
                "s3:PutObjectAcl",
                "s3:PutObjectVersionAcl",
                "s3:DeleteObject",
                "s3:DeleteObjectVersion",
                "s3:ListMultipartUploadParts",
                "s3:AbortMultipartUpload",
                "s3:GetObjectTorrent",
                "s3:GetObjectVersionTorrent",
                "s3:RestoreObject"
            ],


{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "*"
            ],
            "Resource": [
                "arn:aws:s3:::riccic-oregon"
            ],
            "Effect": "Allow",
            "Sid": "AllowS3Listing"
        }
    ]
}


{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "*"
            ],
            "Resource": [
                "arn:aws:s3:::riccic-oregon"
            ],
            "Effect": "Allow",
            "Sid": "BLABLA"
        }
    ]
}


--- Outer Join

dev=# select * from table_a a order by a.c1;
 c1 | c2 
----+----
  1 | a
  2 | b
  3 | c
  4 | d
  5 | e
(5 rows)

dev=# select * from table_b b order by b.c1;
 c1 | c2 
----+----
  1 | A
  2 | B
  3 | C
(3 rows)

dev=# select * from table_a a left join table_b b on a.c1=b.c1 order by a.c1;
 c1 | c2 | c1 | c2 
----+----+----+----
  1 | a  |  1 | A
  2 | b  |  2 | B
  3 | c  |  3 | C
  4 | d  |    | 
  5 | e  |    | 
(5 rows)

dev=# select * from table_a a, table_b b where a.c1=b.c1(+) order by a.c1;
 c1 | c2 | c1 | c2 
----+----+----+----
  1 | a  |  1 | A
  2 | b  |  2 | B
  3 | c  |  3 | C
  4 | d  |    | 
  5 | e  |    | 
(5 rows)

dev=# select * from table_a a left join table_b b on (a.c1=b.c1 and a.c2='a') order by a.c1;
 c1 | c2 | c1 | c2 
----+----+----+----
  1 | a  |  1 | A
  2 | b  |    | 
  3 | c  |    | 
  4 | d  |    | 
  5 | e  |    | 
(5 rows)

dev=# explain select * from table_a a left join table_b b on (a.c1=b.c1 and b.c2='A') order by a.c1;
                                         QUERY PLAN                                          
---------------------------------------------------------------------------------------------
 XN Merge  (cost=1000000760000.22..1000000760000.23 rows=5 width=134)
   Merge Key: a.c1
   ->  XN Network  (cost=1000000760000.22..1000000760000.23 rows=5 width=134)
         Send to leader
         ->  XN Sort  (cost=1000000760000.22..1000000760000.23 rows=5 width=134)
               Sort Key: a.c1
               ->  XN Hash Left Join DS_BCAST_INNER  (cost=0.04..760000.16 rows=5 width=134)
                     Hash Cond: ("outer".c1 = "inner".c1)
                     ->  XN Seq Scan on table_a a  (cost=0.00..0.05 rows=5 width=67)
                     ->  XN Hash  (cost=0.04..0.04 rows=1 width=67)
                           ->  XN Seq Scan on table_b b  (cost=0.00..0.04 rows=1 width=67)
                                 Filter: ((c2)::text = 'A'::text)
 ----- Tables missing statistics: table_a, table_b -----
 ----- Update statistics by running the ANALYZE command on these tables -----
(14 rows)

dev=# select * from table_a a, table_b b where a.c1=b.c1(+) and b.c2(+)='A' order by a.c1;
 c1 | c2 | c1 | c2 
----+----+----+----
  1 | a  |  1 | A
  2 | b  |    | 
  3 | c  |    | 
  4 | d  |    | 
  5 | e  |    | 
(5 rows)

dev=# explain select * from table_a a, table_b b where a.c1=b.c1(+) and b.c2(+)='A' order by a.c1;
                                         QUERY PLAN                                          
---------------------------------------------------------------------------------------------
 XN Merge  (cost=1000000760000.22..1000000760000.23 rows=5 width=134)
   Merge Key: a.c1
   ->  XN Network  (cost=1000000760000.22..1000000760000.23 rows=5 width=134)
         Send to leader
         ->  XN Sort  (cost=1000000760000.22..1000000760000.23 rows=5 width=134)
               Sort Key: a.c1
               ->  XN Hash Left Join DS_BCAST_INNER  (cost=0.04..760000.16 rows=5 width=134)
                     Hash Cond: ("outer".c1 = "inner".c1)
                     ->  XN Seq Scan on table_a a  (cost=0.00..0.05 rows=5 width=67)
                     ->  XN Hash  (cost=0.04..0.04 rows=1 width=67)
                           ->  XN Seq Scan on table_b b  (cost=0.00..0.04 rows=1 width=67)
                                 Filter: ((c2)::text = 'A'::text)
 ----- Tables missing statistics: table_a, table_b -----
 ----- Update statistics by running the ANALYZE command on these tables -----
(14 rows)


--- Cluster space size

SELECT host,SUM(used), SUM(capacity) FROM stv_partitions WHERE host = owner GROUP BY host ORDER BY host;

--- WLM Queues details

dev=# select rtrim(name) as name, 
num_query_tasks as slots, 
query_working_mem as mem, 
max_execution_time as max_time, 
user_group_wild_card as user_wildcard, 
query_group_wild_card as query_wildcard
from stv_wlm_service_class_config
;
                        name                        | slots | mem  | max_time | user_wildcard | query_wildcard 
----------------------------------------------------+-------+------+----------+---------------+----------------
 Service class for system user (Health Check)       |     1 |  153 |        0 | false         | false   
 Service class for system user (Metrics Collection) |     1 |  153 |        0 | false         | false   
 Service class for system user (CM Stats)           |     2 |   76 |        0 | false         | false   
 Service class for system user (Operator)           |     1 |  382 |        0 | false         | false   
 Service class for super user                       |     1 |  535 |        0 | false         | false   
 Service class #1                                   |     5 | 1254 |        0 | false         | false   
(6 rows)

dev=# select rtrim(name) as name, num_query_tasks as slots, target_num_query_tasks as target_slots, query_working_mem as memory, target_query_working_mem as target_memory 
from stv_wlm_service_class_config;
                        name                        | slots | target_slots | memory | target_memory 
----------------------------------------------------+-------+--------------+--------+---------------
 Service class for system user (Health Check)       |     1 |            1 |    153 |           153
 Service class for system user (Metrics Collection) |     1 |            1 |    153 |           153
 Service class for system user (CM Stats)           |     2 |            2 |     76 |            76
 Service class for system user (Operator)           |     1 |            1 |    382 |           382
 Service class for super user                       |     1 |            1 |    535 |           535
 Service class #1                                   |     5 |            5 |   1254 |          1254
(6 rows)

You have two nodes with 244Gb each right, the numbers you are seeing are per slot per node.  

Let's say out of the 244gb, 122gb (half of the total memory) is allocated to query queues.  The rest of the memory is used by the redshift background processes, super user queues, OS file caching etc.  

The  memory allocation to your first queue will be (122*0.49)/6  which is roughly the amount you are seeing.  Similarly on your second queue the memory allocated will be (122*0.2)/10 which is again close to what you see in the WLM tables.  

--- hsasun

(09:24:11) Annie Sun: rs-nirvana: logs
rs: /rdsdbdata/data/logs

(09:24:20) Annie Sun: for start_node and stl_ logs

(09:24:30) Annie Sun: i think we got dropped

(09:25:02) Annie Sun: /usr/local/logs - HM logs

(09:26:37) Annie Sun: -rw-r--r-- 1 rdshm rds  67M May 23 23:24 rds-application.debug.log
-rw-r--r-- 1 rdshm rds 1.2M May 23 23:24 rds-application.log

(09:28:17) Annie Sun: su -c "/var/log/messages"

(09:28:42) Annie Sun: su -c “less /var/log/messages"

(09:30:19) Annie Sun: /rdsdbbin/padb/rel/bin/cqi allx "dmesg | egrep -i \"fail|error|exception|kill|ixgbevf\" | tail -20 | gawk -v uptime=\$( grep btime /proc/stat | cut -d ' ' -f 2 ) '/^[[ 0-9.]*]/ { print strftime(\"[%Y/%m/%d %H:%M:%S]\", substr(\$0,2,index(\$0,\".\")-2)+uptime) substr(\$0,index(\$0,\"]\")+1) }'"

(09:48:41) Annie Sun: /apollo/env/BarkCLI/bin/bark -ConfigFile /tmp/bark.dub -FetchLogs --LogGroupName=AWSCookieMonster/PADB/Prod/36731 --StartTime=2015-12-15T00:00:00Z --EndTime=2015-12-16T00:00:00Z --OwnerEmail=aws-cm-prod-euwest1@amazon.com --matchLogName 1000.start_node -path /tmp/hssun/36731

(09:48:52) Annie Sun: /apollo/env/BarkCLI/bin/bark -FetchLogs --LogGroupName=AWSCookieMonster/HostManager/Prod/160471 --StartTime=2016-05-14T00:00:00Z --EndTime=2016-05-15T00:00:00Z  --OwnerEmail=aws-cm-prod-useast1@amazon.com --matchLogName rds-application. -path=/tmp/logs/160471

(09:50:24) Annie Sun: ssh security-bastions-prod-dub.amazon.com
/opt/systems/bin/expand-hostclass aws-cookie-monster-timber-euw1
ssh into that host for timber

(09:51:15) Annie Sun: cqi allx ‘comand'

(09:51:19) Annie Sun: cqi dumpstack

(09:51:30) Annie Sun: cqi xstop/cqi xstart

(09:52:36) Annie Sun: naming convention:

(09:52:48) Annie Sun: ricci-tt<tt_num>-something

(09:54:53) Annie Sun: https://w.amazon.com/index.php/AWS_Cookie_Monster/Operations/FrequentCmds#Data_Plane.2FPADB_troubleshooting

--- Redshift ROLE access to COPY and UNLOAD

http://docs.aws.amazon.com/redshift/latest/mgmt/copy-unload-iam-role.html
http://docs.aws.amazon.com/redshift/latest/mgmt/authorizing-redshift-service.html


Create an IAM Policy:
~~~~~~~~~~~~~~~~~~~~
{
    "Version": "2012-10-17",
    "Statement": {
        "Effect": "Allow",
        "Action": [
            "s3:*"
        ],
        "Resource": "arn:aws:s3:::*",
        "Condition": {
            "IpAddress": {
                "aws:SourceIp": [
                    "52.64.145.4/32"
                ]
            }
        }
    }
}

create an IAM role:
~~~~~~~~~~~~~~~~~~
Role ARN = arn:aws:iam::344492629025:role/RedshiftCopyUnload
Policy Name = S3AccessByIP 
Trust Relationship: 
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "redshift.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}

Assign to Redshift Cluster:
~~~~~~~~~~~~~~~~~~~~~~~~~~
Manage IAM roles: RedshiftCopyUnload (in-sync)

Run Copy:
~~~~~~~~
dev=# copy t1 from 's3://riccic-syd/test.csv' credentials 'aws_iam_role=arn:aws:iam::344492629025:role/RedshiftCopyUnload' csv; 
INFO:  Load into table 't1' completed, 3 record(s) loaded successfully.
COPY

--- Serialization Violation issue
https://www.postgresql.org/docs/current/static/transaction-iso.html

dev=# create table mytab (class int, value int);
CREATE TABLE
dev=# insert into mytab values (1,10),(1,20),(2,100),(2,200);
INSERT 0 4
dev=# select * from mytab;
 class | value 
-------+-------
     1 |    10
     2 |   100
     1 |    20
     2 |   200
(4 rows)


### --- Session 1 ---

dev=# begin;
BEGIN

select * from svl_session;
create table t2 select * from t1 where 1=2;

dev=# SELECT SUM(value) FROM mytab WHERE class=1;
 sum 
-----
  30
(1 row)

dev=# SELECT SUM(value) FROM mytab WHERE class=2;
 sum 
-----
 300
(1 row)

dev=# insert into mytab SELECT 2,SUM(value) FROM mytab WHERE class =1;
INSERT 0 1
dev=# SELECT SUM(value) FROM mytab WHERE class=1;
 sum 
-----
  30
(1 row)

dev=# SELECT SUM(value) FROM mytab WHERE class=2;
 sum 
-----
 330
(1 row)

## --- Session 2 ---

dev=# begin;
BEGIN
dev=# SELECT SUM(value) FROM mytab WHERE class=1;
 sum 
-----
  30
(1 row)

dev=# SELECT SUM(value) FROM mytab WHERE class=2;
 sum 
-----
 300
(1 row)

dev=# select pg_backend_pid();
 pg_backend_pid 
----------------
           7005
(1 row)

dev=# insert into mytab SELECT 1,SUM(value) FROM mytab WHERE class=2;

<<HERE IT WAITS TO LOCK THE TABLE>>

## --- Session #1 ---

dev=# select pg_backend_pid();
 pg_backend_pid 
----------------
           7003
(1 row)

dev=# select * from svv_transactions where relation=141349;
 txn_owner | txn_db |   xid   | pid  |         txn_start          |       lock_mode       | lockable_object_type | relation | granted 
-----------+--------+---------+------+----------------------------+-----------------------+----------------------+----------+---------
 master    | dev    | 4044550 | 7003 | 2016-06-07 01:36:34.092125 | ShareRowExclusiveLock | relation             |   141349 | t
 master    | dev    | 4044550 | 7003 | 2016-06-07 01:36:34.092125 | AccessShareLock       | relation             |   141349 | t
 master    | dev    | 4044551 | 7005 | 2016-06-07 01:37:02.717484 | ShareRowExclusiveLock | relation             |   141349 | f
 master    | dev    | 4044551 | 7005 | 2016-06-07 01:37:02.717484 | AccessShareLock       | relation             |   141349 | t
(4 rows)

dev=# end;
COMMIT

## --- Session #2 ---

dev=# select pg_backend_pid();
 pg_backend_pid 
----------------
           7005
(1 row)

dev=# insert into mytab SELECT 1,SUM(value) FROM mytab WHERE class=2;
ERROR:  1023
DETAIL:  Serializable isolation violation on table - 141349, transactions forming the cycle are: 4044550, 4044551 (pid:7005)

dev=# rollback;
ROLLBACK

## --- Check conflicts ---

dev=# select * from svv_transactions where relation=141349;
 txn_owner | txn_db | xid | pid | txn_start | lock_mode | lockable_object_type | relation | granted 
-----------+--------+-----+-----+-----------+-----------+----------------------+----------+---------
(0 rows)

dev=# select * from stl_tr_conflict where table_id = 141349;
 xact_id | process_id |       xact_start_ts        |         abort_time         | table_id 
---------+------------+----------------------------+----------------------------+----------
 4044551 |       7005 | 2016-06-07 01:37:02.717484 | 2016-06-07 01:37:16.986409 |   141349
(1 row)

ev=# select userid,xid,pid,trim(label) wlm_label,starttime,endtime,sequence,type,trim(text) text from svl_statementtext where xid in (4044550, 4044551) order by starttime asc;
 userid |   xid   | pid  | wlm_label |         starttime          |          endtime           | sequence |  type   |                               text                               
--------+---------+------+-----------+----------------------------+----------------------------+----------+---------+------------------------------------------------------------------
    100 | 4044550 | 7003 | default   | 2016-06-07 01:35:58.847419 | 2016-06-07 01:35:58.847421 |        0 | UTILITY | begin;
    100 | 4044551 | 7005 | default   | 2016-06-07 01:36:02.568474 | 2016-06-07 01:36:02.568475 |        0 | UTILITY | begin;
    100 | 4044550 | 7003 | default   | 2016-06-07 01:36:34.091514 | 2016-06-07 01:36:34.096192 |        0 | QUERY   | SELECT SUM(value) FROM mytab WHERE class=1;
    100 | 4044550 | 7003 | default   | 2016-06-07 01:36:38.097369 | 2016-06-07 01:36:38.101945 |        0 | QUERY   | SELECT SUM(value) FROM mytab WHERE class=2;
    100 | 4044550 | 7003 | default   | 2016-06-07 01:36:49.993056 | 2016-06-07 01:36:50.004978 |        0 | QUERY   | insert into mytab SELECT 2,SUM(value) FROM mytab WHERE class =1;
    100 | 4044550 | 7003 | default   | 2016-06-07 01:36:57.776855 | 2016-06-07 01:36:57.781616 |        0 | QUERY   | SELECT SUM(value) FROM mytab WHERE class=1;
    100 | 4044550 | 7003 | default   | 2016-06-07 01:36:59.335699 | 2016-06-07 01:36:59.340277 |        0 | QUERY   | SELECT SUM(value) FROM mytab WHERE class=2;
    100 | 4044551 | 7005 | default   | 2016-06-07 01:37:02.716875 | 2016-06-07 01:37:02.721648 |        0 | QUERY   | SELECT SUM(value) FROM mytab WHERE class=1;
    100 | 4044551 | 7005 | default   | 2016-06-07 01:37:05.152511 | 2016-06-07 01:37:05.157253 |        0 | QUERY   | SELECT SUM(value) FROM mytab WHERE class=2;
    100 | 4044550 | 7003 | default   | 2016-06-07 01:37:13.103424 | 2016-06-07 01:37:13.17382  |        0 | QUERY   | select * from svv_transactions where relation=141349;
    100 | 4044550 | 7003 | default   | 2016-06-07 01:37:16.890943 | 2016-06-07 01:37:16.922683 |        0 | UTILITY | COMMIT
    100 | 4044551 | 7005 | default   | 2016-06-07 01:37:16.982137 | 2016-06-07 01:37:16.987134 |        0 | QUERY   | insert into mytab SELECT 1,SUM(value) FROM mytab WHERE class=2;
    100 | 4044551 | 7005 | default   | 2016-06-07 01:40:40.968813 | 2016-06-07 01:40:40.968814 |        0 | UTILITY | rollback;
(13 rows)

dev=# SELECT * FROM stl_commit_stats WHERE xid IN (4044550, 4044551);
-[ RECORD 1 ]---+---------------------------
xid             | 4044550
node            | 0
startqueue      | 2000-01-01 00:00:00
startwork       | 2016-06-07 01:37:16.89112
endflush        | 2016-06-07 01:37:16.9195
endstage        | 2016-06-07 01:37:16.920019
endlocal        | 2016-06-07 01:37:16.922194
startglobal     | 2016-06-07 01:37:16.922365
endtime         | 2016-06-07 01:37:16.922607
queuelen        | 0
permblocks      | 155
newblocks       | 10
dirtyblocks     | 10
headers         | 22
numxids         | 0
oldestxid       | 0
extwritelatency | 0
metadatawritten | 1
-[ RECORD 2 ]---+---------------------------
xid             | 4044550
node            | -1
startqueue      | 2016-06-07 01:37:16.766192
startwork       | 2016-06-07 01:37:16.890943
endflush        | 2000-01-01 00:00:00
endstage        | 2000-01-01 00:00:00
endlocal        | 2000-01-01 00:00:00
startglobal     | 2016-06-07 01:37:16.922284
endtime         | 2016-06-07 01:37:16.9227
queuelen        | 0
permblocks      | 0
newblocks       | 0
dirtyblocks     | 0
headers         | 0
numxids         | 0
oldestxid       | 0
extwritelatency | 0
metadatawritten | 1

# --- Scenario 2 ---

## --- Session #1 ---

dev=# create table mytab (class int, value int);
CREATE TABLE
dev=# insert into mytab values (1,10),(1,20),(2,100),(2,200);
INSERT 0 4
dev=# select * from mytab;
 class | value 
-------+-------
     1 |    10
     2 |   100
     1 |    20
     2 |   200
(4 rows)

dev=# begin;
BEGIN
dev=# insert into mytab SELECT 2,SUM(value) FROM mytab WHERE class =1;
INSERT 0 1
dev=# select pg_backend_pid(); 
 pg_backend_pid 
----------------
           7003
(1 row)

dev=# select * from svv_transactions;
 txn_owner | txn_db |   xid   | pid  |         txn_start         |       lock_mode       | lockable_object_type | relation | granted 
-----------+--------+---------+------+---------------------------+-----------------------+----------------------+----------+---------
 master    | dev    | 4045074 | 7003 | 2016-06-07 02:16:10.47651 | AccessShareLock       | relation             |    16886 | t
 master    | dev    | 4045074 | 7003 | 2016-06-07 02:16:10.47651 | AccessShareLock       | relation             |    51790 | t
 master    | dev    | 4045074 | 7003 | 2016-06-07 02:16:10.47651 | AccessShareLock       | relation             |    51850 | t
 master    | dev    | 4045074 | 7003 | 2016-06-07 02:16:10.47651 | AccessShareLock       | relation             |   140406 | t
 master    | dev    | 4045074 | 7003 | 2016-06-07 02:16:10.47651 | ShareRowExclusiveLock | relation             |   141349 | t
 master    | dev    | 4045074 | 7003 | 2016-06-07 02:16:10.47651 | AccessShareLock       | relation             |   141349 | t
 master    | dev    | 4045074 | 7003 | 2016-06-07 02:16:10.47651 | ExclusiveLock         | transactionid        |          | t
(7 rows)

## --- Session #2 ---

dev=# begin;
BEGIN
dev=# analyze mytab;
ANALYZE
dev=# insert into mytab SELECT 1,SUM(value) FROM mytab WHERE class =2;

## --- Session #1 ---

dev=# end;
COMMIT

## --- Session #2 ---

dev=# insert into mytab SELECT 1,SUM(value) FROM mytab WHERE class =2;
ERROR:  1023
DETAIL:  Serializable isolation violation on table - 141349, transactions forming the cycle are: 4045074, 4045081 (pid:7005)
dev=# end;
ROLLBACK

dev=# select * from stl_tr_conflict where table_id = 141349;
-[ RECORD 1 ]-+---------------------------
xact_id       | 4045081
process_id    | 7005
xact_start_ts | 2016-06-07 02:16:36.598187
abort_time    | 2016-06-07 02:17:25.433475
table_id      | 141349

dev=#   select userid,xid,pid,trim(label) wlm_label,starttime,endtime,sequence,type,trim(text) text from svl_statementtext where xid in (4045074, 4045081) order by starttime asc;
 userid |   xid   | pid  | wlm_label |         starttime          |          endtime           | sequence |  type   |                               text                               
--------+---------+------+-----------+----------------------------+----------------------------+----------+---------+------------------------------------------------------------------
    100 | 4045074 | 7003 | default   | 2016-06-07 02:16:10.470038 | 2016-06-07 02:16:10.47004  |        0 | UTILITY | begin;
    100 | 4045074 | 7003 | default   | 2016-06-07 02:16:10.475962 | 2016-06-07 02:16:10.491423 |        0 | QUERY   | insert into mytab SELECT 2,SUM(value) FROM mytab WHERE class =1;
    100 | 4045074 | 7003 | default   | 2016-06-07 02:16:10.496361 | 2016-06-07 02:16:10.599096 |        0 | QUERY   | select * from svv_transactions;
    100 | 4045081 | 7005 | default   | 2016-06-07 02:16:36.596692 | 2016-06-07 02:16:36.596694 |        0 | UTILITY | begin;
    100 | 4045081 | 7005 | default   | 2016-06-07 02:16:36.597608 | 2016-06-07 02:16:36.605085 |        0 | UTILITY | Analyze mytab
    100 | 4045081 | 7005 | default   | 2016-06-07 02:16:36.597637 | 2016-06-07 02:16:36.601714 |        0 | QUERY   | padb_fetch_sample: select count(*) from mytab
    100 | 4045081 | 7005 | default   | 2016-06-07 02:16:36.601888 | 2016-06-07 02:16:36.604754 |        0 | QUERY   | padb_fetch_sample: select * from mytab
    100 | 4045074 | 7003 | default   | 2016-06-07 02:17:25.312528 | 2016-06-07 02:17:25.357007 |        0 | UTILITY | COMMIT
    100 | 4045081 | 7005 | default   | 2016-06-07 02:17:25.429151 | 2016-06-07 02:17:25.434043 |        0 | QUERY   | insert into mytab SELECT 1,SUM(value) FROM mytab WHERE class =2;
(9 rows)

dev=# SELECT * FROM stl_commit_stats WHERE xid IN (4045074, 4045081);
   xid   | node |         startqueue         |         startwork          |          endflush          |          endstage          |          endlocal          |        startglobal         |          endtime           | 
queuelen | permblocks | newblocks | dirtyblocks | headers | numxids | oldestxid | extwritelatency | metadatawritten 
---------+------+----------------------------+----------------------------+----------------------------+----------------------------+----------------------------+----------------------------+----------------------------+-
---------+------------+-----------+-------------+---------+---------+-----------+-----------------+-----------------
 4045074 |    0 | 2000-01-01 00:00:00        | 2016-06-07 02:17:25.312731 | 2016-06-07 02:17:25.355364 | 2016-06-07 02:17:25.355834 | 2016-06-07 02:17:25.356479 | 2016-06-07 02:17:25.356697 | 2016-06-07 02:17:25.356906 | 
       0 |        155 |        10 |          10 |      22 |       0 |         0 |               0 |               1
 4045074 |   -1 | 2016-06-07 02:17:25.286955 | 2016-06-07 02:17:25.312528 | 2000-01-01 00:00:00        | 2000-01-01 00:00:00        | 2000-01-01 00:00:00        | 2016-06-07 02:17:25.356611 | 2016-06-07 02:17:25.357026 | 
       0 |          0 |         0 |           0 |       0 |       0 |         0 |               0 |               1
(2 rows)

### --- Other scenario ---

-- T1
dev=# begin;
BEGIN
dev=# insert into mytab select * from mytab;
INSERT 0 4

-- T2

dev=# begin;
BEGIN
dev=# select * from mytab;
 class | value 
-------+-------
     1 |    20
     2 |   200
     1 |    10
     2 |   100
(4 rows)

dev=# insert into mytab values (100,100);

-- T1

dev=# end;
COMMIT

-- T2

dev=# insert into mytab values (100,100);
ERROR:  1023
DETAIL:  Serializable isolation violation on table - 141349, transactions forming the cycle are: 4045571, 4045572 (pid:9779)

dev=# select userid,xid,pid,trim(label) wlm_label,starttime,endtime,sequence,type,trim(text) text from svl_statementtext where xid in (4045571, 4045572) order by starttime asc;
 userid |   xid   | pid  | wlm_label |         starttime          |          endtime           | sequence |  type   |                  text                  
--------+---------+------+-----------+----------------------------+----------------------------+----------+---------+----------------------------------------
    100 | 4045571 | 9777 | default   | 2016-06-07 02:51:01.141196 | 2016-06-07 02:51:01.141198 |        0 | UTILITY | begin;
    100 | 4045571 | 9777 | default   | 2016-06-07 02:51:04.968199 | 2016-06-07 02:51:04.977434 |        0 | QUERY   | insert into mytab select * from mytab;
    100 | 4045572 | 9779 | default   | 2016-06-07 02:51:13.062337 | 2016-06-07 02:51:13.062339 |        0 | UTILITY | begin;
    100 | 4045572 | 9779 | default   | 2016-06-07 02:51:20.175067 | 2016-06-07 02:51:20.178247 |        0 | QUERY   | select * from mytab;
    100 | 4045571 | 9777 | default   | 2016-06-07 02:51:54.611056 | 2016-06-07 02:51:54.651687 |        0 | UTILITY | COMMIT
    100 | 4045572 | 9779 | default   | 2016-06-07 02:51:54.701376 | 2016-06-07 02:51:54.703079 |        0 | QUERY   | insert into mytab values (100,100);
(6 rows)

dev=# select slice,id,trim(name) name,rows,sorted_rows,temp,db_id,insert_pristine,delete_pristine,backup from stv_tbl_perm where id = 141349;
 slice |   id   | name  | rows | sorted_rows | temp | db_id  | insert_pristine | delete_pristine | backup 
-------+--------+-------+------+-------------+------+--------+-----------------+-----------------+--------
     0 | 141349 | mytab |    2 |           0 |    0 | 100064 |               0 |               1 |      1
     1 | 141349 | mytab |    2 |           0 |    0 | 100064 |               0 |               1 |      1
  6411 | 141349 | mytab |    0 |           0 |    0 | 100064 |               3 |               1 |      1
(3 rows)


------- Query continue running even after timeout is set in WLM

select * from stv_wlm_query_state;

If the customer ever has a query that exceeded the timeout, they can check stv_wlm_query_state to see if the query is in the state = ‘Returning’. If it is in Returning, that means WLM timeout no longer applies to the query. However, when the query is in this state, the customer should be able to explicitly cancel the query."

------- WLM USER Groups

1) WLM Queue Setup
user_*	A value that indicates whether wildcard characters are allowed in the WLM configuration to specify user groups.
Reference: http://docs.aws.amazon.com/redshift/latest/dg/tutorial-wlm-understanding-default-processing.html

2) Example how to setup WLM User Groups

Step 3: Create a Database User and Group

In Step 1: Create a Parameter Group, you configured one of your query queues with a user group named admin. Before you can run any queries in this queue, you need to create the user group in the database and add a user to the group. Then you’ll log into psql using the new user’s credentials and run queries. You need to run queries as a superuser, such as the masteruser, to create database users.
To Create a New Database User and User Group

In the database, create a new database user named adminwlm by running the following command in a psql window.

create user adminwlm createuser password '123Admin';

Then, run the following commands to create the new user group and add your new adminwlm user to it.

create group admin;
alter group admin add user adminwlm;

Reference: http://docs.aws.amazon.com/redshift/latest/dg/tutorial-wlm-routing-queries-to-queues.html

Here is my test case which confirms users does not work with WLM queues:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#-- Create a view to check the config 

dev=# create or replace view WLM_QUEUE_STATE_VW as
select (config.service_class) as queue
, trim (class.condition) as description
, config.num_query_tasks as slots
, config.query_working_mem as mem
, config.max_execution_time as max_time
, config.user_group_wild_card as "user_*"
, config.query_group_wild_card as "query_*"
, state.num_queued_queries queued
, state.num_executing_queries executing
, state.num_executed_queries executed
from
STV_WLM_CLASSIFICATION_CONFIG class,
STV_WLM_SERVICE_CLASS_CONFIG config,
STV_WLM_SERVICE_CLASS_STATE state
where
class.action_service_class = config.service_class 
and class.action_service_class = state.service_class 
and config.service_class > 4
order by config.service_class;
CREATE VIEW

#-- As you can see I have a group called ETL and COPYUSER

dev=# select * from WLM_QUEUE_STATE_VW;
queue | description | slots | mem | max_time | user_* | query_* | queued | executing | executed 
-------+-------------------------------------------+-------+-----+----------+----------+----------+--------+-----------+----------
5 | (super user) and (query group: superuser) | 1 | 535 | 0 | false | false | 0 | 0 | 0
6 | (user group: copyuser) | 5 | 188 | 0 | false | false | 0 | 0 | 0
6 | (user group: etl) | 5 | 188 | 0 | false | false | 0 | 0 | 0
7 | (user group: maintenance) | 3 | 209 | 0 | false | false | 0 | 0 | 0
8 | (querytype: any) | 7 | 672 | 0 | false | false | 0 | 1 | 32
(5 rows)

# -- I login as COPYUSER and run my copy

dev=# select current_user;
current_user 
--------------
copyuser
(1 row)

dev=# copy t1 from 's3://riccic-oregon/t1.csv' credentials 'aws_iam_role=arn:aws:iam::XXXXXXXXXX:role/RedshiftCopyUnload' csv;
INFO: Load into table 't1' completed, 2 record(s) loaded successfully.
COPY
dev=# select * from pg_last_query_id();
pg_last_query_id 
------------------
210138
(1 row)

# -- When check the Queue class is 8 (default), not 6 which contains (COPYUSER and ETL)

dev=# \x
Expanded display is on.

dev=# select * from STL_WLM_QUERY where query=210138;
-[ RECORD 1 ]------------+---------------------------
userid | 109
xid | 778772
task | 210137
query | 210138
service_class | 8
slot_count | 1
service_class_start_time | 2016-06-08 00:23:56.181604
queue_start_time | 2016-06-08 00:23:56.181614
queue_end_time | 2016-06-08 00:23:56.181614
total_queue_time | 0
exec_start_time | 2016-06-08 00:23:56.181616
exec_end_time | 2016-06-08 00:23:56.183337
total_exec_time | 1721
service_class_end_time | 2016-06-08 00:23:56.183337
final_state | Completed 
(1 row)

dev=# \x
Expanded display is off.

dev=# select * from WLM_QUEUE_STATE_VW where queue=8;
queue | description | slots | mem | max_time | user_* | query_* | queued | executing | executed 
-------+------------------+-------+-----+----------+----------+----------+--------+-----------+----------
8 | (querytype: any) | 7 | 672 | 0 | false | false | 0 | 0 | 33
(1 row)

# -- Then I create the ETL group and assign it to the COPYUSER user. Still login as COPYUSER

dev=# create group etl;
CREATE GROUP
dev=# alter group etl add user copyuser;
ALTER GROUP

dev=# select current_user;
current_user 
--------------
copyuser
(1 row)

# -- When I run my copy it now picks the ETL WLM usergroup (queue 6)

dev=# copy t1 from 's3://riccic-oregon/t1.csv' credentials 'aws_iam_role=arn:aws:iam::XXXXXXXXXX:role/RedshiftCopyUnload' csv;
INFO: Load into table 't1' completed, 2 record(s) loaded successfully.
COPY

dev=# select * from pg_last_query_id();
pg_last_query_id 
------------------
210169
(1 row)

dev=# \x
Expanded display is on.

dev=# select * from STL_WLM_QUERY where query=210169;
-[ RECORD 1 ]------------+---------------------------
userid | 109
xid | 778845
task | 210168
query | 210169
service_class | 6
slot_count | 1
service_class_start_time | 2016-06-08 00:30:13.482843
queue_start_time | 2016-06-08 00:30:13.482852
queue_end_time | 2016-06-08 00:30:13.482852
total_queue_time | 0
exec_start_time | 2016-06-08 00:30:13.482854
exec_end_time | 2016-06-08 00:30:13.484529
total_exec_time | 1675
service_class_end_time | 2016-06-08 00:30:13.484529
final_state | Completed 
(1 row)

dev=# \x
Expanded display is off.

dev=# select * from WLM_QUEUE_STATE_VW where queue=6;
queue | description | slots | mem | max_time | user_* | query_* | queued | executing | executed 
-------+------------------------+-------+-----+----------+----------+----------+--------+-----------+----------
6 | (user group: copyuser) | 5 | 188 | 0 | false | false | 0 | 1 | 12
6 | (user group: etl) | 5 | 188 | 0 | false | false | 0 | 1 | 12
(2 rows)

---- Space

dev=# SELECT
  trim(pgdb.datname) AS Database,
  trim(pgn.nspname)  AS Schema,
  trim(a.name)       AS Table,
  b.mbytes           AS mbytes,
  a.rows             AS rows
FROM (SELECT
        db_id,
        id,
        name,
        sum(rows) AS rows
      FROM stv_tbl_perm a
      GROUP BY db_id, id, name) AS a
  JOIN pg_class AS pgc ON pgc.oid = a.id
  JOIN pg_namespace AS pgn ON pgn.oid = pgc.relnamespace
  JOIN pg_database AS pgdb ON pgdb.oid = a.db_id
  JOIN (SELECT
          tbl,
          count(*) AS mbytes
        FROM stv_blocklist
        GROUP BY tbl) b ON a.id = b.tbl
ORDER BY mbytes DESC LIMIT 100;
 database | schema |       table        | mbytes | rows  
----------+--------+--------------------+--------+-------
 dev      | public | _users_part_201501 |     24 | 10001
 dev      | public | users_part_201502  |     18 |    35
 dev      | public | users_part_201501  |     18 | 10001
 dev      | public | users_part_201503  |     18 | 20001
 dev      | public | mytab              |     10 |     4
 dev      | public | t1                 |     10 |     9
 dev      | public | t2                 |     10 |     4
 dev      | public | utfnull            |      6 |     2
(8 rows)

--- Troubleshooting

1) Identify the query and get its details (process ID (pid), transaction ID (xid), query ID (query)). For this you can use STL_QUERY[1].

Example query to view the last 5 statements containing the word delete:
select query,xid,pid,trim(querytxt) from stl_query where querytxt ilike '%delete%' order by endtime desc limit 5;

2) Check the physical execution of the query using SVL_QUERY_REPORT [2]. This helps to understand what part of the execution takes time

The following query can be used for that (QUERY_ID needs to be replaced with the query ID from step 1):
select query, segment, step, label ,is_rrscan as rrS, is_diskbased as disk, is_delayed_scan as DelayS, min(start_time) as starttime, max(end_time) as endtime, datediff(ms, min(start_time), max(end_time)) as "elapsed_msecs", sum(rows) as row_s , sum(rows_pre_filter) as rows_pf, CASE WHEN sum(rows_pre_filter) = 0 THEN 100 ELSE sum(rows)::float/sum(rows_pre_filter)::float*100 END as pct_filter, SUM(workmem)/1024/1024 as "Memory(MB)", SUM(bytes)/1024/1024 as "MB_produced"from svl_query_report where query in (QUERY_ID) group by query, segment, step, label , is_rrscan, is_diskbased , is_delayed_scan order by query, segment, step, label;

3) Check the commit statistics using STL_COMMIT_STATS [3]. This helps to understand the time that was taken by commits. you can just get the full output for a specific transaction ID (xid from step 1)
select * from stl_commit_stats where xid = TRANSACTION_ID;

4) If the above steps did not show where time is taken it is best to check whether WLM queuing can explain the timing. For this STL_WLM_QUERY [4] can be used.

SELECT query, queue_start_time, service_class AS class, slot_count AS slots, total_queue_time / 1000 AS ms, total_exec_time / 1000 exec_ms, (total_queue_time + total_exec_time) / 1000 AS total_ms
FROM stl_wlm_query where xid = 1687964;

--- Min table size

--https://www.postgresql.org/docs/8.0/static/datatype.html / https://www.postgresql.org/docs/9.1/static/datatype-datetime.html
select table_name,column_name,data_type, 
case 
when data_type = 'integer' then  4
when data_type = 'bigint' then  8
when data_type = 'numeric' then numeric_precision
when data_type = 'character varying' then character_maximum_length
when data_type = 'timestamp without time zone' then 8
when data_type = 'smallint' then 2
else 0
END column_bytes
--,*
from information_schema.columns 
where table_name = 'tracking_20160616_20160630';

-- Dist ALL - Table is only located in the first slice of each node (that is by multiply by nodes not slices)
SELECT 
distinct b.table_id, trim(t.name) tname,decode(b.reldiststyle,0, 'even',1,'key' ,8,'all') as diststyle,b.slices,b.columns,b.spaces num_regions,s.cns nodes,
CASE 
WHEN b.reldiststyle = 0 THEN (b.slices * b.columns * b.spaces)
WHEN b.reldiststyle = 1 THEN (b.slices * b.columns * b.spaces)
WHEN b.reldiststyle = 8 THEN (s.cns * b.columns * b.spaces)
END minimum_size,
b.blocks actual_size 
FROM
(
SELECT c.reldiststyle,
COUNT(distinct slice) slices,
COUNT(distinct col) columns, 
COUNT(DISTINCT unsorted) spaces,
COUNT(blocknum) "blocks", tbl table_id 
FROM STV_BLOCKLIST
JOIN pg_class c ON c.oid = stv_blocklist.tbl
WHERE tbl IN (
SELECT DISTINCT id 
FROM stv_tbl_perm 
WHERE db_id > 1)
GROUP BY tbl, c.reldiststyle) b, 
(SELECT COUNT(DISTINCT node) cns, COUNT(slice) slices FROM stv_slices) s,
stv_tbl_perm t
WHERE t.id = b.table_id;

 table_id |              tname               | diststyle | slices | columns | num_regions | nodes | minimum_size | actual_size 
----------+----------------------------------+-----------+--------+---------+-------------+-------+--------------+-------------
   108406 | cat                              | even      |      4 |       9 |           1 |     2 |           36 |          36
   108410 | date                             | key       |      4 |      11 |           2 |     2 |           88 |          88
   108424 | music                            | even      |      2 |       7 |           1 |     2 |           14 |          14
   108432 | temp1_users                      | even      |      4 |      21 |           1 |     2 |           84 |        2136
   108434 | temp2_users                      | even      |      4 |      21 |           2 |     2 |          168 |        2220
   108440 | tmp_users_lzo                    | key       |      4 |      21 |           1 |     2 |           84 |         227
   108449 | venue                            | key       |      4 |       8 |           2 |     2 |           64 |          64
   118352 | table_a                          | even      |      4 |       5 |           1 |     2 |           20 |          20
   128430 | abc                              | even      |      1 |       4 |           1 |     2 |            4 |           4
   108394 | appointmentrecord                | key       |      1 |      44 |           2 |     2 |           88 |          88
   108408 | category                         | key       |      4 |       7 |           2 |     2 |           56 |          56
   108438 | tmp_users                        | even      |      4 |      21 |           1 |     2 |           84 |        1080
   108442 | users                            | even      |      4 |      21 |           1 |     2 |           84 |         112
   154904 | driverlocation_stg_tmp           | key       |      2 |      20 |           1 |     2 |           40 |          40
   108417 | hbrg_prod_elb_2015_10            | even      |      2 |      18 |           1 |     2 |           36 |          36
   108426 | sales                            | key       |      4 |      13 |           2 |     2 |          104 |         104
   108436 | temp3_users                      | even      |      4 |      21 |           1 |     2 |           84 |          84
   108444 | users_stg                        | even      |      4 |      21 |           1 |     2 |           84 |          88
   118354 | table_b                          | even      |      3 |       5 |           1 |     2 |           15 |          15
   108428 | t1                               | even      |      2 |       6 |           1 |     2 |           12 |          12
   100075 | redshift_auto_health_check_91297 | even      |      4 |       4 |           1 |     2 |           16 |          16
   108415 | event                            | key       |      4 |       9 |           2 |     2 |           72 |          72
   108419 | listing                          | key       |      4 |      11 |           2 |     2 |           88 |          88
   108430 | t2                               | even      |      2 |       4 |           1 |     2 |            8 |           8
(24 rows)

-- This will show compute nodes execution time comparisson between nodes (good to troubleshoot performance diff on nodes)

# You can compare the amount of work done in Bytes on each node 

select iq.day_d, sl.node, sum(iq.elapsed_ms) as elapsed, sum(iq.bytes) as bytes from (select start_time::date as day_d, slice,query,segment,datediff('ms',min(start_time),max(end_time)) as elapsed_ms, sum(bytes) as bytes from svl_query_report where end_time > start_time group by 1,2,3,4) iq join stv_slices as sl on (sl.slice = iq.slice) group by 1,2 order by 1 desc, 3 desc;

# Then add the query to identify slow pieces of SQL 

select iq.day_d, sl.node, iq.query, sum(iq.elapsed_ms) as elapsed, sum(iq.bytes) as bytes from (select start_time::date as day_d, slice,query,segment,datediff('ms',min(start_time),max(end_time)) as elapsed_ms, sum(bytes) as bytes from svl_query_report where end_time > start_time group by 1,2,3,4) iq join stv_slices as sl on (sl.slice = iq.slice) group by 1,2,3 order by 1 desc, 3 desc;

-- Unload file size

By default UNLOAD will parallelize extract of data based on number of slices on the cluster nodes, you can override this behavior if you set PARALLEL OFF in your UNLOAD command options. I think the reason why you are seeing the explain behavior in your case is due to the distribution style of your tables.

When you use ALL, the data is located into the first slice of the node. That means UNLOAD when parallelizing will unload all the data from 1 slice on any of the nodes and the create other empty small files. 

In your case dc1.8xlarge with 32 slices per node gives you 256 slices in 8 nodes. Slice 0 will contain all the data, rest of the slices won't. Since UNLOAD is not aware of this, it will produce as many files as slices, one 1 will contain all the data.

In order to fix this, you can use PARALLEL OFF so that files will be split in max 6.2 GB parts.

References:
~~~~~~~~~~
http://docs.aws.amazon.com/redshift/latest/dg/t_Unloading_tables.html
http://docs.aws.amazon.com/redshift/latest/dg/r_UNLOAD.html

dev=# CREATE TABLE IF NOT EXISTS "public"."venue_cp"
 (
         "venueid" SMALLINT NOT NULL  
         ,"venuename" VARCHAR(100)   
         ,"venuecity" VARCHAR(30)   
         ,"venuestate" CHAR(2)   
         ,"venueseats" INTEGER   
 )
 DISTSTYLE ALL SORTKEY (
         "venueid"
         )
 ;
CREATE TABLE
dev=# insert into venue_cp select * from venue;
INSERT 0 202
dev=# analyze venue_cp
dev-# ;
ANALYZE
dev=# analyze venue;
ANALYZE
dev=# select b.slice,count(1) num_block,sum(b.num_values) num_rows,i.table,max(i.size) size_mb from svv_table_info i,stv_blocklist b where i.table_id=b.tbl and i.table ilike '%venue%' group by i.table,b.slice order by 3,1;
 slice | num_block | num_rows |  table   | size_mb 
-------+-----------+----------+----------+---------
     0 |        16 |      360 | venue    |      64
     2 |        16 |      376 | venue    |      64
     3 |        16 |      424 | venue    |      64
     1 |        16 |      456 | venue    |      64
     0 |        16 |     1616 | venue_cp |      32
     2 |        16 |     1616 | venue_cp |      32
(6 rows)

dev=# unload ('select * from venue') to 's3://riccic-oregon/unload_venue' credentials 'aws_iam_role=arn:aws:iam::344492629025:role/RedshiftCopyUnload' gzip MANIFEST;
UNLOAD
dev=# unload ('select * from venue_cp') to 's3://riccic-oregon/unload_venue_cp' credentials 'aws_iam_role=arn:aws:iam::344492629025:role/RedshiftCopyUnload' gzip MANIFEST;
UNLOAD
dev=# unload ('select * from venue_cp') to 's3://riccic-oregon/unload_paroff_venue_cp' credentials 'aws_iam_role=arn:aws:iam::344492629025:role/RedshiftCopyUnload' gzip MANIFEST parallel off;
UNLOAD

2016-06-25 05:11:21       3331 unload_paroff_venue_cp000.gz
2016-06-25 05:11:22         85 unload_paroff_venue_cpmanifest

2016-06-25 05:10:46        916 unload_venue0000_part_00.gz
2016-06-25 05:10:46       1090 unload_venue0001_part_00.gz
2016-06-25 05:10:46        940 unload_venue0002_part_00.gz
2016-06-25 05:10:46       1001 unload_venue0003_part_00.gz
2016-06-25 05:10:49        270 unload_venuemanifest

2016-06-25 05:11:02       3331 unload_venue_cp0000_part_00.gz
2016-06-25 05:11:02         20 unload_venue_cp0001_part_00.gz
2016-06-25 05:11:02         20 unload_venue_cp0002_part_00.gz
2016-06-25 05:11:02         20 unload_venue_cp0003_part_00.gz
2016-06-25 05:11:03        282 unload_venue_cpmanifest

-- Top Queries

SELECT trim(DATABASE)           AS DB,
  COUNT(query)                  AS n_qry,
  MAX(substring (qrytext,1,80)) AS qrytext,
  MIN(run_seconds)              AS "min" ,
  MAX(run_seconds)              AS "max",
  AVG(run_seconds)              AS "avg",
  SUM(run_seconds)              AS total,
  MAX(query)                    AS max_query_id,
  MAX(starttime)::DATE          AS last_run,
  aborted,
  event
FROM
  (SELECT userid,
    label,
    stl_query.query,
    trim(DATABASE)      AS DATABASE,
    trim(querytxt)      AS qrytext,
    md5(trim(querytxt)) AS qry_md5,
    starttime,
    endtime,
    DATEDIFF(seconds, starttime,endtime)::NUMERIC(12,2) AS run_seconds,
    aborted,
    DECODE(alrt.event,'Very selective query filter','Filter','Scanned a large number of deleted rows','Deleted','Nested Loop Join in the query plan','Nested Loop','Distributed a large number of rows across the network','Distributed','Broadcasted a large number of rows across the network','Broadcast','Missing query planner statistics','Stats',alrt.event) AS event
  FROM stl_query
  LEFT OUTER JOIN
    (SELECT query,
      trim(split_part(event,':',1)) AS event
    FROM STL_ALERT_EVENT_LOG
    WHERE event_time >= DATEADD(DAY, -7, CURRENT_DATE)
    GROUP BY query,
      trim(split_part(event,':',1))
    ) AS alrt
  ON alrt.query = stl_query.query
  WHERE userid <> 1
    -- and (querytxt like 'SELECT%' or querytxt like 'select%' )
    -- and database = ''
  AND starttime >= DATEADD(DAY, -7, CURRENT_DATE)
  )
GROUP BY DATABASE,
  label,
  qry_md5,
  aborted,
  event
ORDER BY total DESC limit 50;

-- Find the group that belongs to the user.

SELECT 
	pg_group.groname
	,pg_group.grosysid
	,pg_user.*
FROM pg_group, pg_user 
WHERE pg_user.usesysid = ANY(pg_group.grolist) 
ORDER BY 1,2;

-- Top 10 tables (include allocated+tombstone+free,metadata)

SELECT * FROM
(
  SELECT tbl,
CASE WHEN tbl > 0 THEN 'User_Table' WHEN tbl = 0 THEN 'Freed_Blocks' WHEN tbl = -2 THEN 'Catalog_File_Store' WHEN tbl = -3 THEN 'Metadata' WHEN tbl = -4 THEN 'Temp_Delete_Blocks' WHEN tbl = -6 THEN 'Query_Spill_To_Disk' ELSE 'Stage_blocks_For_Real_Table_DML' END as Block_type, 
CASE when tombstone > 0 THEN 'Tombstoned' ELSE 'Not Tombstoned' END as tombstone, 
count(*) AS size_mb
  FROM stv_blocklist
  GROUP BY 1,2,3
)
LEFT JOIN
(select distinct id, name FROM stv_tbl_perm)
ON id = tbl
ORDER BY size_mb DESC
LIMIT 10;

-- WLM + Commit queuing 

SELECT IQ.*,
  ((IQ.wlm_queue_time::FLOAT   /IQ.wlm_start_commit_time)*100)::DECIMAL(5,2) AS pct_wlm_queue_time,
  ((IQ.exec_only_time::FLOAT   /IQ.wlm_start_commit_time)*100)::DECIMAL(5,2) AS pct_exec_only_time,
  ((IQ.commit_queue_time::FLOAT/IQ.wlm_start_commit_time)*100)::DECIMAL(5,2) pct_commit_queue_time,
  ((IQ.commit_time::FLOAT      /IQ.wlm_start_commit_time)*100)::DECIMAL(5,2) pct_commit_time
FROM
  (SELECT TRUNC(b.starttime) AS DAY,
    d.service_class,
    c.node,
    COUNT(DISTINCT c.xid)                                            AS count_commit_xid,
    SUM(DATEDIFF('microsec', d.service_class_start_time, c.endtime)) AS wlm_start_commit_time,
    SUM(DATEDIFF('microsec', d.queue_start_time, d.queue_end_time )) AS wlm_queue_time,
    SUM(DATEDIFF('microsec', b.starttime, b.endtime))                AS exec_only_time,
    SUM(DATEDIFF('microsec', c.startwork, c.endtime)) commit_time,
    SUM(DATEDIFF('microsec', DECODE(c.startqueue,'2000-01-01 00:00:00',c.startwork,c.startqueue), c.startwork)) commit_queue_time
  FROM stl_query b ,
    stl_commit_stats c,
    stl_wlm_query d
  WHERE b.xid         = c.xid
  AND b.query         = d.query
  AND c.xid           > 0
  AND d.service_class > 4
  GROUP BY TRUNC(b.starttime),
    d.service_class,
    c.node
  ORDER BY TRUNC(b.starttime),
    d.service_class,
    c.node
  ) IQ; 

- day, date
- count_commit_xid, the amount of commit transactions for the 'day'
- node, we want to see node with a value of -1 which is the leader node, and this is where we will see the commit queue time
- pct_wlm_queue_time, percentage of time all the transactions spent waiting for an available slot (WLM Query Queue)
- pct_exec_only_time, percentage of time the actual statement spend in execution state
- pct_commit_queue_time, percentage of time the statement spend waiting in the 'commit queue'
- pct_commit_time, percentage of time that is spent actually committing 

Service_class=8 is the default queue. You can get this information from "select service_class,name from pg_catalog.stv_wlm_service_class_config;"

-- Copy using JSON path:

[ec2-user@ip-172-31-42-235 firehose]$ cat case.json 
{"eventId": "e+w9pEsDZHiJ8Lr5cw==","snoutHeaterTemperature": "54","supplyVoltage": "13238","coolerTemperature": "8","heatSinkTemperature": "75","capTemperature": "37","snoutTemperature": "19"}
{"eventId": "6V6st3bEq2wSoeEk2A==","snoutHeaterTemperature": "33","supplyVoltage": "13043","coolerTemperature": "23","heatSinkTemperature": "30","capTemperature": "62","snoutTemperature": "54"}

[ec2-user@ip-172-31-42-235 firehose]$ cat case_jsonpath.json 
{
    "jsonpaths": [
        "$['eventId']",
        "$['snoutHeaterTemperature']",
        "$['supplyVoltage']",
        "$['coolerTemperature']",
        "$['heatSinkTemperature']",
        "$['capTemperature']",
        "$['snoutTemperature']"
    ]
}

dev=# create table eptevent
(
eventid character varying(300) not null,
snoutheatertemperature character varying(20) ,
supplyvoltage character varying(20) ,
coolertemperature character varying(20) ,
heatsinktemperature character varying(20) ,
captemperature character varying(20) ,
snouttemperature character varying(20)
) 
sortkey  (eventid)
;

dev=# COPY eptevent FROM 's3://riccic-oregon/firehose/case.json' with credentials 'aws_access_key_id=AKIAIQAUQ2UBXLX4GUJQ;aws_secret_access_key=---' json 's3://riccic-oregon/firehose/case_jsonpath.json';
INFO:  Load into table 'eptevent' completed, 2 record(s) loaded successfully.
COPY
dev=# select * from eptevent;
       eventid        | snoutheatertemperature | supplyvoltage | coolertemperature | heatsinktemperature | captemperature | snouttemperature 
----------------------+------------------------+---------------+-------------------+---------------------+----------------+------------------
 6V6st3bEq2wSoeEk2A== | 33                     | 13043         | 23                | 30                  | 62             | 54
 e+w9pEsDZHiJ8Lr5cw== | 54                     | 13238         | 8                 | 75                  | 37             | 19
(2 rows)

--  WLM setting example

wlm_json_configuration 		
[{
"query_group_wild_card":0,
"user_group":["etl_users"],"max_execution_time":0,"user_group_wild_card":0,"query_group":["etl_query_group"],"query_concurrency":20},
{
"query_group_wild_card":0,
"user_group":[],"max_execution_time":0,"user_group_wild_card":0,"query_group":[],"query_concurrency":15}] 


-- Format columns with trim

for i in `echo "event                        |         recordtime         |            remotehost            |            remoteport            |  pid  |                   
    dbname                       |                      username                      |            authmethod            |  duration  |                     sslversion              
        |                                                            sslcipher                                                             |  mtu  |                          sslco 
mpression                          |                           sslexpansion" | paste - - - - - - | sed "s/ //g" | sed "s/\t//g" | sed "s/|/ /g"`; do echo "trim($i) $i,"; done
trim(event) event,
trim(recordtime) recordtime,
trim(remotehost) remotehost,
trim(remoteport) remoteport,
trim(pid) pid,
trim(dbname) dbname,
trim(username) username,
trim(authmethod) authmethod,
trim(duration) duration,
trim(sslversion) sslversion,
trim(sslcipher) sslcipher,
trim(mtu) mtu,
trim(sslcompression) sslcompression,
trim(sslexpansion) sslexpansion,


-- last connection logs

select trim(event) event,
trim(recordtime) recordtime,
trim(remotehost) remotehost,
trim(remoteport) remoteport,
trim(pid) pid,
trim(dbname) dbname,
trim(username) username,
trim(authmethod) authmethod,
trim(duration) duration,
trim(sslversion) sslversion,
trim(sslcipher) sslcipher,
trim(mtu) mtu,
trim(sslcompression) sslcompression,
trim(sslexpansion) sslexpansion
from stl_connection_log 
where recordtime > dateadd(hour, -2, getdate()) order by pid;

select trim(event) event,
trim(recordtime) recordtime,
trim(remotehost) remotehost,
trim(remoteport) remoteport,
trim(pid) pid,
trim(dbname) dbname,
trim(username) username,
trim(authmethod) authmethod,
trim(sslversion) sslversion,
trim(mtu) mtu,
from stl_connection_log 
where recordtime > dateadd(hour, -2, getdate()) order by pid;

--- Import encoded chars

http://docs.aws.amazon.com/redshift/latest/dg/copy-parameters-data-conversion.html#copy-encoding

[ec2-user@ip-172-31-25-113 redshift]$ cat encoded_chars.csv 
specific german characters like ä,ü,ö,ß

[ec2-user@ip-172-31-25-113 redshift]$ aws s3 cp encoded_chars.csv s3://riccic-syd/
upload: ./encoded_chars.csv to s3://riccic-syd/encoded_chars.csv

[ec2-user@ip-172-31-25-113 redshift]$ psql -h rs-syd-cluster.cstlcxvdnozb.ap-southeast-2.redshift.amazonaws.com -p 5439 -U master dev
psql (9.4.6, server 8.0.2)
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
Type "help" for help.

dev=# create table encoded_t (c1 varchar(100));
CREATE TABLE

dev=# copy encoded_t from 's3://riccic-syd/encoded_chars.csv' credentials 'aws_iam_role=arn:aws:iam::344492629025:role/RedshiftCopyUnload' encoding as UTF8;
INFO:  Load into table 'encoded_t' completed, 1 record(s) loaded successfully.
COPY
dev=# select * from encoded_t;
                   c1                    
-----------------------------------------
 specific german characters like ä,ü,ö,ß
(1 row)

dev=# copy encoded_t from 's3://riccic-syd/encoded_chars.csv' credentials 'aws_iam_role=arn:aws:iam::344492629025:role/RedshiftCopyUnload';
INFO:  Load into table 'encoded_t' completed, 1 record(s) loaded successfully.
COPY
dev=# select * from encoded_t;
                   c1                    
-----------------------------------------
 specific german characters like ä,ü,ö,ß
 specific german characters like ä,ü,ö,ß
(2 rows)

--- Redshift / Split file before load in S3 (using manifest)

CREATE TABLE series_series (
  created timestamp NOT NULL,
  modified timestamp NOT NULL,
  series_id varchar(255) NOT NULL,
  title varchar(255) NOT NULL,
  source varchar(255) NOT NULL,
  release varchar(255) NOT NULL,
  seasonal_adjustment varchar(255) NOT NULL,
  frequency varchar(255) NOT NULL,
  units varchar(255) NOT NULL,
  date_range varchar(255) NOT NULL,
  last_updated timestamp NOT NULL,
  popularity bigint NOT NULL,
  country_id bigint DEFAULT NULL,
  slug varchar(255) DEFAULT NULL,
  first_value float DEFAULT NULL,
  last_value float DEFAULT NULL,
  author_id bigint DEFAULT NULL,
  indicator_overview varchar(255)
);


$ perl dg_tt0086106067_series_series.pl | split -a 8 -d -l 100000 - tt0086106067_series_series.
$ for file in `ls tt0086106067_series_series.0*.gz`; do aws s3 cp s3://riccic-syd/$file; done
$ for file in `ls tt0086106067_series_series.0*.gz`; do aws s3 cp $file s3://riccic-syd/; done

$ cat tt0086106067_series_series.manifest 
{
  "entries": [
    {"url":"s3://riccic-syd/tt0086106067_series_series.00000000.gz", "mandatory":true},
    {"url":"s3://riccic-syd/tt0086106067_series_series.00000001.gz", "mandatory":true},
    {"url":"s3://riccic-syd/tt0086106067_series_series.00000002.gz", "mandatory":true}
  ]
}

$ aws s3 cp series_series.manifest s3://abc-syd/

dev=# copy series_series from 's3://abc-syd/series_series.manifest' credentials 'aws_iam_role=arn:aws:iam::xxxxxx:role/RedshiftCopyUnload' manifest csv timeformat as 'YYYY-MM-DD HH:MI:SS' null as 'NULL' gzip;
INFO: Load into table 'series_series' completed, 300000 record(s) loaded successfully.
COPY
copy encoded_t from 's3://riccic-syd/tt0086106067_series_series.manifest' credentials 'aws_iam_role=arn:aws:iam::344492629025:role/RedshiftCopyUnload' manifest csv timeformat as 'YYYY-MM-DD HH:MI:SS' null as 'NULL' gzip;

$ cat tt0086106067_series_series.sample.csv 
2013-10-02 15:15:15,2013-10-02 15:15:15,SERID1,tBNsgz2HZsziG9XkUNbSNHA5bceIOTrR,tBNsgz2HZsziG9XkUNbSNHA5bceIOTrR,,,tBNsgz2HZsziG9XkUNbSNHA5bceIOTrR,tBNsgz2HZsziG9XkUNbSNHA5bceIOTrR,tBNsgz2HZsziG9XkUNbSNHA5bceIOTrR,2013-10-02 15:15:15,26,46,NULL,26,26,NULL,NULL

--- ODBC Setup
http://www.easysoft.com/developer/interfaces/odbc/linux.html

http://docs.aws.amazon.com/redshift/latest/mgmt/install-odbc-driver-linux.html

[root@ip-172-31-25-113 redshift]# rpm -qilp AmazonRedshiftODBC-64bit-1.2.7.1007-1.x86_64.rpm
Name        : AmazonRedshiftODBC-64bit
Version     : 1.2.7
Release     : 1
Architecture: x86_64
Install Date: (not installed)
Group       : ODBC Driver
Size        : 42202358
License     : unknown
Signature   : (none)
Source RPM  : AmazonRedshiftODBC-64bit-1.2.7-1.src.rpm
Build Date  : Mon 11 Jan 2016 07:54:20 PM UTC
Build Host  : BA-CentOS5-03.bamboo.ad
Relocations : (not relocatable)
Vendor      : unknown
Summary     : amazonredshiftodbc-64bit
Description :
An ODBC driver providing connectivity to a Redshift data source.
/opt
/opt/amazon
/opt/amazon/redshiftodbc
/opt/amazon/redshiftodbc/Amazon Redshift ODBC Driver License Agreement.pdf
/opt/amazon/redshiftodbc/Amazon Redshift ODBC Driver License Agreement.txt
/opt/amazon/redshiftodbc/ErrorMessages
/opt/amazon/redshiftodbc/ErrorMessages/en-US
/opt/amazon/redshiftodbc/ErrorMessages/en-US/ODBCMessages.xml
/opt/amazon/redshiftodbc/ErrorMessages/en-US/PGOMessages.xml
/opt/amazon/redshiftodbc/Setup
/opt/amazon/redshiftodbc/Setup/odbc.ini
/opt/amazon/redshiftodbc/Setup/odbcinst.ini
/opt/amazon/redshiftodbc/lib
/opt/amazon/redshiftodbc/lib/64
/opt/amazon/redshiftodbc/lib/64/PostgreSQLODBC.did
/opt/amazon/redshiftodbc/lib/64/amazon.redshiftodbc.ini
/opt/amazon/redshiftodbc/lib/64/libamazonredshiftodbc64.so
[root@ip-172-31-25-113 redshift]# rpm -ivh AmazonRedshiftODBC-64bit-1.2.7.1007-1.x86_64.rpm
Preparing...                          ################################# [100%]
Updating / installing...
   1:AmazonRedshiftODBC-64bit-1.2.7-1 ################################# [100%]

[ec2-user@ip-172-31-25-113 ~]$ cat /etc/odbcinst.ini 
...
...

[Amazon Redshift (x86)]
Description=Amazon Redshift ODBC Driver(32-bit)
Driver=/opt/amazon/redshiftodbc/lib/32/libamazonredshiftodbc32.so

[Amazon Redshift (x64)]
Description=Amazon Redshift ODBC Driver(64-bit)
Driver=/opt/amazon/redshiftodbc/lib/64/libamazonredshiftodbc64.so


[ec2-user@ip-172-31-25-113 ~]$ odbcinst -j
unixODBC 2.2.14
DRIVERS............: /etc/odbcinst.ini
SYSTEM DATA SOURCES: /etc/odbc.ini
FILE DATA SOURCES..: /etc/ODBCDataSources
USER DATA SOURCES..: /home/ec2-user/.odbc.ini
SQLULEN Size.......: 8
SQLLEN Size........: 8
SQLSETPOSIROW Size.: 8



[ec2-user@ip-172-31-25-113 ~]$ cat ~/.odbc.ini 
[ODBC]
Trace=yes

[rs-syd-cluster]
# This key is not necessary and is only to give a description of the data source.
Description=Amazon Redshift ODBC Driver (64-bit) DSN

# Driver: The location where the ODBC driver is installed to.
Driver=/opt/amazon/redshiftodbc/lib/64/libamazonredshiftodbc64.so

# Required: These values can also be specified in the connection string.
Server=rs-syd-cluster.cstlcxvdnozb.ap-southeast-2.redshift.amazonaws.com
Port=5439
Database=dev
locale=en-US

# Optional: These values can also be specified in the connection string.
# sslmode=
# KeepAlive=1
# KeepAliveCount=0
# KeepAliveTime=0
# KeepAliveInterval=0
# SingleRowMode=0
# UseDeclareFetch=0
# Fetch=100
# UseMultipleStatements=0	
# UseUnicode=1
# BoolsAsChar=1
# TextAsLongVarchar=1
# MaxVarchar=255
# MaxLongVarchar=8190
# MaxBytea=255
# ProxyHost=
# ProxyPort=
	
#Note: You must specify PWD in the connection string if authentication is on. 
#UID can be saved as a part of the DSN or specified in the connection string. 



[ec2-user@ip-172-31-25-113 redshift]$ vi /opt/amazon/redshiftodbc/lib/64//amazon.redshiftodbc.ini

# Generic ODBCInstLib
#   iODBC
#ODBCInstLib=libiodbcinst.so

#   AmazonDM / unixODBC
ODBCInstLib=libodbcinst.so




[ec2-user@ip-172-31-25-113 ~]$ isql -v rs-syd-cluster master Master11
+---------------------------------------+
| Connected!                            |
|                                       |
| sql-statement                         |
| help [tablename]                      |
| quit                                  |
|                                       |
+---------------------------------------+
SQL> 

-- Date arithmetics

http://docs.aws.amazon.com/redshift/latest/dg/r_DATEADD_function.html
http://docs.aws.amazon.com/redshift/latest/dg/Date_functions_header.html

dev=# select max(cdate),min(cdate),datediff(days,min(cdate),max(cdate)),datediff(week,min(cdate),max(cdate)),dateadd(day,datediff(days,min(cdate),max(cdate)),getdate()),getdate() from caldates;
    max     |    min     | date_diff | date_diff |      date_add       |       getdate       
------------+------------+-----------+-----------+---------------------+---------------------
 2016-08-16 | 2016-08-06 |        10 |         2 | 2016-08-26 23:33:36 | 2016-08-16 23:33:36
(1 row)



-- Live steps running

dev=# select * from stv_exec_state order by rows desc limit 1;
-[ RECORD 1 ]---+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
userid          | 100
query           | 263980
slice           | 1
segment         | 8
step            | 8
starttime       | 2016-08-31 06:30:55.023359
currenttime     | 2016-08-31 06:37:48.148316
tasknum         | 20
rows            | 41511719001
bytes           | 0
label           | nestloop                                                                                                                                                                                                                                                        
is_diskbased    | f
workmem         | 0
num_parts       | 0
is_rrscan       | f
is_delayed_scan | f

-- Performance review

$ psql -h rs-syd-cluster.cstlcxvdnozb.ap-southeast-2.redshift.amazonaws.com -p 5439 -U master dev -f review_performance.sql

\o case1877367601.txt
\set vpattern 378696
\qecho -- Query Text - stl_explain
select * from stl_querytext where query = :vpattern;
\qecho -- Explain plan - stl_explain
select userid,query,nodeid,parentid,trim(plannode) plannode,trim(info) info from stl_explain where query = :vpattern;
\qecho --Review WLM Queuing for above queries - stl_wlm_query
SELECT TRIM(DATABASE) AS DB,
       w.query,
       SUBSTRING(q.querytxt,1,100) AS querytxt,
       w.queue_start_time,
       w.service_class AS class,
       w.slot_count AS slots,
       w.total_queue_time / 1000000 AS queue_seconds,
       w.total_exec_time / 1000000 exec_seconds,
       (w.total_queue_time + w.total_exec_time) / 1000000 AS total_seconds
FROM stl_wlm_query w
  LEFT JOIN stl_query q
         ON q.query = w.query
        AND q.userid = w.userid
WHERE w.query = :vpattern
--AND w.total_queue_time > 0
ORDER BY w.total_queue_time DESC,
         w.queue_start_time DESC;
\qecho --Get information about commit stats - stl_commit_stats
select startqueue,node, datediff(ms,startqueue,startwork) as queue_time, datediff(ms, startwork, endtime) as commit_time, queuelen 
from stl_commit_stats 
where xid in (select xid from stl_querytext where query = :vpattern)
order by queuelen desc , queue_time desc;
\qecho --Compile Time
select userid, xid,  pid, query, segment, locus,  
datediff(ms, starttime, endtime) as duration, compile 
from svl_compile 
where query = :vpattern;
\qecho --Understand other operations within the same PID - svl_statementtext
select userid,xid,pid,label,starttime,endtime,sequence,type,trim(text) from svl_statementtext where pid in (select pid from stl_querytext where query = :vpattern);
\qecho --Review query work - STL_PLAN_INFO
select * from STL_PLAN_INFO where query = :vpattern;
\qecho --Review query work - svl_query_report
select * from svl_query_report where query = :vpattern order by segment,step,slice;
\qecho --Review query work - svl_query_summary
select * from svl_query_summary where query = :vpattern order by seg,step;
\qecho -- Review alert
select * from stl_alert_event_log where query = :vpattern;
\qecho -- Review STL_ERROR
select userid,process,recordtime,pid,errcode,trim(file),linenum,trim(context),trim(error) from stl_error where recordtime between (select starttime from stl_query where query = :vpattern) and (select endtime from stl_query where query = :vpattern);
\q

-- enable verbosity

dev=# \set VERBOSITY verbose
dev=# 
dev=# select * from t111;
ERROR:  42P01: relation "t111" does not exist
LOCATION:  RangeVarGetRelid, /home/rdsdb/padb/src/pg/src/backend/catalog/namespace.c:222

-- Check Cursors space

http://kb.tableau.com/articles/issue/error-exceeded-the-maximum-size-allowed-creating-redshift-extract
http://docs.aws.amazon.com/redshift/latest/dg/declare.html#declare-constraints

dev=# begin; DECLARE allc CURSOR FOR select * from series_series;
dev=# fetch forward 100000 from allc;

dev=# select * from STV_CURSOR_CONFIGURATION;select * from STV_ACTIVE_CURSORS;
-[ RECORD 1 ]----------+-------
current_cursor_count   | 1
max_diskspace_usable   | 374400
current_diskspace_used | 9600

-[ RECORD 1 ]+---------------------------------------
userid       | 100
name         | allc                                                                                                                                                                                                                                                            
xid          | 1088952
pid          | 21224
starttime    | 2016-09-06 05:07:12.036683
row_count    | 300000
byte_count   | 94796004
fetched_rows | 100000

PROD 05:49:09 rs-syd-cluster:L:log$ ps axu | grep 21224 | grep -v grep
rdsdb    21224  0.0  0.3 10446844 47120 ?      S    05:07   0:01 padbmaster trap eader -user 3001 -group 104

PROD 05:09:39 rs-syd-cluster:L:log$ ls -lrt /proc/21224/fd
total 0
...
lrwx------ 1 rdsdb rds 64 Sep  6 05:09 26 -> /raid/pgsql_tmp/pgsql_tmp21224.0
...

/rdspgdata/data/data/pg/global/1262: data
PROD 05:45:46 rs-syd-cluster:L:log$ ls -lrt /raid/pgsql_tmp/pgsql_tmp21224.0
-rw------- 1 rdsdb rds 94796004 Sep  6 05:07 /raid/pgsql_tmp/pgsql_tmp21224.0

--  get data from a query

\o case1862133941.txt
\timing
select now();
--
WITH opportunities AS (     (SELECT
    category,
...
...
100.0 * impact/DECODE((SELECT MAX(impact) FROM opportunities),0,1,(SELECT MAX(impact) FROM opportunities)) AS percent_revenue
FROM
opportunities
ORDER BY impact DESC;
--
\set qid pg_last_query_id()
\set cid pg_backend_pid()
--
select :qid;
select substring(querytxt,1,20),query,xid,pid,starttime,endtime,datediff('msec',starttime,endtime) from stl_query where query = :qid;
select * from stl_wlm_query where pid = :qid;
select min(starttime),max(endtime),datediff('msec',min(starttime),max(endtime))  from pg_catalog.svl_compile where query = :qid;
select * from stl_connection_log where pid = :cid;
--
\q


-- Monitor activity live

** On Compute node
dev=# select datediff('usec',starttime,currenttime) elap_usec,datediff('min',starttime,currenttime) elap_min,query,slice,segment,step,tasknum,substring(label,25) lb,(rows/10000.0)::decimal(10,4) rows_per_k,(bytes/1024.0/1024.0)::decimal(10,4) MBytes,num_parts from stv_exec_state order by 10 desc limit 10;
 elap_usec  | elap_min | query  | slice | segment | step | tasknum |         lb         | rows_per_k |  mbytes   | num_parts 
------------+----------+--------+-------+---------+------+---------+--------------------+------------+-----------+-----------
 1980556176 |       33 | 475100 |   217 |       2 |    0 |     811 | tablename='i_hits' |  1061.5352 | 1792.5572 |         0
 1980565562 |       33 | 475100 |   189 |       2 |    0 |     387 | tablename='i_hits' |  1061.1071 | 1791.5969 |         0
 1980545236 |       33 | 475100 |   160 |       2 |    0 |    1247 | tablename='i_hits' |  1055.7376 | 1783.3050 |         0
 1980583284 |       33 | 475100 |   221 |       2 |    0 |    1246 | tablename='i_hits' |  1053.4447 | 1778.9275 |         0
 1980553031 |       33 | 475100 |   196 |       2 |    0 |    1257 | tablename='i_hits' |  1050.3191 | 1774.1041 |         0
 1980556300 |       33 | 475100 |   193 |       2 |    0 |     711 | tablename='i_hits' |  1050.6162 | 1773.4539 |         0
 1980565474 |       33 | 475100 |   192 |       2 |    0 |    1166 | tablename='i_hits' |  1049.8182 | 1772.8096 |         0
 1980559265 |       33 | 475100 |    15 |       2 |    0 |    1204 | tablename='i_hits' |  1048.4784 | 1771.2690 |         0
 1980558036 |       33 | 475100 |   195 |       2 |    0 |     729 | tablename='i_hits' |  1048.2175 | 1770.5622 |         0
 1980553602 |       33 | 475100 |   223 |       2 |    0 |     820 | tablename='i_hits' |  1046.6670 | 1768.3215 |         0
(10 rows)

On Leader node
dev=# select * from stv_wlm_query_state ;
   xid   |  task  | query  | service_class | slot_count |       wlm_start_time       |      state       | queue_time |  exec_time  
---------+--------+--------+---------------+------------+----------------------------+------------------+------------+-------------
 1223773 | 899368 | 899369 |             4 |          1 | 2016-09-17 04:29:57.141774 | Running          |          0 |         629
 1223160 | 899205 | 899206 |             8 |          1 | 2016-09-17 03:37:27.872012 | Returning        |          0 |  3149270335
 1209482 | 895778 | 895779 |             8 |          1 | 2016-09-16 19:37:56.24279  | Returning        |          0 | 31920899556
(3 rows)


-- Time break down of a statement

2016-09-17 00:59:02 UTC [ db=biuser:57dc9551.b965@bi pid=47461 xid=3417963 ]'LOG:  statement: UPDATE src_apps_cdc.mtl_item_locations SET last_update_login 
= CAST(NULL AS Decimal(18,0))  WHERE src_apps_cdc.mtl_item_locations.inventory_location_id = 314.0000000000 AND src_apps_cdc.mtl_item_locations.organization
_id = 109.0000000000;
'2016-09-17 00:59:02 UTC [ db=biuser:57dc9551.b965@bi pid=47461 xid=3417963 ]'LOG:  [ query id=850097 ] Statement queued to WLM.
'2016-09-17 00:59:11 UTC [ db=biuser:57dc9551.b965@bi pid=47461 xid=3417963 ]'LOG:  [ query id=850097 ] Statement execution cleanup.

dev=# select starttime,endtime ,datediff('msec',starttime,endtime) from stl_query where query = 850097;
         starttime          |          endtime           | date_diff 
----------------------------+----------------------------+-----------
 2016-09-17 00:59:02.819528 | 2016-09-17 00:59:11.996034 |      9177
(1 row)

dev=# select min(start_time),max(end_time),datediff('msec',min(start_time),max(end_time)) from svl_query_report where query = 850097;
            min             |            max             | date_diff 
----------------------------+----------------------------+-----------
 2016-09-17 00:59:08.583785 | 2016-09-17 00:59:11.994804 |      3411
(1 row)

dev=# SELECT TRIM(DATABASE) AS DB,
dev-#        w.query,
dev-#        SUBSTRING(q.querytxt,1,100) AS querytxt,
dev-#        w.queue_start_time,
dev-#        w.service_class AS class,
dev-#        w.slot_count AS slots,
dev-#        w.total_queue_time / 1000000 AS queue_seconds,
dev-#        w.total_exec_time / 1000000 exec_seconds,
dev-#        (w.total_queue_time + w.total_exec_time) / 1000000 AS total_seconds
dev-# FROM stl_wlm_query w
dev-#   LEFT JOIN stl_query q
dev-#          ON q.query = w.query
dev-#         AND q.userid = w.userid
dev-# WHERE w.userid > 1
dev-# AND w.query = :vpattern
dev-# ORDER BY w.total_queue_time DESC,
dev-#          w.queue_start_time DESC;
 db | query  |                                               querytxt                                               |      queue_start_time      | class | slots | queue_seconds | exec_seconds | total_seconds 
----+--------+------------------------------------------------------------------------------------------------------+----------------------------+-------+-------+---------------+--------------+---------------
 bi | 850097 | update src_apps_cdc.mtl_item_locations set last_update_login = null where organization_id = 109.0000 | 2016-09-17 00:59:02.820337 |     7 |     1 |             0 |            9 |             9
(1 row)

dev=# select startqueue,node, datediff(ms,startqueue,startwork) as queue_time, datediff(ms, startwork, endtime) as commit_time, queuelen 
dev-# from stl_commit_stats 
dev-# where xid in (select xid from stl_querytext where query = :vpattern);
         startqueue         | node |  queue_time  | commit_time | queuelen 
----------------------------+------+--------------+-------------+----------
 2016-09-17 00:59:11.996813 |   -1 |         2147 |        1585 |        1
 2000-01-01 00:00:00        |    0 | 527389154139 |        1584 |        0
 2000-01-01 00:00:00        |    1 | 527389154140 |        1567 |        0
(3 rows)


-- Blocks per table

-- Blocks per table
SELECT
trim(n.nspname) schema_name,
trim(c.relname) table_name,
b.tbl table_id,
trim(a.attname) column_name,
a.attnum column_id,
COUNT(b.tbl) MBytes,
sum(num_values) values_per_block,
((COUNT(b.tbl)*1024*1024)::decimal(38,2)/sum(num_values))::decimal(38,2) size_per_col_row_in_bytes
FROM
pg_class c,
pg_namespace n,
pg_attribute a,
stv_blocklist b
WHERE
n.nspname = '<SCHEMA>'
AND c.relname='<TABLE NAME>'
AND c.relnamespace = n.oid
AND c.oid = a.attrelid
AND c.oid = b.tbl
AND a.attnum = b.col
GROUP BY
trim(n.nspname),
trim(c.relname),
b.tbl,
trim(a.attname),
a.attnum
ORDER BY a.attnum; 

-- Statements per hour

dev=# select to_char(starttime,'yyyy-mm-dd-hh') by_hr,lower(substring(text,1,6)),count(1),count(1)/60.0 rate_by_min from svl_statementtext where sequence=0 group by 1,2 order by 1 desc;

     by_hr     | lower  | count | rate_by_min 
---------------+--------+-------+-------------
 2016-10-05-12 | set st |    13 |      0.2166
 2016-10-05-12 | select |    14 |      0.2333
 2016-10-04-12 | set st |   531 |      8.8500
 2016-10-04-12 | set qu |     2 |      0.0333
 2016-10-04-12 | select |   421 |      7.0166

-- Work per compute per hour

-> 
dev=# select to_char(start_time,'yyyy-mm-dd-hh') by_hour,s.node,count(1) tot_steps,sum(r.elapsed_time)/1000000 tot_ela_sec,sum(r.elapsed_time)/1000000/count(1)::decimal(10,2) elap_per_sec_step,sum(r.bytes) tot_bytes,sum(r.bytes)/count(1)::decimal(10,2) bytes_per_step,sum(r.rows) tot_rows,sum(r.rows)/count(1)::decimal(10,2) rows_per_step from svl_query_report r, stv_slices s where r.slice=s.slice and start_time between '2016-10-04 13:00' and '2016-10-04 17:00' and end_time > '2000-01-01 00:00:00' group by 1,2 order by 1,2 desc;

    by_hour    | node | tot_steps | tot_ela_sec | elap_per_sec_step |   tot_bytes   |   bytes_per_step   |  tot_rows   |   rows_per_step   
---------------+------+-----------+-------------+-------------------+---------------+--------------------+-------------+-------------------
 2016-10-04-01 |   63 |     13784 |      162948 |      11.821532211 |  673646702803 | 48871641.236433546 | 19067762730 | 1383325.792948345
 2016-10-04-01 |   62 |     13746 |      128290 |       9.332896842 |  615385735257 | 44768349.720427760 | 15567816148 | 1132534.275280081
...
 2016-10-04-01 |   40 |     13784 |      120515 |       8.743107951 |  678877928206 | 49251155.557603017 | 19303620580 | 1400436.780325014
 2016-10-04-01 |   39 |     13788 |      120320 |       8.726428778 |  685793944813 | 49738464.230707861 | 19358657556 | 1404022.161009573
 2016-10-04-01 |   38 |     13668 |      163032 |      11.928007023 |  592678764402 | 43362508.370061457 | 14182134328 | 1037615.915130231
 2016-10-04-01 |   37 |     13776 |      130432 |       9.468060394 |  677482978873 | 49178497.304950638 | 19046780779 | 1382606.037964576
 2016-10-04-01 |   36 |     13772 |      125925 |       9.143552134 |  688245831436 | 49974283.432762126 | 19377794075 | 1407042.845991867
...
 2016-10-04-04 |    3 |     24606 |      161070 |       6.545964398 |  254609122669 | 10347440.570145492 |  7820404946 |  317825.121758920
 2016-10-04-04 |    2 |     24588 |      166563 |       6.774158125 |  257816752009 | 10485470.636448674 |  7997730889 |  325269.679884496
 2016-10-04-04 |    1 |     24624 |      165349 |       6.714952891 |  256062836921 | 10398913.130320012 |  7791564343 |  316421.553890513
 2016-10-04-04 |    0 |     24624 |      161955 |       6.577119883 |  257642338995 | 10463057.951388888 |  7878232972 |  319941.235055230
(256 rows)

-> Include LABEL 
dev=# select to_char(start_time,'yyyy-mm-dd-hh') by_hour,s.node,substring(label,1,5) op,count(1) tot_steps,sum(r.elapsed_time)/1000000 tot_ela_sec,sum(r.elapsed_time)/1000000/count(1)::decimal(10,2) elap_per_sec_step,sum(r.bytes) tot_bytes,sum(r.bytes)/count(1)::decimal(10,2) bytes_per_step,sum(r.rows) tot_rows,sum(r.rows)/count(1)::decimal(10,2) rows_per_step from svl_query_report r, stv_slices s where r.slice=s.slice and start_time between '2016-10-04 13:00' and '2016-10-04 17:00' and end_time > '2000-01-01 00:00:00' group by 1,2,3 order by 1,2,3 desc;

    by_hour    | node |  op   | tot_steps | tot_ela_sec | elap_per_sec_step |   tot_bytes   |   bytes_per_step    |  tot_rows   |   rows_per_step   
---------------+------+-------+-----------+-------------+-------------------+---------------+---------------------+-------------+-------------------
 2016-10-04-01 |    0 | windo |        28 |          35 |       1.250000000 |             0 |         0.000000000 |    36743957 | 1312284.178571428
 2016-10-04-01 |    0 | uniqu |        64 |        1953 |      30.515625000 |             0 |         0.000000000 |      234321 |    3661.265625000
 2016-10-04-01 |    0 | sort  |       202 |        8445 |      41.806930693 |    6997570612 |  34641438.673267326 |    36899474 |  182670.663366336
 2016-10-04-01 |    0 | scan  |      3994 |       31277 |       7.830996494 |  603886516263 | 151198426.705808713 |  6411486773 | 1605279.612669003
 2016-10-04-01 |    0 | save  |       840 |        1211 |       1.441666666 |   56539782892 |  67309265.347619047 |   172555238 |  205422.902380952
 2016-10-04-01 |    0 | retur |      1014 |         485 |       0.478303747 |        306760 |       302.524654832 |        8659 |       8.539447731
 2016-10-04-01 |    0 | proje |      5348 |       58305 |      10.902206432 |             0 |         0.000000000 | 12193035923 | 2279924.443343305
 2016-10-04-01 |    0 | parse |        44 |           3 |       0.068181818 |             0 |         0.000000000 |       85227 |    1936.977272727

-- Stardard deviation of EXEC TIME per node (see mode 38 how it get highlighted)

-> Per node
select node,avg(tot_ela_sec),stddev(tot_ela_sec)::decimal(14,2) stddev_ela_sec from (select to_char(start_time,'yyyy-mm-dd-hh') by_hour,s.node,sum(r.elapsed_time)/1000000 tot_ela_sec from svl_query_report r, stv_slices s where r.slice=s.slice and start_time between '2016-10-04 13:00' and '2016-10-04 17:00' and end_time > '2000-01-01 00:00:00' group by 1,2) group by 1 order by 1 desc;

 node |  avg   | stddev_ela_sec 
------+--------+----------------
   63 | 213021 |       78382.37
   62 | 201023 |       69828.14
   61 | 190672 |       62174.29
   ...
   39 | 183783 |       59136.39
   38 | 274970 |      136738.91
   37 | 196437 |       64414.31
   ...
    2 | 197264 |       63964.20
    1 | 215535 |       77592.22
    0 | 188281 |       59288.67
(64 rows)

-- Stardard deviation of EXEC TIME, ROWS, BYTES, STEPS per node (search for large deviations)

-> Per node
select 
 node,
 avg(tot_ela_sec) avg_ela,stddev(tot_ela_sec)::decimal(14,2) stddev_ela_sec,
 avg(tot_rows) avg_rows,stddev(tot_rows)::decimal(14,2) stddev_rows,
 avg(tot_bytes) avg_bytes,stddev(tot_bytes)::decimal(14,2) stddev_bytes,
 avg(tot_steps) avg_bytes,stddev(tot_steps)::decimal(14,2) stddev_steps
from 
  (select to_char(start_time,'yyyy-mm-dd-hh') by_hour,s.node,
   sum(r.elapsed_time)/1000000 tot_ela_sec,sum(r.rows) tot_rows,sum(r.bytes) tot_bytes,count(1) tot_steps 
   from svl_query_report r, stv_slices s 
   where r.slice=s.slice and start_time between '2016-10-08 00:00' and '2016-10-14 23:59' and end_time > '2000-01-01 00:00:00' 
   group by 1,2
  ) 
group by 1 order by 1 desc;

-> per node and operation
dev=# select node,op,avg(tot_ela_sec),stddev(tot_ela_sec)::decimal(14,2) stddev_ela_sec from (select to_char(start_time,'yyyy-mm-dd-hh') by_hour,s.node,substring(label,1,5) op,count(1) tot_steps,sum(r.elapsed_time)/1000000 tot_ela_sec,sum(r.elapsed_time)/1000000/count(1)::decimal(10,2) elap_per_sec_step,sum(r.bytes) tot_bytes,sum(r.bytes)/count(1)::decimal(10,2) bytes_per_step,sum(r.rows) tot_rows,sum(r.rows)/count(1)::decimal(10,2) rows_per_step from svl_query_report r, stv_slices s where r.slice=s.slice and start_time between '2016-10-04 13:00' and '2016-10-04 17:00' and end_time > '2000-01-01 00:00:00' group by 1,2,3) group by 1,2 order by 2,4 desc limit 25;

 node |  op   |  avg   | stddev_ela_sec 
------+-------+--------+----------------
   38 | proje | 136451 |       79272.74
   20 | proje |  92094 |       34911.56
    0 | proje |  85776 |       32459.29
   40 | proje |  83543 |       32006.80
    0 | retur |    540 |         318.86
   40 | retur |    519 |         318.84
   20 | retur |    547 |         315.29
   38 | retur |   1074 |         214.45
   38 | save  |   4154 |        2384.09
   40 | save  |   3272 |        2159.67
    0 | save  |   3276 |        2158.52
   20 | save  |   3481 |        2037.98
   38 | scan  |  67743 |       41860.11
   20 | scan  |  49314 |       22381.03
    0 | scan  |  46157 |       20894.59
   40 | scan  |  45396 |       20715.63
   38 | sort  |  12140 |        5176.97
   40 | sort  |  12044 |        5171.15
    0 | sort  |  12049 |        5170.80
   20 | sort  |  12053 |        5168.52

-- Retransmit - rexmit standard deviation in the last few day (see which hosts are rexmit more either src or dst)

SELECT TO_CHAR(recordtime,'yyyy-mm-dd') by_day,
  src.node
  ||' -> '
  ||dest.node net_src_dest,
  COUNT(1) tot_rexmit,
  (SUM(t.len)/1024.0/1024.0)::DEC(38,2) LEN_mb
FROM stl_comm_rexmit t,
  stv_slices src,
  stv_slices dest
WHERE t.src_slice = src.slice
AND t.dst_slice   = dest.slice
AND recordtime BETWEEN '2016-10-04 13:00' AND '2016-10-15 23:59'
GROUP BY 1,2
ORDER BY 1;

   by_day   | net_src_dest | tot_rexmit | len_mb 
------------+--------------+------------+--------
 2016-10-12 | 1 -> 2       |       4447 |  37.17
 2016-10-12 | 1 -> 0       |         93 |   0.60
 2016-10-12 | 2 -> 0       |       1053 |   8.62
 2016-10-12 | 0 -> 3       |        943 |   2.36
 2016-10-12 | 3 -> 0       |       2038 |  17.04
 2016-10-12 | 2 -> 3       |       7733 |  63.96
 2016-10-12 | 3 -> 1       |       1289 |  10.56
 2016-10-12 | 3 -> 2       |        388 |   2.34
 2016-10-12 | 2 -> 1       |        154 |   0.95
 2016-10-12 | 0 -> 1       |       2775 |  22.96
 2016-10-12 | 0 -> 2       |       1150 |   9.30
 2016-10-12 | 1 -> 3       |       3784 |  27.49
 2016-10-13 | 0 -> 1       |       2462 |  20.59
 2016-10-13 | 3 -> 0       |       2148 |  17.89
 2016-10-13 | 3 -> 2       |        500 |   3.20
 2016-10-13 | 1 -> 0       |        194 |   1.40
 2016-10-13 | 1 -> 2       |       3783 |  31.58
 2016-10-13 | 2 -> 0       |       1005 |   8.23
 2016-10-13 | 0 -> 2       |       1205 |   8.95
 2016-10-13 | 2 -> 1       |        200 |   1.57
 2016-10-13 | 3 -> 1       |       1664 |  13.56
 2016-10-13 | 2 -> 3       |       6128 |  49.86
 2016-10-13 | 1 -> 3       |       2514 |  19.11
 2016-10-13 | 0 -> 3       |        834 |   2.26

SELECT net_src_dest,
  AVG(tot_rexmit) avg_tot_rexmit_mb,
  stddev(tot_rexmit)::DECIMAL(14,2) stddev_tot_rexmit_mb
FROM
  (SELECT TO_CHAR(recordtime,'yyyy-mm-dd') by_day,
    src.node
    ||' -> '
    ||dest.node net_src_dest,
    COUNT(1) tot_rexmit,
    (SUM(t.len)/1024.0/1024.0)::DEC(38,2) LEN_mb
  FROM stl_comm_rexmit t,
    stv_slices src,
    stv_slices dest
  WHERE t.src_slice = src.slice
  AND t.dst_slice   = dest.slice
  AND recordtime BETWEEN '2016-10-04 13:00' AND '2016-10-15 23:59'
  GROUP BY 1,2
  )
GROUP BY 1
ORDER BY 3;

 net_src_dest | avg  | stddev_tot_rexmit 
--------------+------+-------------------
 3 -> 1       | 1317 |            883.34
 1 -> 2       | 2881 |           1797.86
 1 -> 0       |  112 |             71.60
 0 -> 2       |  804 |            526.34
 3 -> 2       |  400 |            269.51
 1 -> 3       | 2359 |           1514.86
 2 -> 3       | 5044 |           3123.62
 2 -> 1       |  172 |            122.82
 0 -> 1       | 1672 |           1187.79
 3 -> 0       | 1448 |            875.45
 2 -> 0       |  716 |            441.20
 0 -> 3       |  667 |            423.95
(12 rows)



-- Blocks
select
svvti.schema
,svvti.table
,c_sub.tbl as table_id
,c_sub.block_type
,c_sub.num_of_blocks as space_used_GB
, c_sub.tombstone
FROM (select
tbl
,CASE WHEN tbl > 0  THEN 'User_Table'
             WHEN tbl = 0  THEN 'Freed_Blocks'
             WHEN tbl = -2 THEN 'Catalog_File_Store'
             WHEN tbl = -3 THEN 'Metadata'
             WHEN tbl = -4 THEN 'Temp_Delete_Blocks'
             WHEN tbl = -6 THEN 'Query_Spill_To_Disk'
             ELSE 'Stage_blocks_For_Real_Table_DML'
         END as Block_type,
CASE when tombstone > 0 THEN 1 ELSE 0 END as tombstone,
         count(1)/1024 as num_of_blocks
from    stv_blocklist
group by 1 , 2, 3
having count(1)/1024 > 0
order by 1, 2, 3) c_sub
LEFT JOIN svv_table_info svvti on svvti.table_id = c_sub.tbl
order by 5 DESC
;

-- S3 work

dev=# select s.node,sum(data_size)/1024/1024 uncompress_mb,sum(transfer_size)/1024/1024 transfer_mb,(sum(transfer_size)/1024/1024)/(avg(transfer_time)/1000000) rate_mb_per_sec,avg(transfer_time)/1000000/60 transfer_min,avg(compression_time)/1000000/60 compress_min,avg(app_connect_time)/1000000/60 app_min,avg(connect_time)/1000000/60 conn_min,sum(retries) from stl_s3client s3,stv_slices s where query=15550960 and s.slice=s3.slice group by 1 order by 1;
 node | uncompress_mb | transfer_mb | rate_mb_per_sec | transfer_min | compress_min | app_min | conn_min | sum 
------+---------------+-------------+-----------------+--------------+--------------+---------+----------+-----
    0 |        132473 |        9685 |              12 |           12 |            0 |       0 |        0 |   0
    1 |        131309 |        9598 |              13 |           11 |            0 |       0 |        0 |   3
    2 |        129211 |        9446 |              13 |           12 |            0 |       0 |        0 |   4
    3 |        132472 |        9684 |              12 |           12 |            0 |       0 |        0 |   0
    4 |        132455 |        9683 |              12 |           13 |            0 |       0 |        0 |   1
    5 |        132048 |        9653 |              12 |           12 |            0 |       0 |        0 |   2
    6 |        131071 |        9582 |              12 |           12 |            0 |       0 |        0 |   2
    7 |        132471 |        9685 |              12 |           12 |            0 |       0 |        0 |   0
    8 |        130995 |        9577 |              13 |           12 |            0 |       0 |        0 |   2
    9 |        132322 |        9673 |              12 |           13 |            0 |       0 |        0 |   1
   10 |        132277 |        9669 |              12 |           12 |            0 |       0 |        0 |   1
   11 |        132211 |        9665 |              12 |           12 |            0 |       0 |        0 |   1
   12 |        127861 |        9346 |              12 |           12 |            0 |       0 |        0 |   6
   13 |        132472 |        9685 |              13 |           12 |            0 |       0 |        0 |   0
   14 |        130896 |        9569 |              12 |           12 |            0 |       0 |        0 |   1
(15 rows)

dev=# select count(1),case when transfer_min between 0 and 1 then '0_1' when transfer_min between 2 and 5 then '2_5' else '6_plus' end time_in_min from (  select slice,data_size/1024/1024 uncompress_mb,transfer_size/1024/1024 transfer_mb,transfer_time/1000000/60 transfer_min,compression_time/1000000/60 compress_min,app_connect_time/1000000/60 app_min,connect_time/1000000/60 conn_min,retries,recordtime from stl_s3client where query=15550960 order by 4,slice,start_time ) group by 2 order by 2
dev-# ;
 count | time_in_min 
-------+-------------
     6 | 0_1
   200 | 2_5
   996 | 6_plus
(3 rows)

SELECT s.node,
  (SUM(data_size)       /1024.0/1024.0)::                                DECIMAL(38,2) uncompress_mbytes,
  (SUM(transfer_size)   /1024.0/1024.0)::                                DECIMAL(38,2) transfer_mbytes,
  ((SUM(transfer_size)  /1024.0/1024.0)/(AVG(transfer_time)/1000000.0))::DECIMAL(38,2) rate_mb_per_sec,
  (AVG(transfer_time)   /1000000.0/60.0)::                               DECIMAL(38,2) transfer_min,
  (AVG(compression_time)/1000000.0/60.0)::                               DECIMAL(38,2) compress_min,
  (AVG(app_connect_time)/1000000.0/60.0)::                               DECIMAL(38,2) app_min,
  (AVG(connect_time)    /1000000.0/60.0)::                               DECIMAL(38,2) conn_min,
  SUM(retries) tot_retries
FROM stl_s3client s3,
  stv_slices s
WHERE query=645606
AND s.slice=s3.slice
GROUP BY 1;

SELECT COUNT(1),
  CASE
    WHEN transfer_min BETWEEN 0 AND 1
    THEN '0_1'
    WHEN transfer_min BETWEEN 0 AND 1
    THEN '2_3'
    WHEN transfer_min BETWEEN 0 AND 1
    THEN '3_4'
    WHEN transfer_min BETWEEN 0 AND 1
    THEN '5_6'   
    WHEN transfer_min BETWEEN 0 AND 1
    THEN '7_8'
    WHEN transfer_min BETWEEN 0 AND 1
    THEN '9_10'
    ELSE '11_plus'
  END time_in_min
FROM
  (SELECT s.node,
    (SUM(data_size)       /1024.0/1024.0)::                                DECIMAL(38,2) uncompress_mbytes,
    (SUM(transfer_size)   /1024.0/1024.0)::                                DECIMAL(38,2) transfer_mbytes,
    ((SUM(transfer_size)  /1024.0/1024.0)/(AVG(transfer_time)/1000000.0))::DECIMAL(38,2) rate_mb_per_sec,
    (AVG(transfer_time)   /1000000.0/60.0)::                             DECIMAL(38,2) transfer_min,
    (AVG(compression_time)/1000000.0/60.0)::                             DECIMAL(38,2) compress_min,
    (AVG(app_connect_time)/1000000.0/60.0)::                             DECIMAL(38,2) app_min,
    (AVG(connect_time)    /1000000.0/60.0)::                             DECIMAL(38,2) conn_min,
    SUM(retries) tot_retries
  FROM stl_s3client s3,
    stv_slices s
  WHERE query=645606
  AND s.slice=s3.slice
  GROUP BY 1
  )
GROUP BY 2
ORDER BY 2;

-- Time files take to download from S3

SELECT node,
  max(lg) max_time_in_sec_to_dwnl_from_s3,
  COUNT(1) file_count
FROM
  (SELECT *
  FROM
    (SELECT query,
      s.node,
      s.slice,
      curtime,
      lag(curtime) over (order by query,curtime),
      DATEDIFF('sec',lag(curtime) over (partition BY query order by curtime),curtime) lg -- Get the diff time between files loads
    FROM stl_load_commits c,
      stv_slices s
    WHERE s.slice=c.slice
    AND curtime > dateadd('min',-10,sysdate)
    --AND query   IN      (SELECT query FROM stl_load_commits GROUP BY query HAVING COUNT(1)=60) -- COPY that loads 60 files only
    ORDER BY query,
      curtime
    )
  --WHERE lg > 30 -- Get those files that takes longer than 30 sec to download
  ORDER BY 4 DESC
  )
GROUP BY node
ORDER BY 2 DESC;

 node | max_time_in_sec_to_dwnl_from_s3 | file_count 
------+---------------------------------+------------
    1 |                               1 |        478
    7 |                               1 |        477
   15 |                               1 |        480
   19 |                               1 |        479
   10 |                               1 |        478
    9 |                               1 |        477
    4 |                               1 |        479
   12 |                               1 |        481
   28 |                               1 |        476
   17 |                               1 |        478
   13 |                               1 |        481
   24 |                               1 |        477
    8 |                               1 |        477
   30 |                               1 |        479
   35 |                               1 |        479
   27 |                               1 |        476
   26 |                               1 |        476
   20 |                               1 |        479
   34 |                               1 |        480
    3 |                               1 |        479
   14 |                               1 |        481
   32 |                               1 |        479
   33 |                               1 |        480
   25 |                               1 |        476
   21 |                               1 |        478
    2 |                               1 |        478
    5 |                               1 |        479
    6 |                               1 |        478
    0 |                               0 |        477
   11 |                               0 |        479
   22 |                               0 |        477
   31 |                               0 |        479
   18 |                               0 |        478
   29 |                               0 |        478
   16 |                               0 |        480
   23 |                               0 |        477
(36 rows)

-- Review WLM conurrency settings over time

dev=# WITH
dev-#         -- Replace STL_SCAN in generate_dt_series with another table which has > 604800 rows if STL_SCAN does not
dev-#         generate_dt_series AS (select sysdate - (n * interval '5 second') as dt from (select row_number() over () as n from stl_scan limit 40320)),
dev-#         apex AS (SELECT iq.dt, iq.service_class, iq.num_query_tasks, count(iq.slot_count) as service_class_queries, sum(iq.slot_count) as service_class_slots
dev(#                 FROM
dev(#                 (select gds.dt, wq.service_class, wscc.num_query_tasks, wq.slot_count
dev(#                 FROM stl_wlm_query wq
dev(#                 JOIN stv_wlm_service_class_config wscc ON (wscc.service_class = wq.service_class AND wscc.service_class > 4)
dev(#                 JOIN generate_dt_series gds ON (wq.service_class_start_time <= gds.dt AND wq.service_class_end_time > gds.dt)
dev(#                 WHERE wq.userid > 1 AND wq.service_class > 4) iq
dev(#         GROUP BY iq.dt, iq.service_class, iq.num_query_tasks),
dev-#         maxes as (SELECT apex.service_class, trunc(apex.dt) as d, date_part(h,apex.dt) as dt_h, max(service_class_slots) max_service_class_slots
dev(#                         from apex group by apex.service_class, apex.dt, date_part(h,apex.dt))
dev-# SELECT apex.service_class, apex.num_query_tasks as max_wlm_concurrency, maxes.d as day, maxes.dt_h || ':00 - ' || maxes.dt_h || ':59' as hour, MAX(apex.service_class_slots) as max_service_class_slots
dev-# FROM apex
dev-# JOIN maxes ON (apex.service_class = maxes.service_class AND apex.service_class_slots = maxes.max_service_class_slots)
dev-# GROUP BY  apex.service_class, apex.num_query_tasks, maxes.d, maxes.dt_h
dev-# ORDER BY apex.service_class, maxes.d, maxes.dt_h;

 service_class | max_wlm_concurrency |    day     |     hour      | max_service_class_slots
---------------+---------------------+------------+---------------+-------------------------
             6 |                  20 | 2016-10-16 | 16:00 - 16:59 |                       2
             6 |                  20 | 2016-10-16 | 17:00 - 17:59 |                       2
             6 |                  20 | 2016-10-16 | 18:00 - 18:59 |                       2
             6 |                  20 | 2016-10-16 | 19:00 - 19:59 |                       2
             6 |                  20 | 2016-10-16 | 20:00 - 20:59 |                       2
             6 |                  20 | 2016-10-16 | 21:00 - 21:59 |                       2
             6 |                  20 | 2016-10-16 | 22:00 - 22:59 |                       1
             6 |                  20 | 2016-10-16 | 23:00 - 23:59 |                       3
             6 |                  20 | 2016-10-17 | 0:00 - 0:59   |                       2
             6 |                  20 | 2016-10-17 | 1:00 - 1:59   |                       3
             6 |                  20 | 2016-10-17 | 2:00 - 2:59   |                       1
             6 |                  20 | 2016-10-17 | 3:00 - 3:59   |                       3
             6 |                  20 | 2016-10-17 | 4:00 - 4:59   |                       2

-- Reviewing ANALYZE command

dev=# set analyze_threshold_percent to 100;
SET
dev=# analyze t22;
ANALYZE

dev=# select * from stl_analyze where xid in (select xid from stl_utilitytext where text ilike 'analyze%t22%' and starttime > dateadd('h',-2,sysdate));
 userid |   xid   |            database            | table_id |     status      | rows | modified_rows | threshold_percent | is_auto |         starttime          |          endtime           
--------+---------+--------------------------------+----------+-----------------+------+---------------+-------------------+---------+----------------------------+----------------------------
    100 | 2054218 | dev                            |   275916 | Full            |    8 |             0 |               100 | f       | 2016-10-25 22:33:39.257134 | 2016-10-25 22:33:40.862834
(1 row)

dev=# select * from svl_statementtext where pid=12242 and text ilike '%sample%t22%';
 userid |   xid   |  pid  |             label              |         starttime          |          endtime           | sequence | type  |                                                                                                   text                                               
                                                    
--------+---------+-------+--------------------------------+----------------------------+----------------------------+----------+-------+-------------------------------------------------------
    100 | 2054218 | 12242 | default                        | 2016-10-25 22:33:39.273206 | 2016-10-25 22:33:40.862278 |        0 | QUERY | padb_fetch_sample: select * from t22
    100 | 2054218 | 12242 | default                        | 2016-10-25 22:33:39.257187 | 2016-10-25 22:33:39.272971 |        0 | QUERY | padb_fetch_sample: select count(*) from t22
                                                   
(2 rows)

dev=# select * from pg_statistic_indicator i, stv_tbl_perm p where p.id=i.stairelid and p.name='t22';
 stairelid | stairows | staiins | staidels | slice |   id   |                                   name                                   | rows | sorted_rows | temp | db_id  | insert_pristine | delete_pristine | backup 
-----------+----------+---------+----------+-------+--------+--------------------------------------------------------------------------+------+-------------+------+--------+-----------------+-----------------+--------
    275916 |        8 |       0 |        0 |  6411 | 275916 | t22                                                                      |    0 |           0 |    0 | 100064 |               3 |               1 |      1
    275916 |        8 |       0 |        0 |     3 | 275916 | t22                                                                      |    2 |           0 |    0 | 100064 |               0 |               1 |      1
    275916 |        8 |       0 |        0 |     1 | 275916 | t22                                                                      |    2 |           0 |    0 | 100064 |               0 |               1 |      1
    275916 |        8 |       0 |        0 |     2 | 275916 | t22                                                                      |    2 |           0 |    0 | 100064 |               0 |               1 |      1
    275916 |        8 |       0 |        0 |     0 | 275916 | t22                                                                      |    2 |           0 |    0 | 100064 |               0 |               1 |      1
(5 rows)

dev=# select pg_class.reltuples from pg_class where oid in (SELECT table_id FROM SVV_TABLE_INFO sv WHERE sv.table = 't22' and sv.schema = 'public');
 reltuples 
-----------
         8
(1 row)
