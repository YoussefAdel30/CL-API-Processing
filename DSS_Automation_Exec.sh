#!/bin/bash

# Developed by: Abdullah Mahmoud (IbrahimA67)
# FMS & RA Developer
# Vodafone Egypt
# DSS Automation Script

# Variables
Default_Path="/hpfms/app/scripts/utilities/DSS_Automation"
Repository="$Default_Path/Repository"
Archive="$Default_Path/Archive"
SQL_OUTPUT_DIR="$Default_Path/SQL_OUTPUT_DIR"
TEMP_DIR="$Default_Path/temp"
WHITELIST_FILE="$Default_Path/Whitelist_users/output/WhiteUsers.csv"
dtime=$(date +"%Y%m%d%H%M%S")
v_hostname=$(hostname)
##unhash when failover to COL2
##source /opt/rh/python27/enable

# Lock file to prevent overlapping runs
LOCK_FILE="/tmp/DSS_Automation.lock"
if [ -e "$LOCK_FILE" ]; then
    echo "Script is already running. Exiting."
    exit 1
else
    touch "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"' EXIT
fi

# Logging function
log() {
    local log_file="$Default_Path/logs/DSS_Automation_${dtime}.log"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$log_file"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# Function to send email
send_email() {
    local from="${v_hostname}@vodafone.com"  # Use a valid email address
    local bcc="omar.salah@vodafone.com.eg,yasmin.wanas@vodafone.com.eg,mohamed.abdelrehim@vodafone.com.eg,youssef.adel@vodafone.com.eg"
    local subject="$1"
    local body="$2"
    local email="$3"
    local attachment="$4"
    local cc="$5"  # New CC parameter

    echo "$body" | mailx -v \
        -s "$subject" \
        -S smtp="10.230.30.32:25" \
        -r "$from" \
        -b "$bcc" \
        ${cc:+-c "$cc"} \
        ${attachment:+-a "$attachment"} \
        "$email"
}


# Function to check if a number is whitelisted
is_whitelisted() {
    local number="$1"
    local column="$2"
    
    if [[ "$column" == "1" ]]; then
        awk -F, '{print $1}' "$WHITELIST_FILE" | grep -Fx "${number}"
    elif [[ "$column" == "2" ]]; then
        awk -F, '{print $2}' "$WHITELIST_FILE" | grep -Fx "${number}"
	elif [[ "$column" == "3" ]]; then
        awk -F, '{print $3}' "$WHITELIST_FILE" | grep -Fx "${number}"
	elif [[ "$column" == "4" ]]; then
        awk -F, '{print $4}' "$WHITELIST_FILE" | grep -Fx "${number:0:14}"
    fi
}

# Function to process a single request
process_request() {
    local line="$1"
	local file="$2"  # Pass the file name to the function

    IFS=',' read -r Requester_name mobile_number function locations timestamp email Req_ID <<< "$line"
	
    # Extract function name and days
    function_name=$(echo "$function" | cut -d'_' -f1)
    Days=$(echo "$function" | cut -d'_' -f2)
    history=$(echo "$timestamp" | cut -d'T' -f1)
    hour=$(echo "$timestamp" | cut -d'T' -f2)
    Requester_ID=$(echo -n "$Req_ID" | tr -cd '[:print:]' | tr -d '[:space:]')
	location=$(echo -n "$locations" | tr -cd '[:print:]' | tr -d '[:space:]')
	mobile_no=$(echo -n "$mobile_number" | tr -cd '[:print:]' | tr -d '[:space:]')
    valid_functions=("MLU" "LU" "SITELU" "SITELEGAL" "CLU" "CALLS" "BCALLS" "INFO" "IMEI" "MTI" "SIM" "ID" "CASH" "VISIT" "CL","CASHB","CRD","CRD2","CONN")
    WhitelistMobile=("MLU" "LU" "CLU" "CALLS" "BCALLS" "INFO" "MTI" "CASH" "VISIT" "CL","CASHB","CRD","CRD2","CONN")

    # Whitelist check based on function type
    if [[ " ${WhitelistMobile[@]} " =~ " $function_name " ]] && [[ -n "$(is_whitelisted "$mobile_no" "1")" ]]; then
        log "Employee query attempt for mobile number: ${mobile_no} for File: ${file}"
 			
		subject="$Requester_name | Employee Query"
        body="not authorized to query mobile number: ${mobile_no}."
		cc="datadisclosureteam@vodafone.com.eg"
        send_email "$subject" "$body" "$email" "" "$cc"
        ##return
    elif [ "$function_name" == "ID" ] && [[ -n "$(is_whitelisted "$mobile_no" "2")" ]]; then
        log "Employee query attempt for National ID: ${mobile_no} for File: ${file}"
        subject="$Requester_name | Employee Query"
        body="not authorized to query mobile number: ${mobile_no}."
		cc="datadisclosureteam@vodafone.com.eg"
        send_email "$subject" "$body" "$email" "" "$cc"
        ##return
	elif [ "$function_name" == "SIM" ] && [[ -n "$(is_whitelisted "$mobile_no" "3")" ]]; then
        log "Employee query attempt for SIM: ${mobile_no} for File: ${file}"
        subject="$Requester_name | Employee Query"
        body="not authorized to query SIM: ${mobile_no}."
		cc="datadisclosureteam@vodafone.com.eg"
        send_email "$subject" "$body" "$email" "" "$cc"
        ##return
	elif [ "$function_name" == "IMEI" ] && [[ -n "$(is_whitelisted "$mobile_no" "4")" ]]; then
        log "Employee query attempt for IMEI: ${mobile_no} for File: ${file}"
        subject="$Requester_name | Employee Query"
        body="not authorized to query IMEI: ${mobile_no}."
		cc="datadisclosureteam@vodafone.com.eg"
        send_email "$subject" "$body" "$email" "" "$cc"
        ##return
    fi

    # Validate function and input length
    if [ "$function_name" == "VISIT" ]; then
        log "Extracting the VISIT function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/DWH_Queries/Visit_query.sh "$mobile_no" "$Days" "$location" "$history" "$hour"
        log "Ending extracting the VISIT function on ${mobile_no} on ${timestamp} for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/VISIT_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/VISIT_${mobile_no}_${Days}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: VISIT_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: VISIT_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#------------------------------------------------------------------------------------------
    elif [ "$function_name" == "CASH" ] && [ "${#mobile_no}" -eq 11 ]; then
        log "Extracting the CASH function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/DWH_Queries/Cash_query.sh "$mobile_no" "$Days" "$location" "$history" "$hour"
        log "Ending extracting the CASH function on ${mobile_no} on ${timestamp} for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/CASH_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/CASH_${mobile_no}_${Days}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: CASH_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: CASH_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#------------------------------------------------------------------------------------------
    elif [ "$function_name" == "ID" ] && [ "${#mobile_no}" -le 14 ]; then
        log "Extracting the ID function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/DWH_Queries/ID_query.sh "$mobile_no" "$location" "$history" "$hour"
        log "Ending extracting the ID function on ${mobile_no} on ${timestamp} for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/ID_${mobile_no}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/ID_${mobile_no}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: ID_${mobile_no}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: ID_${mobile_no}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file} for File: ${file}"
        fi
#------------------------------------------------------------------------------------------------
    elif [ "$function_name" == "SIM" ] && [ "${#mobile_no}" -gt 18 ]; then
        log "Extracting the SIM function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/DWH_Queries/Sim_query.sh "$mobile_no" "$location" "$history" "$hour"
        log "Ending extracting the SIM function on ${mobile_no} on ${timestamp} for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/SIM_${mobile_no}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/SIM_${mobile_no}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: SIM_${mobile_no}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: SIM_${mobile_no}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#--------------------------------------------------------------------------------------------------		
    elif [ "$function_name" == "MTI" ] && [ "${#mobile_no}" -eq 11 ]; then
        log "Extracting the MTI function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/DWH_Queries/MTI_query.sh "$mobile_no" "$location" "$history" "$hour"
        log "Ending extracting the MTI function on ${mobile_no} on ${timestamp} for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/MTI_${mobile_no}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/MTI_${mobile_no}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: MTI_${mobile_no}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: MTI_${mobile_no}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#--------------------------------------------------------------------------------------------------
    elif [ "$function_name" == "IMEI" ] && [ "${#mobile_no}" -gt 13 ]; then
        log "Extracting the IMEI function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/DWH_Queries/IMEI_query.sh "$mobile_no" "$Days" "$location" "$history" "$hour"
        log "Ending extracting the IMEI function on ${mobile_no} on ${timestamp} for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/IMEI_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/IMEI_${mobile_no}_${Days}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: IMEI_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: IMEI_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#--------------------------------------------------------------------------------------------------
    elif [ "$function_name" == "INFO" ] && [ "${#mobile_no}" -eq 11 ]; then
        log "Extracting the INFO function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/DWH_Queries/INFO_query.sh "$mobile_no" "$location" "$history" "$hour"
        log "Ending extracting the INFO function on ${mobile_no} on ${timestamp} for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/INFO_${mobile_no}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/INFO_${mobile_no}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: INFO_${mobile_no}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: INFO_${mobile_no}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#--------------------------------------------------------------------------------------------------
    elif [ "$function_name" == "CASHB" ] && [ "${#mobile_no}" -eq 11 ]; then
        log "Extracting the CASHB function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/DWH_Queries/CashB_query.sh "$mobile_no" "$location" "$history" "$hour"
        log "Ending extracting the CASHB function on ${mobile_no} on ${timestamp} for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/CASHB_${mobile_no}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/CASHB_${mobile_no}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: CASHB_${mobile_no}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: CASHB_${mobile_no}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#--------------------------------------------------------------------------------------------------	
    elif [ "$function_name" == "CRD" ] && [ "${#mobile_no}" -eq 11 ]; then
        log "Extracting the CRD function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/DWH_Queries/CRD_query.sh "$mobile_no" "$Days" "$location" "$history" "$hour"
        log "Ending extracting the CRD function on ${mobile_no} on ${timestamp} for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/CRD_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/CRD_${mobile_no}_${Days}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: CRD_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: CRD_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#--------------------------------------------------------------------------------------------------	
	elif [ "$function_name" == "CRD2" ]; then
        log "Extracting the CRD2 function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/DWH_Queries/CRD2_query.sh "$mobile_no" "$location" "$history" "$hour"
        log "Ending extracting the CRD2 function on ${mobile_no} on ${timestamp} for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/CRD2_${mobile_no}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/CRD2_${mobile_no}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: CRD2_${mobile_no}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: CRD2_${mobile_no}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#--------------------------------------------------------------------------------------------------	
	elif [ "$function_name" == "CONN" ]; then
        log "Extracting the CONN function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/DWH_Queries/Conn_query.sh "$mobile_no" "$Days" "$location" "$history" "$hour"
        log "Ending extracting the CONN function on ${mobile_no} on ${timestamp} for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/CONN_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/CONN_${mobile_no}_${Days}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: CONN${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: CONN${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#--------------------------------------------------------------------------------------------------	
    elif [ "$function_name" == "BCALLS" ] && [ "${#mobile_no}" -eq 11 ]; then
        log "Extracting the BCALL function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/DWH_Queries/BCALL_query.sh "$mobile_no" "$Days" "$location" "$history" "$hour"
        log "Ending extracting the BCALL function on $mobile_no on $timestamp for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/BCALL_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/BCALL_${mobile_no}_${Days}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: BCALL_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: BCALL_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#--------------------------------------------------------------------------------------------------
    elif [ "$function_name" == "CALLS" ] && [ "${#mobile_no}" -eq 11 ]; then
        log "Extracting the CALL function on $mobile_no on ${timestamp} for File: ${file}"
        $Default_Path/DWH_Queries/CALL_query.sh "$mobile_no" "$Days" "$location" "$history" "$hour"
        log "Ending extracting the CALL function on ${mobile_no} on ${timestamp} for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/CALL_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/CALL_${mobile_no}_${Days}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: CALL_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: CALL_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}" 
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#--------------------------------------------------------------------------------------------------
    elif [ "$function_name" == "CLU" ] && [ "${#mobile_no}" -eq 11 ]; then
        log "Extracting the CLU function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/NBL_Queries/CLU_query.sh "$mobile_no" "$location" "$history" "$hour"
        log "Ending extracting the CLU function on $mobile_no on $timestamp for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/CLU_${mobile_no}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/CLU_${mobile_no}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: CLU_${mobile_no}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: CLU_${mobile_no}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#--------------------------------------------------------------------------------------------------
    elif [ "$function_name" == "SITELU" ]; then
        log "Extracting the SITELU function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/NBL_Queries/SITELU_query.csh "$mobile_no" "$Days" "$location" "$history" "$hour"
        log "Ending extracting the SITELU function on $mobile_no on $timestamp for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/SITELU_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/SITELU_${mobile_no}_${Days}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: SITELU_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: SITELU_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#--------------------------------------------------------------------------------------------------
    elif [ "$function_name" == "SITELEGAL" ]; then
        log "Extracting the SITELEGAL function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/DWH_Queries/SITELEGAL_query.sh "$mobile_no" "$Days" "$location" "$history" "$hour"
        log "Ending extracting the SITELEGAL function on $mobile_no on $timestamp for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/SITELEGAL_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/SITELEGAL_${mobile_no}_${Days}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: SITELEGAL_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: SITELEGAL_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi			
#--------------------------------------------------------------------------------------------------
    elif [ "$function_name" == "LU" ] && [ "${#mobile_no}" -eq 11 ]; then
        log "Extracting the LU function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/NBL_Queries/LU_query.sh "$mobile_no" "$Days" "$location" "$history" "$hour"
        log "Ending extracting the LU function on $mobile_no on $timestamp for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/LU_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/LU_${mobile_no}_${Days}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: LU_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: LU_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#--------------------------------------------------------------------------------------------------
    elif [ "$function_name" == "MLU" ] && [ "${#mobile_no}" -eq 11 ]; then
        log "Extracting the MLU function on ${mobile_no} on ${timestamp} for File: ${file}"
        $Default_Path/NBL_Queries/MLU_query.sh "$mobile_no" "$Days" "$location" "$history" "$hour"
        log "Ending extracting the MLU function on $mobile_no on $timestamp for File: ${file}"
        output_file_xlsx="$SQL_OUTPUT_DIR/MLU_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX"
        output_file_csv="$SQL_OUTPUT_DIR/MLU_${mobile_no}_${Days}_${location}_${history}_${hour}.csv"
        if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
            log "Query output generated: MLU_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX for File: ${file}"
            temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
            mkdir -p "$temp_dir"
            mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
            log "move the output generated: MLU_${mobile_no}_${Days}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
        else
            subject="$function_name | $location | No Data Found"
            body="No data retrieved for input: $mobile_no"
            send_email "$subject" "$body" "$email"
            log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
        fi
#--------------------------------------------------------------------------------------------------
    elif [ "$function_name" == "CL" ] && [ "${#mobile_no}" -eq 11 ]; then

		msisdn_api="${mobile_no: -10}"
		timestamp=$(date +"%Y-%m-%dT%H:%M:%S")

		log "Executing NEW CL API request for ${msisdn_api} at ${timestamp} for File: ${file}"

		values_dir="$Default_Path/Remedy_Query/values_repo"
		mkdir -p "$values_dir"

		values_file="${values_dir}/dss_auto_cl_values_${msisdn_api}_$$.txt"
		log_file="$Default_Path/Remedy_Query/dss_auto_python.log"
		mapper_csv="/hpfms/app/scripts/utilities/DSS_Automation/Remedy_Query/cell_mapper.csv"

		# Run Python script
		site_ids=$($Default_Path/Remedy_Query/api_processing.py \
			"$msisdn_api" "$values_file" "$mapper_csv" "$log_file")

		log "Site IDs returned by Python: ${site_ids}"

		if [ -z "$site_ids" ]; then
			log "processing failed or no SITE IDs returned for MSISDN $msisdn_api"
			subject="$function_name | $location | No Data Found"
			body="processing failed or no SITE IDs returned for MSISDN $mobile_no"
			send_email "$subject" "$body" "$email"

			# CLEANUP (IMPORTANT)
			rm -f "$values_file"

			return
		fi

		# ---------------------------------------------------
		# Aggregate multiple API records into comma lists
		# ---------------------------------------------------

		# Initialize aggregates
		SITE_IDS=""
		PROC_TIMES=""
		CID_HEXS=""
		CID_DECS=""
		LAC_DECS=""
		TYPES=""
		IMSI_OSS=""
		IMEI_OSS=""
		first_site=""
		MOBILE_STATS=""

		# Read CSV rows line by line
		while IFS=',' read -r SITE_ID CID_HEX CID_DEC LAC_DEC TYPE IMSI IMEI PROC_TIME MOBILE_STAT
		do
			IMSI_OSS="$IMSI"
			IMEI_OSS="$IMEI"

			if [ -z "$first_site" ]; then
				first_site="$SITE_ID"
			fi

			SITE_IDS="${SITE_IDS},${SITE_ID}"
			PROC_TIMES="${PROC_TIMES},${PROC_TIME}"
			CID_HEXS="${CID_HEXS},${CID_HEX}"
			CID_DECS="${CID_DECS},${CID_DEC}"
			LAC_DECS="${LAC_DECS},${LAC_DEC}"
			TYPES="${TYPES},${TYPE}"
			MOBILE_STATS="${MOBILE_STATS},${MOBILE_STAT}"

		done < "$values_file"

		# Remove leading commas
		SITE_IDS=${SITE_IDS#,}
		PROC_TIMES=${PROC_TIMES#,}
		CID_HEXS=${CID_HEXS#,}
		CID_DECS=${CID_DECS#,}
		LAC_DECS=${LAC_DECS#,}
		TYPES=${TYPES#,}
		MOBILE_STATS=${MOBILE_STATS#,}
		

		echo "Aggregated SITE_IDS: $SITE_IDS"
		echo "Aggregated PROC_TIMES: $PROC_TIMES"
		echo "Aggregated CID_HEXS: $CID_HEXS"
		echo "Aggregated CID_DECS: $CID_DECS"
		echo "Aggregated LAC_DECS: $LAC_DECS"
		echo "Aggregated TYPES: $TYPES"


		# Other values
		MSISDN_OSS="$msisdn_api"
		TS_OSS="$PROC_TIMES"
		CellNo_OSS="$CID_HEXS"
		CellID_OSS="$CID_DECS"
		LAC_OSS="$LAC_DECS"
		Status4g_OSS="$TYPES"
		MME_OSS=""
		Mobile_state_OSS="$MOBILE_STATS"

		log "Executing CL query for $mobile_no at $timestamp for File: $file"

		$Default_Path/Remedy_Query/CL_query.sh \
			"$SITE_IDS" "$location" "$history" "$hour" \
			"$MSISDN_OSS" "$IMSI_OSS" "$IMEI_OSS" \
			"$TS_OSS" "$CellID_OSS" "$CellNo_OSS" \
			"$LAC_OSS" "$Status4g_OSS" "$MME_OSS" "$Mobile_state_OSS" "$first_site"

		log "Ending extraction of the CL function on $mobile_no at $timestamp for File: $file"

		output_file_xlsx="$SQL_OUTPUT_DIR/CL_${first_site}_${location}_${history}_${hour}.XLSX"
		output_file_csv="$SQL_OUTPUT_DIR/CL_${first_site}_${location}_${history}_${hour}.csv"

		if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then

			log "Query output generated: CL_${first_site}_${location}_${history}_${hour}.XLSX for File: $file"

			temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
			mkdir -p "$temp_dir"

			mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
			rm -f "$values_file"

			log "Moved output to $Requester_ID/${function_name}_${location}_${email} as ${mobile_no}.XLSX for File: $file"

		else

			subject="$function_name | $location | No Data Found"
			body="No data retrieved for input: $mobile_no"
			rm -f "$values_file"

			send_email "$subject" "$body" "$email"

			log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"

		fi
#--------------------------------------------------------------------------------------------------
    else
        if [[ ! " ${valid_functions[@]} " =~ " $function_name " ]]; then
            log "Invalid function: ${function_name} for ${mobile_no} for File: ${file}"
            subject="$Requester_name | Invalid function"
            body="Please check your request. You inserted an invalid function: ${function_name}."
            send_email "$subject" "$body" "$email"
        else
            log "Invalid Inquiry Number: ${mobile_no}, Length: ${#mobile_no} for File: ${file}"
            subject="$Requester_name | Invalid Inquiry Number"
            body="Please check your request. You inserted an invalid Inquiry Number: ${mobile_no}, Length: ${#mobile_no} for Function: ${function_name}."
            send_email "$subject" "$body" "$email"
        fi
    fi
}
#export -f process_request log send_email is_whitelisted
#export Default_Path Repository Archive SQL_OUTPUT_DIR TEMP_DIR WHITELIST_FILE dtime v_hostname

# Function to process a single file
process_file() {
    local file="$1"
    log "Processing file: ${file}"

    # Create a temp subfolder for this file only
    TEMP_SUB_DIR="$TEMP_DIR/${file}"
    mkdir -p "$TEMP_SUB_DIR"

    log "----First executing the script based on function name For File:${file}----"
    # Process each line in the file using xargs, passing subfolder path too
    cat "$file" | xargs -I{} -P 5 bash -c 'TEMP_SUB_DIR="'"$TEMP_SUB_DIR"'"; process_request "{}" "$0"' "$file"

    log "-------second step merge the output in multi-sheet For File: ${file} -----"
    # Loop through only this file's TEMP subfolder
    for requester_dir in "$TEMP_SUB_DIR"/*; do
        for function_dir in "$requester_dir"/*; do
            if [ -d "$function_dir" ]; then
                Merge_loc_func_email=$(basename "$function_dir")
                msisdn="$(cut -d ',' -f2 ${Repository}/${file} | head -1)"
                emails="$(echo "$Merge_loc_func_email" | cut -d'_' -f3)"
                FUNCTION_N="$(echo "$Merge_loc_func_email" | cut -d'_' -f1)"
                location_sub="$(echo "$Merge_loc_func_email" | cut -d'_' -f2)"
                output_XLSX="$SQL_OUTPUT_DIR/${FUNCTION_N}_${msisdn}.xlsx"

                log "Executing Python script to generate new xlsx called ${FUNCTION_N}_${msisdn}.xlsx to add multi-sheet"
                # Call Python script to generate Excel file
                python - <<EOF >> /tmp/dss_auto_python.log 2>&1
# -*- coding: utf-8 -*-
import os
from openpyxl import load_workbook, Workbook
from openpyxl.utils import get_column_letter  # Added missing import

input_folder = "$function_dir"
output_file = "$output_XLSX"
print("Python started. Input folder:", "$function_dir")
print("Output file:", "$output_XLSX")

# Create a new workbook
new_wb = Workbook()
new_wb.remove(new_wb.active)  # Remove the default blank sheet

def copy_sheet(source_ws, target_ws):
    """Enhanced copy function that preserves column widths and formatting"""
    # Copy cell values
    for row in source_ws.iter_rows():
        for cell in row:
            if cell.value is not None:
                target_cell = target_ws.cell(row=cell.row, column=cell.col_idx, value=cell.value)
                
                # Copy formatting if needed
                if cell.has_style:
                    target_cell.font = cell.font.copy()
                    target_cell.border = cell.border.copy()
                    target_cell.fill = cell.fill.copy()
                    target_cell.number_format = cell.number_format
                    target_cell.protection = cell.protection.copy()
                    target_cell.alignment = cell.alignment.copy()
    
    # Copy column dimensions
    for col in range(1, source_ws.max_column + 1):
        col_letter = get_column_letter(col)
        target_ws.column_dimensions[col_letter].width = source_ws.column_dimensions[col_letter].width

# Iterate over all XLSX files in the folder
for file in sorted(os.listdir(input_folder)):
    if file.endswith(".XLSX") or file.endswith(".xlsx"):
        file_path = os.path.join(input_folder, file)
        wb = load_workbook(file_path)

        # Use the filename as the sheet name (without extension)
        sheet_title = os.path.splitext(file)[0]

        # Ensure unique sheet names
        count = 1
        while sheet_title in new_wb.sheetnames:
            sheet_title = "{}_{}".format(os.path.splitext(file)[0], count)
            count += 1

        target_ws = new_wb.create_sheet(title=sheet_title)

        # Copy content from the first sheet (assuming only one sheet per file)
        source_ws = wb.active
        copy_sheet(source_ws, target_ws)

# Save merged file
print("Saving merged workbook...")
new_wb.save(output_file)
print("Merge complete:", output_file)

# Open (or create) a file named "output.txt" in write mode

f = open("/hpfms/app/scripts/utilities/DSS_Automation/TESSTTT.txt", "w")
 
# Write text into the file

f.write("After merging the excel $output_XLSX.\n")
 
# Always close the file to save changes

f.close()
EOF

                subject="$location_sub | $FUNCTION_N"
                log "The subject generated is ${subject}"
                body="Please find attached the required report generation."
                send_email "$subject" "$body" "$emails" "$output_XLSX"
                log "Email sent to $emails with ${FUNCTION_N}_${msisdn}.xlsx"

                # Clean up function_dir
                rm -rf "$function_dir"
                log "function_dir Removed: $function_dir"
            fi
        done
        rm -rf "$requester_dir"
        log "requester_dir Removed: $requester_dir"
    done

    # Clean up only this file's TEMP subfolder
    rm -rf "$TEMP_SUB_DIR"
    log "TEMP_SUB_DIR Removed: $TEMP_SUB_DIR"

    # Move processed file to Archive
    mv "$Repository/$file" "$Archive"
    log "File archived: $(basename "$file")"
}


# Export all required functions and variables
export -f process_request log send_email is_whitelisted process_file
export Default_Path Repository Archive SQL_OUTPUT_DIR TEMP_SUB_DIR TEMP_DIR WHITELIST_FILE dtime v_hostname

# Main execution
mkdir -p "$TEMP_DIR"
cd "$Repository" || exit

max_jobs=10
processed_files=()

process_new_file() {
    local file="$1"
    log "Starting processing: $file"
    process_file "$file" &
    processed_files+=("$file")
}

while true; do
    # Find all DSS files not yet processed
    while IFS= read -r -d $'\0' file; do
        file=$(basename "$file")
        
        # Skip if already processed
        if printf '%s\n' "${processed_files[@]}" | grep -Fxq "$file"; then
            continue
        fi
        
        # Wait for an available slot
        while [ "$(jobs -r | wc -l)" -ge "$max_jobs" ]; do
            sleep 1
        done
        
        process_new_file "$file"
        
    done < <(find . -maxdepth 1 -name "DSS*" -print0)
    
    # Exit if no more files and no jobs running
    if [ "$(jobs -r | wc -l)" -eq 0 ] && [ "${#processed_files[@]}" -gt 0 ]; then
        break
    fi
    
    sleep 5  # Check for new files every 5 seconds
done

# Final cleanup
wait
rm -rf "$TEMP_DIR"




# ## CL Backup
# elif [ "$function_name" == "CL" ] && [ "${#mobile_no}" -eq 11 ]; then
        # log "Executing the OSS script on ${mobile_no} on ${timestamp} for File: ${file}"
        # $Default_Path/OSS_dir/OSS_Exec.sh "$mobile_no"
		# output_file_path="$Default_Path/OSS_dir/output/2${mobile_no}.txt"
		# # Step 7: Completion message
		# if [ -f "$output_file_path" ]; then
			# log "Output file successfully transferred to $output_file_path"
		# else
			# log "Failed to transfer output file. Please check manually."
		# fi
        # if [ -f "$output_file_path" ] && ! grep -iq 'is not registered' "$output_file_path"; then
            # log "The provided MSISDN: ${mobile_no} is registered on the network for File: ${file}"
            
            # # Extract values from the output of OSS script
            # site_id=$(grep -i 'Covering site' "$output_file_path" | awk -F": " '{print $2}' | head -1)
            # MSISDN_OSS=$(grep -i 'MSISDN' "$output_file_path" | awk -F": " '{print $2}' | head -1)
            # IMSI_OSS=$(grep -i 'IMSI' "$output_file_path" | awk -F": " '{print $2}' | head -1)
            # IMEI_OSS=$(grep -i 'IMEI' "$output_file_path" | awk -F": " '{print $2}' | head -1)
            # Covering_Switch_OSS=$(grep -i 'Covering Switch' "$output_file_path" | awk -F": " '{print $2}' | head -1)
            # CellID_OSS=$(grep -i 'Cell ID' "$output_file_path" | awk -F": " '{print $2}' | head -1)
            # CellNo_OSS=$(grep -i 'Cell Number' "$output_file_path" | awk -F": " '{print $2}' | head -1)
            # LAC_OSS=$(grep -i 'LAC' "$output_file_path" | awk -F": " '{print $2}' | head -1)
            # Status4g_OSS=$(grep -i '4G Status' "$output_file_path" | awk -F": " '{print $2}' | head -1)
            # MME_OSS=$(grep -i 'MME' "$output_file_path" | awk -F": " '{print $2}' | head -1)
            # Mobile_state_OSS=$(grep -i 'Mobile state' "$output_file_path" | awk -F": " '{print $2}' | head -1)
            
            # log "Extracting the CL function on ${mobile_no} at ${timestamp} for File: ${file}"
            # $Default_Path/Remedy_Query/CL_query.sh "$site_id" "$location" "$history" "$hour" "$MSISDN_OSS" "$IMSI_OSS" "$IMEI_OSS" "$Covering_Switch_OSS" "$CellID_OSS" "$CellNo_OSS" "$LAC_OSS" "$Status4g_OSS" "$MME_OSS" "$Mobile_state_OSS"
            # log "Ending extraction of the CL function on $mobile_no at $timestamp for File: ${file}"
	
            # output_file_xlsx="$SQL_OUTPUT_DIR/CL_${site_id}_${location}_${history}_${hour}.XLSX"
            # output_file_csv="$SQL_OUTPUT_DIR/CL_${site_id}_${location}_${history}_${hour}.csv"
            # if [ -f "$output_file_xlsx" ] && [ -s "$output_file_csv" ]; then
                # log "Query output generated: CL_${site_id}_${location}_${history}_${hour}.XLSX for File: ${file}"
                # temp_dir="$TEMP_SUB_DIR/$Requester_ID/${function_name}_${location}_${email}"
                # mkdir -p "$temp_dir"
                # mv "$output_file_xlsx" "$temp_dir/${mobile_no}.XLSX"
                # log "move the output generated: CL_${site_id}_${location}_${history}_${hour}.XLSX to $Requester_ID/${function_name}_${location}_${email} with new name called ${mobile_no}.XLSX for File: ${file}"
            # else
                # subject="$function_name | $location | No Data Found"
                # body="No data retrieved for input: $mobile_no"
                # send_email "$subject" "$body" "$email"
                # log "No data found: ${mobile_no} in function: ${function_name} for File: ${file}"
            # fi
        # else
            # subject="$function_name | $location | Not Registered to Network"
            # body="The provided MSISDN: ${mobile_no} is NOT registered on the network."
            # send_email "$subject" "$body" "$email"
			# log "Not Registered to Network: ${mobile_no} in function: ${function_name} for File: ${file}"
        # fi		
