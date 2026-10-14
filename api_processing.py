#!/usr/bin/env python2.7
# -*- coding: utf-8 -*-

import sys, csv, requests
from datetime import datetime

def log(msg, log_file):
    ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    with open(log_file, "a") as f:
        f.write("%s - %s\n" % (ts, msg))

def hex_to_dec(v):
    return int(v, 16)

def main(msisdn_api, values_file, mapper_csv, log_file):

    log("Starting API processing for %s" % msisdn_api, log_file)

    # Fetch API data
    # Fetch API data
    url = "http://10.230.67.75:1522/legacy-portal/current-location/?msisdn_list=%s" % msisdn_api
    try:
        response = requests.get(url, timeout=1500)

        # Log status code
        log("API status code: %s for %s" % (response.status_code, msisdn_api), log_file)

        # Log limited response to avoid huge logs (first 1000 chars)
        log("API response (truncated) for MSISDN %s: %s" % (msisdn_api, response.text[:1000]),log_file)

        # Parse JSON
        data = response.json()

    except Exception as e:
        log("API request failed for MSISDN %s: %s" % (msisdn_api, e), log_file)
        sys.exit(1)

    records = data.get("data", [])
    if not records:
        log("No records returned for %s" % msisdn_api, log_file)
        sys.exit(2)

    # Load mapper CSV
    mapper = {}
    with open(mapper_csv) as f:
        reader = csv.reader(f)
        for m in reader:
            if len(m) >= 8:
                mapper[(m[6], m[7])] = m[2]

    # Prepare to write rows
    rows = []

    for rec in records:
        cell = rec.get("cell", "")
        ctype = rec.get("type", "")
        imsi = rec.get("imsi", "")
        imei = rec.get("imei", "")
        mobile_stat = rec.get("Mobile_Stat", "")
        proc_time = rec.get("proc_starttime", "").replace(" ", "_")

        cid_hex = ""
        cid_dec = ""
        lac_dec = ""
        site_id = ""

        if ctype == "EPC":
            # For EPC, remove first 5 chars, everything else is CID
            cid_hex = cell[5:]
            try:
                cid_dec = str(hex_to_dec(cid_hex))
            except:
                cid_dec = ""
            # Find SITE_ID and LAC from mapper using CID
            for (lac, cid), site in mapper.items():
                if cid == cid_dec:
                    site_id = site
                    lac_dec = lac
                    break
        else:
            # For 2/3G, remove first 5 chars, split LAC and CID  2C75 = 11381 B67B = 46715
            hex_part = cell[5:]
            lac_hex = hex_part[:4]
            cid_hex = hex_part[4:8]
            try:
                lac_dec = str(hex_to_dec(lac_hex))
            except:
                lac_dec = ""
            try:
                cid_dec = str(hex_to_dec(cid_hex))
            except:
                cid_dec = ""
            site_id = mapper.get((lac_dec, cid_dec), "")

        if site_id:
            # Each API record becomes one row in the file
            rows.append([site_id, cid_hex, cid_dec, lac_dec, ctype, imsi, imei, proc_time, mobile_stat])

    if not rows:
        log("No valid SITE_ID mapping found for %s" % msisdn_api, log_file)
        sys.exit(3)

    # Write all rows to values_file, one line per record
    with open(values_file, "w") as f:
        for row in rows:
            f.write(",".join(row) + "\n")

    # Print all SITE_IDs as comma-separated list for Bash
    site_ids = [r[0] for r in rows]
    print(",".join(site_ids))

    log("Processed %d records for %s" % (len(rows), msisdn_api), log_file)


if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: api_processing.py <msisdn> <values_file> <mapper_csv> <log_file>")
        sys.exit(1)

    main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])