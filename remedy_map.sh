#!/bin/bash


###############################################
# Load Oracle Environment (cron-safe)
###############################################
# Oracle Instant Client paths
export ORACLE_HOME=/hpfms/app/erm
export PATH=$ORACLE_HOME/lib/instantclient:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib/instantclient:$LD_LIBRARY_PATH


# Output file
CSV_FILE="site_mapping_$(date +%Y%m%d_%H%M%S).csv"

# Run SQLPlus
sqlplus -s FMS_SYSADM/Abcd1234#@ods_gss_ro.dceg.vodafone.com.eg:1521/ods_fms <<END

-- CSV settings
SET MARKUP CSV ON DELIMITER , QUOTE ON
SET FEEDBACK OFF
SET PAGESIZE 0
SET TRIMOUT ON
SET TRIMSPOOL ON
SET LINESIZE 5000
SET VERIFY OFF
SET ECHO OFF
SET WRAP OFF

SPOOL $CSV_FILE

SELECT
    SITE_ID,
    MINOR_AREA,
    CITY,
    REPLACE(REPLACE(REPLACE(LANDLORD_ADDRESS, ',', '_'), CHR(10), ' | '), CHR(13), ' | ') AS LANDLORD_ADDRESS,
    '  N '|| LATITUDE ||'  E '|| LONGITUDE AS COORDINATES
FROM ARADMIN.GSM_ROLLOUT_SCREEN
WHERE OPTION_STATUS = '0';

SPOOL OFF
EXIT
END

echo "CSV file generated: $CSV_FILE"
