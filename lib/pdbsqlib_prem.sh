#  /**********************************/
# /*       SQL FUNCTIONS            */
#/**********************************/
#
## Load the sql libraries. The following sripts needs to be located in the lib folder.
#. $(dirname $0)/lib/pdbsqlib_prem.sh
#. $(dirname $0)/lib/pdbsqlib_cloud.sh
# -- STATUS ALL PDBs
status_pdb ()
{
sqlplus -s / as sysdba << EOF 2>&1
set feedback off verify off echo off;
show pdbs;
EOF
}
# -- START ALL PDBs
start_all_pdb ()
{
printInfo "Starting ALL PDBs "
printSeparator

sqlplus -s / as sysdba << EOF 2>&1 >> ${LOG_FILE}
set serveroutput on;
BEGIN
-- Logging
dbms_output.put_line('Starting ALL pluggable databases');
--
EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ALL OPEN';
EXCEPTION
WHEN OTHERS THEN
  dbms_output.put_line('Unexpected error ocurrs: '||sqlerrm);
END;
/
exit 0
EOF
printSeparator
}
## -- STOP ALL PDBs
stop_all_pdb ()
{
printInfo "Stopping ALL PDBs "
printSeparator

sqlplus -s / as sysdba << EOF 2>&1 >> ${LOG_FILE}
set serveroutput on;
BEGIN
-- Logging
dbms_output.put_line('Stopping ALL pluggable databases');
--
EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ALL CLOSE IMMEDIATE';
EXCEPTION
WHEN OTHERS THEN
  dbms_output.put_line('Unexpected error ocurrs: '||sqlerrm);
END;
/
exit 0
EOF
printSeparator
}
## -- STOP A PDB
stop_pdb ()
{
printInfo "Stopping PDB : ${PDBNAME} "
printSeparator

sqlplus -s / as sysdba << EOF 2>&1 >> ${LOG_FILE}
set serveroutput on;
DECLARE
pdbName VARCHAR2(32);
pdbMode VARCHAR2(32);
BEGIN
select name,open_mode into pdbName,pdbMode from v\$pdbs where name = '${PDBNAME}';
if pdbMode like ('READ%') then
-- Logging
dbms_output.put_line('Stopping pluggable database: '||pdbName);
--
EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ' || pdbName || ' CLOSE IMMEDIATE';
else
-- Logging
dbms_output.put_line('PDB is already in '||pdbMode||' mode.');
--
end if;
EXCEPTION
WHEN NO_DATA_FOUND THEN
  dbms_output.put_line('Pluggable database does not exists: '||sqlerrm);
  --NULL;
END;
/
exit 0
EOF
printSeparator
}
## -- START A PDB
start_pdb ()
{
printInfo "Starting a PDB in MOUNT state : ${PDBNAME} "
printSeparator

sqlplus -s / as sysdba << EOF 2>&1 >> ${LOG_FILE}
set serveroutput on;
DECLARE
pdbName VARCHAR2(32);
pdbMode VARCHAR2(32);
BEGIN
select name,open_mode into pdbName,pdbMode from v\$pdbs where name = '${PDBNAME}';
if pdbMode like ('MOUNT%') then
-- Logging
dbms_output.put_line('Starting pluggable database: '||pdbName);
--
EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ' || pdbName || ' OPEN';
else
-- Logging
dbms_output.put_line('PDB is already in '||pdbMode||' mode.');
--
end if;
EXCEPTION
WHEN NO_DATA_FOUND THEN
  dbms_output.put_line('Pluggable database does not exists: '||sqlerrm);
  --NULL;
END;
/
exit 0
EOF
printSeparator
}
## -- CREATE EMPTY PDB FROM PDB$SEED
create_pdb ()
{
printInfo "Privisioning PDB : ${PDBNAME} "
printSeparator

sqlplus -s / as sysdba << EOF 2>&1 >> ${LOG_FILE}
set serveroutput on;
set echo on
set time on
set timin on
WHENEVER SQLERROR EXIT 1
prompt '----------------------------------'
prompt 'Putting template on READ ONLY mode'
prompt '----------------------------------'

declare
pdbMode varchar2(32);
templateName varchar2(32);
begin

templateName := '${TEMPLATE}';
select open_mode into pdbMode from v\$pdbs where name = templateName;

if pdbMode = 'READ WRITE' then
EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ' || templateName  || ' CLOSE IMMEDIATE';
EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ' || templateName  || ' OPEN READ ONLY';
elsif pdbMode <> 'READ ONLY' then
raise_application_error(-20001,'Incompatible mode ' || pdbMode || ' for ' || templateName );
end if;
end;
/

prompt '-----------------'
prompt 'Creating new PDB'
prompt '-----------------'
CREATE PLUGGABLE DATABASE ${PDBNAME} FROM ${TEMPLATE};

prompt '---------------------------------'
prompt 'Openning new PDB and saving state'
prompt '---------------------------------'

ALTER PLUGGABLE DATABASE ${PDBNAME} OPEN;
ALTER PLUGGABLE DATABASE ${PDBNAME} SAVE STATE;
ALTER SESSION SET CONTAINER=${PDBNAME} ;
show con_name

exit 0
EOF
EXIT_CODE=${?}
printSeparator

if [ ${EXIT_CODE} != 0 ]; then
  printWarning "Couldn't create PDB"
  printWarning "Aborting creation of ${PDBNAME}"
  ## Send email
  #sendEmail "${PRINT_ACTION} ABORTED of ${SHOP_NAME}" "${SHOP_INFO}"
  continue;
fi
}

## -- REMOVE A PDB
remove_pdb ()
{
printInfo "Dropping a PDB : ${PDBNAME} "
printSeparator

sqlplus -s / as sysdba << EOF 2>&1 >> ${LOG_FILE}
set serveroutput on;
set echo on
set time on
set timin on
WHENEVER SQLERROR EXIT 1

prompt '--------------'
prompt 'Dropping a PDB'
prompt '--------------'

DECLARE
  pdbName VARCHAR2(32);
  pdbMode VARCHAR2(32);
BEGIN
select name,open_mode into pdbName,pdbMode from v\$pdbs where name = '${PDBNAME}';
--
if pdbMode like ('READ%') then
  EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ' || pdbName || ' CLOSE IMMEDIATE';
  EXECUTE IMMEDIATE 'DROP PLUGGABLE DATABASE ' || pdbName || ' INCLUDING DATAFILES';
elsif pdbMode = 'MOUNTED' then
  EXECUTE IMMEDIATE 'DROP PLUGGABLE DATABASE ' || pdbName || ' INCLUDING DATAFILES';
else 
  raise_application_error(-20001,'Incompatible mode ' || pdbMode || ' for ' || '${PDBNAME}' );
end if;
EXCEPTION
WHEN NO_DATA_FOUND THEN
  dbms_output.put_line('Pluggable database does not exists: '||sqlerrm);
WHEN OTHERS THEN
  raise_application_error(-20009,'Unknow error. Please contact your administrator: ' || sqlerrm);
END;
/

exit 0
EOF
EXIT_CODE=${?}
printSeparator

if [ ${EXIT_CODE} != 0 ]; then
  printWarning "Couldn't remove a PDB"
  printWarning "Aborting removal of ${PDBNAME}"
  ## Send email
  sendEmail "ABORTED removal of ${PDBNAME}"
fi
}
