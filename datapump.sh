echo Enter Source End Point:
read SOURCE_END_POINT
echo Enter Source Schema Name:
read SOURCE_SCHEMA
echo Enter Target End Point:
read TARGET_END_POINT
echo Enter Target Schema:
read TARGET_SCHEMA
echo Enter Target Password:
read TARGET_PASSWORD
echo Enter Import User Password:
read IMPORT_USER_PASSWORD
echo Enter Source TableSpace:
read SOURCE_TABLESPACE
echo Enter Target Tablespace:
read TARGET_TABLESPACE
echo Enter Export User Password
read EXPORT_USER_PASSWORD
#echo Enter SCN:
#read SCN

sqlplus "epadmin/$IMPORT_USER_PASSWORD@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=$TARGET_END_POINT)(Port=1521))(CONNECT_DATA=(SID=ORCL)))" <<EOF
create or replace procedure REMOVE
as
begin
utl_file.fremove('DATA_PUMP_DIR','expdp_test.dmp');
end REMOVE;
/

exec REMOVE;
EOF

#sqlplus -s epadmin/tmoweb1234@$1 <<EOF > current_scn.txt
#select current_scn from v\$database;
#exit
#EOF
#SCN=$(tail -2 current_scn.txt)
#echo $SCN
# Capture SCN
SCN=`sqlplus -s "epadmin/$EXPORT_USER_PASSWORD@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=$SOURCE_END_POINT)(Port=1521))(CONNECT_DATA=(SID=ORCL)))" <<EOF
set pages 0
set head off
set feed off
@test.sql
exit
EOF`

echo $SCN

# Export Data
expdp epadmin/$EXPORT_USER_PASSWORD@\"\(DESCRIPTION=\(ADDRESS=\(PROTOCOL=TCP\)\(Host=$SOURCE_END_POINT\) \(Port=1521\)\)\(CONNECT_DATA=\(SID=ORCL\)\)\)\" directory=DATA_PUMP_DIR dumpfile=expdp_test.dmp logfile=expdp_test.log schemas=$SOURCE_SCHEMA include=TABLE:\"IN\(\'TRULE\', \'TRULEPARAMETER\', \'TLOCALIZEDPROPERTIES\', \'TCOUPON\', \'TCOUPONCONFIG\',\'TCOUPONUSAGE\',\'TVALIDATIONCONSTRAINTS\', \'TTAGVALUETYPEOPERATOR\', \'TTAGOPERATOR\', \'TTAGDICTIONARYTAGDEFINITION\', \'TTAGALLOWEDVALUE\', \'TTAGDEFINITION\', \'TTAGGROUP\', \'TTAGVALUETYPE\', \'TSELLINGCONTEXTCONDITION\', \'TTAGCONDITION\', \'TTAGDICTIONARY\',\'TPAYMENTGATEWAYPROPERTIES\', \'TSTOREPAYMENTGATEWAY\', \'TPAYMENTGATEWAY\', \'TSTORETAXCODE\', \'TSTORECREDITCARDTYPE\', \'TSTOREWAREHOUSE\', \'TRULEEXCEPTION\', \'TRULEELEMENT\', \'TRULESET\', \'TSELLINGCONTEXT\', \'TSHIPPINGSERVICELEVEL\', \'TSHIPPINGCOSTCALCULATIONPARAM\', \'TSHIPPINGCOSTCALCULATIONMETHOD\', \'TSHIPPINGREGION\', \'TWAREHOUSE\',\'TSTORE\',\'TCATALOG\',\'TTAXCODE\', \'TIMPORTJOB\', \'TPRODUCTASSOCIATION\', \'TRATEPLANRULE\',\'TSKUOPTION\',\'TSTORECATALOG\',\'TSKUOPTIONVALUE\',\'TSYNONYMGROUPS\',\'TSYNONYM\',\'TPRICELISTASSIGNMENT\',\'TRULESTORAGE\',\'TCATALOGSUPPORTEDLOCALE\',\'TCATEGORY\',\'TLINKEDCATEGORY\',\'TCATEGORYTYPE\',\'TCATEGORYTYPEATTRIBUTE\',\'TMASTERCATEGORY\',\'TIMPORTNOTIFICATION\',\'TIMPORTNOTIFICATIONMETADATA\',\'TIMPORTBADROW\',\'TIMPORTFAULT\',\'TIMPORTJOBSTATUS\',\'TCSDYNAMICCONTENTDELIVERY\',\'TCSDYNAMICCONTENT\',\'TCSDYNAMICCONTENTSPACE\',\'TIMPORTJOB\',\'TIMPORTMAPPINGS\',\'TSTORESUPPORTEDCURRENCY\',\'TSTORESUPPORTEDLOCALE\',\'TSTORETAXJURISDICTION\',\'TTAXCATEGORY\',\'TSTOREASSOCIATION\',\'TSTOREPAYMENTGATEWAY\',\'TPRODUCT\',\'TTAXVALUE\',\'TPRODUCTSKU\',\'TUSERROLE\',\'TUSERROLEPERMISSIONX\',\'TDIGITALASSETS\',\'TTAXJURISDICTION\',\'TCSDYNAMICCONTENT\',\'TCSPARAMETERVALUE\',\'TCSPARAMETERVALUELDF\',\'TPRICELIST\',\'TBASEAMOUNT\',\'TTAXREGION\',\'TPRODUCTATTRIBUTEVALUE\',\'TPRODUCTCATEGORY\',\'TPRODUCTTYPE\',\'TPRODUCTLDF\',\'TPRODUCTTYPESKUOPTION\',\'TPRODUCTSKUOPTIONVALUE\',\'TPRODUCTSKUATTRIBUTEVALUE\',\'TBUNDLECONSTITUENTX\',\'TBRAND\',\'TBUNDLESELECTIONRULE\',\'TATTRIBUTE\',\'TPRODUCTTYPEATTRIBUTE\',\'TCATEGORYLDF\',\'TPRODUCTTYPESKUATTRIBUTE\',\'TWAREHOUSEADDRESS\'\)\" REUSE_DUMPFILES=YES flashback_scn=$SCN content=data_only

# Create DB Link
#sqlplus epadmin@$SOURCE_TNS/tmoweb1234 <<EOF
sqlplus "epadmin/$EXPORT_USER_PASSWORD@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=$SOURCE_END_POINT)(Port=1521))(CONNECT_DATA=(SID=ORCL)))" <<EOF
create database link test_link connect to epadmin identified by $IMPORT_USER_PASSWORD using '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=$TARGET_END_POINT)(PORT=1521))(CONNECT_DATA=(SID=ORCL)))';

create or replace procedure TRANSFER
as	
begin
DBMS_FILE_TRANSFER.PUT_FILE(
   source_directory_object       => 'DATA_PUMP_DIR',
   source_file_name              => 'expdp_test.dmp',
   destination_directory_object  => 'DATA_PUMP_DIR',
   destination_file_name         => 'expdp_test.dmp',
   destination_database          => 'test_link');
end TRANSFER;
/

exec TRANSFER;
drop database link test_link;
EOF

# Disable Constraints
sqlplus "$TARGET_SCHEMA/$TARGET_PASSWORD@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=$TARGET_END_POINT)(Port=1521))(CONNECT_DATA=(SID=ORCL)))" <<EOF
CREATE or replace PROCEDURE DISABLE_C
as
begin
for i in (select constraint_name, table_name from user_constraints) LOOP
execute immediate 'alter table '||i.table_name||' disable constraint '||i.constraint_name||' cascade';
end loop;
end;
/
exec DISABLE_C;
EOF

# Truncate Tables
declare -a arr=("TSHOPPINGITEMDATA" "TORDERITEMDATA" "TCARTORDER" "TCUSTOMER" "TCUSTOMERAUTHENTICATION" "TCUSTOMERDELETED" "TADDRESS" "TPASSWORDHISTORY" "TSHOPPER" "TCUSTOMERGROUPX" "TCUSTOMERSESSION" "TCUSTOMERCREDITCARD" "TORDERADDRESS" "TORDER" "TORDERLOCK" "TORDERSHIPMENT" "TORDERPAYMENT" "TORDERRETURN" "TSHIPMENTTAX" "TORDERSKU" "TORDERRETURNSKU" "TSHOPPINGCART" "TCARTITEM" "TSHOPPINGITEMRECURRINGPRICE" "TAPPLIEDRULECOUPONCODE" "TTOPSELLER" "TTOPSELLERPRODUCTS" "TWISHLIST" "TOAUTHACCESSTOKEN" "TPAYMENTTOKEN" "TCUSTOMERPAYMENTMETHOD" "TORDERDATA" "TTAXJOURNAL" "TCARTORDERCOUPON" "TCARTITEMMODIFIERGROUP" "TPRODTYPECARTITEMMODIFIERGRP" "TCARTITEMMODIFIERGROUPLDF" "TCARTITEMMODIFIERFIELD" "TCARTITEMMODIFIERFIELDLDF" "TCARTITEMMODIFIERFIELDOPTION" "TCARTITEMMODIFIERFIELDOPTIONLDF" "TCREDITCHECKDETAILS" "TCOMPOSITEPAYMENTTOKEN" "TAUDITRECORD" "TE911ADDRESS" "TACCOUNTS" "TFINANCE" "TCUSTOMERPROFILEVALUE" "TORDERAUDIT")
for i in "${arr[@]}"
do
   sqlplus "epadmin/$IMPORT_USER_PASSWORD@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=$TARGET_END_POINT)(Port=1521))(CONNECT_DATA=(SID=ORCL)))" <<EOF
   TRUNCATE TABLE $TARGET_SCHEMA.$i;
EOF
done

#sqlplus epadmin@$TARGET_TNS/$IMPORT_USER_PASSWORD <<EOF
#for t1 IN  (SELECT table_name FROM dba_tables WHERE table_name IN (TSHOPPINGITEMDATA,TORDERITEMDATA,TCARTORDER,TCUSTOMER,TCUSTOMERAUTHENTICATION,TCUSTOMERDELETED,TADDRESS,TPASSWORDHISTORY,TSHOPPER,TCUSTOMERGROUPX,TCUSTOMERSESSION,TCUSTOMERCREDITCARD,TORDERADDRESS,TORDER,TORDERLOCK,TORDERSHIPMENT,TORDERPAYMENT,TORDERRETURN,TSHIPMENTTAX,TORDERSKU,TORDERRETURNSKU,TSHOPPINGCART,TCARTITEM,TSHOPPINGITEMRECURRINGPRICE,TAPPLIEDRULECOUPONCODE,TTOPSELLER,TTOPSELLERPRODUCTS,TWISHLIST,TOAUTHACCESSTOKEN,TPAYMENTTOKEN,TCUSTOMERPAYMENTMETHOD,TORDERDATA,TTAXJOURNAL,TCARTORDERCOUPON,TCARTITEMMODIFIERGROUP,TPRODTYPECARTITEMMODIFIERGRP,TCARTITEMMODIFIERGROUPLDF,TCARTITEMMODIFIERFIELD,TCARTITEMMODIFIERFIELDLDF,TCARTITEMMODIFIERFIELDOPTION,TCARTITEMMODIFIERFIELDOPTIONLDF,TCREDITCHECKDETAILS,TCOMPOSITEPAYMENTTOKEN,TAUDITRECORD,TE911ADDRESS,TACCOUNTS,TFINANCE,TCUSTOMERPROFILEVALUE,TORDERAUDIT)) LOOP
#      EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || $TARGET_SCHEMA.t1.table_name;
#   END LOOP;
#EOF
# Data pump Import
impdp userid=epadmin/$IMPORT_USER_PASSWORD@\"\(DESCRIPTION=\(ADDRESS=\(PROTOCOL=TCP\)\(Host=$TARGET_END_POINT\) \(Port=1521\)\)\(CONNECT_DATA=\(SID=ORCL\)\)\)\" directory=DATA_PUMP_DIR dumpfile=expdp_test.dmp logfile=impdp_test.log remap_schema=$SOURCE_SCHEMA:$TARGET_SCHEMA content=data_only table_exists_action=truncate remap_tablespace=$SOURCE_TABLESPACE:$TARGET_TABLESPACE

#Enable Constraints
sqlplus "$TARGET_SCHEMA/$TARGET_PASSWORD@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=$TARGET_END_POINT)(Port=1521))(CONNECT_DATA=(SID=ORCL)))" <<EOF
CREATE or replace PROCEDURE ENABLE_U
as
begin
for i in (select constraint_name, table_name from user_constraints where CONSTRAINT_TYPE != 'R') LOOP
execute immediate 'alter table '||i.table_name||' enable constraint '||i.constraint_name||'';
end loop;
end;
/
exec ENABLE_U;
CREATE or replace PROCEDURE ENABLE_R
as
begin
for i in (select constraint_name, table_name from user_constraints where status='DISABLED') LOOP
execute immediate 'alter table '||i.table_name||' enable constraint '||i.constraint_name||'';
end loop;
end;
/
exec ENABLE_R;
EOF
