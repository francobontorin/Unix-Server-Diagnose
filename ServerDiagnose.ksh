#!/bin/ksh
################################################################################
#
# Documentation
# ==============================================================================
# This script is used to diagnose the Unix, generating a 
# compliance report
# ==============================================================================
#
# Version Control
# ==============================================================================
#	Ver 1.0.2 - Created by Franco Bontorin / Unix Technical Services
#			  - Date: Feb 2013
################################################################################


##########################
# VARIABLE DECLARATION   #
##########################

PLATFORM=$(uname)
OS_VERSION=$(uname -r)
HOSTNAME=$(uname -n)
ENVIRONMENT=$(uname -n | cut -c 4-7)
LOG_FILE=/tmp/UTS-ServerDiagnose-$(date +'%d.%b.%Y-%I.%M%p').report
NOK=$(printf "\033[00;31mNOT OK\033[00m")
OK=$(printf "\033[00;32mOK\033[00m")
LATEST=$(printf "\033[00;32mUP TO DATE\033[00m")
NLATEST=$(printf "\033[00;33mOUTDATED\033[00m")
TEMPLATE=/sys_apps_01/sys_adm/common/AutomationScripts/Compliance/Compliance.tplt
NTP_SERVER1=$(grep -v "# local clock" /etc/ntp.conf 2> /dev/null | awk '/server/ {print $2}' | head -1)
NTP_SERVER2=$(grep -v "# local clock" /etc/ntp.conf 2> /dev/null | awk '/server/ {print $2}' | tail -1)

function LoadTemplate {
	
	if [ ! -f $TEMPLATE ]
	then
		printLog "\nABORTED: Compliance Template File not found\n\n"
		exit 1
	fi
}

function printLog {

	# Send the input to the screen and to a log file
	
	printf "$@" 2>&1 | tee -a $LOG_FILE
	return 0
}

function netmask_h2d {
	
	# Convert Solaris Netmask from HEX to DEC
	set -- `echo $1 | sed -e 's/\([0-9a-fA-F][0-9a-fA-F]\)/\1\ /g'`
	perl -e '$,=".";print 0x'$1',0x'$2',0x'$3',0x'$4
}

function SolarisExceptions {

	# Solaris 8/9 aren't supported
	if [ "$PLATFORM" == "SunOS" ]
	then
		NTP_SERVER1=$(grep -v "# local clock" /etc/inet/ntp.conf 2> /dev/null | awk '/server/ {print $2}' | head -1)
		NTP_SERVER2=$(grep -v "# local clock" /etc/inet/ntp.conf 2> /dev/null | awk '/server/ {print $2}' | tail -1)
		if [ "$OS_VERSION" == "5.8" ] || [ "OS_VERSION" == "5.9" ]
		then
			printLog "\nABORTED: Platform Not Supported $PLATFORM $OS_VERSION\n\n"
			exit 1
		fi
	fi
}

function RootExecution {

	# Make sure only root can run our script
	ID=$(id | awk -F"=" '{ print $2 }' | cut -c1)
	if [ "$ID" -ne 0 ]
	then
		printLog "\nABORTED: You must execute this application with root privileges!\n\n"
		exit 1
	fi
	
}



##################
# MAIN FUNCTIONS #
##################


function GatherInformation {

#GLOBAL SETTINGS
	
	# GENERAL SERVER INFORMATION
	ULIMIT=$(ulimit -a)
	TEMPFS=$(df -k /tmp | sed 's/%/%%/g')
	
	# NETWORK DETAILS
	ROUTE_TABLE=$(netstat -nr | grep -v tables) 
	DNS=$(cat /etc/resolv.conf 2> /dev/null | grep -v ^#) 
	DNS_DOMAIN=$(grep -w "domain mastercard.int" /etc/resolv.conf 2> /dev/null)
	DNS_SEARCH=$(grep -w "search mastercard.int" /etc/resolv.conf 2> /dev/null)
	
	# SOFTWARES
	DSMC=$(exit | dsmc 2> /dev/null )
	DSMC_STATUS=$(exit | dsmc 2> /dev/null | awk '/Session established/ {print $2}')
	SENDMAIL_HOSTS=$(grep mail /etc/hosts 2> /dev/null| grep -v ^#) 
	SENDMAIL_CFG=$(grep -w "DSesmtp:mailhost" /etc/mail/sendmail.cf 2> /dev/null | grep -v ^#) 
	ntpq -p > /tmp/ntp_output 2>&1
	NTP=$(cat /tmp/ntp_output)

	# COMPLIANCE CHECK

	if [ "$DSMC_STATUS" == "established" ];then COMPLIANCE_DSMC_STATUS=$OK;else	COMPLIANCE_DSMC_STATUS=$NOK;fi; [[ -z "$DSMC_STATUS" ]] && DSMC_STATUS=N/A
	if [ ! -z "$SENDMAIL_CFG" ]; then	COMPLIANCE_SENDMAIL=$OK;else	COMPLIANCE_SENDMAIL=$NOK;fi
	if [ "$DNS_DOMAIN" == "domain mastercard.int" ]; then	COMPLIANCE_DNS_DOMAIN=$OK;else	COMPLIANCE_DNS_DOMAIN=$NOK;fi
	if [ "$DNS_SEARCH" == "search mastercard.int mastercard.net mastercard.com mclocal.int" ]; then	COMPLIANCE_DNS_SEARCH=$OK;else	COMPLIANCE_DNS_SEARCH=$NOK;fi
		
	case $ENVIRONMENT in
	
	# STL STAGE
	(0stl|1stl|4stl)
		
		DNS_SERVER=$(awk '/nameserver/ {print $2}' /etc/resolv.conf 2> /dev/null | head -1)
		if [ "$NTP_SERVER1" == "adm0stl0" ] || [ "$NTP_SERVER1" == "adm0stl1" ]; then	COMPLIANCE_NTP_SERVER1=$OK;else	COMPLIANCE_NTP_SERVER1=$NOK;fi; [[ -z "$NTP_SERVER1" ]] && NTP_SERVER1=N/A
		if [ "$NTP_SERVER2" == "adm0stl0" ] || [ "$NTP_SERVER2" == "adm0stl1" ]; then	COMPLIANCE_NTP_SERVER2=$OK;else	COMPLIANCE_NTP_SERVER2=$NOK;fi; [[ -z "$NTP_SERVER2" ]] && NTP_SERVER2=N/A
		if [ "$DNS_SERVER" == "10.157.57.53" ]; then	COMPLIANCE_DNS_SERVER=$OK;else	COMPLIANCE_DNS_SERVER=$NOK;fi; [[ -z "$DNS_SERVER" ]] && DNS_SERVER=N/A
	;;
	
	# STL PROD
	(2stl)
		
		DNS_SERVER=$(awk '/nameserver/ {print $2}' /etc/resolv.conf 2> /dev/null | head -1)
		if [ "$NTP_SERVER1" == "adm2stl0" ] || [ "$NTP_SERVER1" == "adm2stl1" ]; then	COMPLIANCE_NTP_SERVER1=$OK;else	COMPLIANCE_NTP_SERVER1=$NOK;fi; [[ -z "$NTP_SERVER1" ]] && NTP_SERVER1=N/A
		if [ "$NTP_SERVER2" == "adm2stl0" ] || [ "$NTP_SERVER2" == "adm2stl1" ]; then	COMPLIANCE_NTP_SERVER2=$OK;else	COMPLIANCE_NTP_SERVER2=$NOK;fi; [[ -z "$NTP_SERVER2" ]] && NTP_SERVER2=N/A
		if [ "$DNS_SERVER" == "10.154.57.53" ] || [ "$DNS_SERVER" == "10.150.57.53" ] ; then	COMPLIANCE_DNS_SERVER=$OK;else	COMPLIANCE_DNS_SERVER=$NOK;fi; [[ -z "$DNS_SERVER" ]] && DNS_SERVER=N/A
	;;
	
	# KSC PROD
	(2ksc)
	
		DNS_SERVER=$(awk '/nameserver/ {print $2}' /etc/resolv.conf 2> /dev/null | head -1)
		if [ "$NTP_SERVER1" == "adm2ksc2" ] || [ "$NTP_SERVER1" == "adm2ksc3" ]; then	COMPLIANCE_NTP_SERVER1=$OK;else	COMPLIANCE_NTP_SERVER1=$NOK;fi; [[ -z "$NTP_SERVER1" ]] && NTP_SERVER1=N/A
		if [ "$NTP_SERVER2" == "adm2ksc2" ] || [ "$NTP_SERVER2" == "adm2ksc3" ]; then	COMPLIANCE_NTP_SERVER2=$OK;else	COMPLIANCE_NTP_SERVER2=$NOK;fi; [[ -z "$NTP_SERVER2" ]] && NTP_SERVER2=N/A
		if [ "$DNS_SERVER" == "10.150.57.53" ] || [ "$DNS_SERVER" == "10.154.57.53" ] ; then	COMPLIANCE_DNS_SERVER=$OK;else	COMPLIANCE_DNS_SERVER=$NOK;fi; [[ -z "$DNS_SERVER" ]] && DNS_SERVER=N/A
	;;
	
	esac

	case $PLATFORM in
	
	(AIX)
	
	
	# KERNEL
	
		AIX_VERSION=$(uname -a | awk '{print $4}')
		OS_LEVEL=$(oslevel -s)
		
		case $AIX_VERSION in
		
		(6)
			OS_LEVEL_TPLT=$(awk '/AIX6-KERNEL/ {print $2}' $TEMPLATE)
		;;
		
		(7)
			OS_LEVEL_TPLT=$(awk '/AIX7-KERNEL/ {print $2}' $TEMPLATE)
		;;
		
		esac
			
		# COMPLIANCE CHECK
		if [ "$OS_LEVEL" == "$OS_LEVEL_TPLT" ]; then	COMPLIANCE_OS_LEVEL=$LATEST;else	COMPLIANCE_OS_LEVEL=$NLATEST;fi
		
		
	# GENERAL SERVER INFORMATION
	
		/usr/sbin/prtconf > /tmp/prtconf_output 2> /dev/null
		SYSTEM_MODEL=$(awk '/System Model:/ {print $3}' /tmp/prtconf_output ) 
		PROCESSORS=$(awk '/Number Of Processors:/ {print $4}' /tmp/prtconf_output) 
		CORES=$(iostat | awk '/lcpu/ {print $3}' | awk -F '=' '{print $2}')
		CLOCK_SPEED=$(awk '/Processor Clock Speed:/ {print $4}' /tmp/prtconf_output) 
		CPU_TYPE=$(awk '/CPU Type:/ {print $3}' /tmp/prtconf_output) 
		
		LPARSTAT=$(lparstat)
		PKGCHK=$(lppchk -v)
		MAXPROC=$(lsattr -El sys0 | awk '/maxuproc/ {print $2}')
		VIO=$(lsdev -Cc disk)
		LSPATH=$(lspath)
		HCHECK=$(lsattr -El hdisk0 | egrep 'hcheck_interval|hcheck_mode')
		HCHECK_INTERVAL=$(lsattr -El hdisk0 | awk '/hcheck_interval/ {print $6}')
		HCHECK_MODE=$(lsattr -El hdisk0 | awk '/hcheck_mode/ {print $6}')
			
		# COMPLIANCE CHECK
		[[ -z "$HCHECK" ]] && HCHECK=N/A
		if [ -z "$PKGCHK" ];then	COMPLIANCE_PKGCHK=$OK;else	COMPLIANCE_PKGCHK=$NOK;fi
		if [ "$MAXPROC" -ge "2048" ];then	COMPLIANCE_MAXPROC=$OK;else	COMPLIANCE_MAXPROC=$NOK;fi
		if [ "$HCHECK_INTERVAL" == "True" ];then	COMPLIANCE_HCHECK_INTERVAL=$OK;else	COMPLIANCE_HCHECK_INTERVAL=$NOK;fi; [[ -z "$HCHECK_INTERVAL" ]] && HCHECK_INTERVAL=N/A	
		if [ "$HCHECK_MODE" == "True" ];then	COMPLIANCE_HCHECK_MODE=$OK;else	COMPLIANCE_HCHECK_MODE=$NOK;fi; [[ -z "$HCHECK_MODE" ]] && HCHECK_MODE=N/A

		
	# HARDWARE
	
		# RAM
		TOTAL_RAM=$(svmon -G | awk ' /memory/ {printf ("%5.2f",$2/256/1024)}'| sed 's/ //g') 
		FREE_RAM=$(svmon -G | awk ' /memory/ {printf ("%5.2f",$4/256/1024)}' | sed 's/ //g') 
		USED_RAM=$(svmon -G | awk ' /in use/ {printf ("%5.2f",($3+$5)/256/1024)}'| sed 's/ //g') 
		RAM_PCT=$(svmon -G | awk ' /memory/ {printf ("%5.0f",($4/$2)*100)}') 
		# SWAP
		TOTAL_SWAP=$(svmon -G | awk ' /pg space/ {printf ("%5.2f",$3/256/1024)}'| sed 's/ //g') 
		FREE_SWAP=$(svmon -G | awk ' /pg space/ {printf ("%5.2f",($3-$4)/256/1024)}'| sed 's/ //g') 
		USED_SWAP=$(svmon -G | awk ' /pg space/ {printf ("%5.2f",$4/256/1024)}'| sed 's/ //g') 
		SWAP_PCT=$(svmon -G | awk ' /pg space/ {printf ("%5.2f\n",($3-$4)/$3*100)}') 
		PAGESIZE=$(pagesize)
		# CPU
		CPU_IDDLE=$(iostat | awk '/idle/ {getline;print $5}' | sed 's/ //g' | cut -f 1 -d.) 
		# DISKS & FILESYSTEM
		AUTOMOUNT_SERVICE=$(lssrc -s automountd) 
		AUTOMOUNT_SETTING=$(grep -v ^# /etc/auto_direct) 
		AUTOMOUNT_STATUS=$(lssrc -s automountd | awk '/automountd/ {print $4}') 
		FS_FULL=$(df | egrep '(8[5-9]%)|(9[0-9]%)|(100%)' | grep -v /sys_apps_01/sys_adm/common | grep -v /mnt | awk ' {print $4 "\t" $7} ' | sort -rn | sed 's/%/%%/g') 
		VGS=$(lsvg)
		LVS=$(lspv 2> /dev/null | awk '{print $1}' | xargs -n 1 lspv -l 2> /dev/null)
		mount | awk '{print $2}' | grep ^/ | sort > /tmp/mount_output
		grep -v ^* /etc/filesystems | grep ^/ | cut -f1 -d: | sort > /tmp/fstab_output
		SDIFF_FS=$(sdiff /tmp/mount_output /tmp/fstab_output)
		DIFF_FS=$(diff /tmp/mount_output /tmp/fstab_output)
		
		# COMPLIANCE CHECK
		if [ "$RAM_PCT" -ge 20 ];then	COMPLIANCE_RAM_PCT=$OK; else	COMPLIANCE_RAM_PCT=$NOK;fi
		if [ "$SWAP_PCT" -ge 20 ];then	COMPLIANCE_SWAP_PCT=$OK;else	COMPLIANCE_SWAP_PCT=$NOK;fi
		if [ "$PAGESIZE" == "4096" ];then	COMPLIANCE_PAGESIZE=$OK;else	COMPLIANCE_PAGESIZE=$NOK;fi
		if [ "$CPU_IDDLE" -ge 20 ];then	COMPLIANCE_CPU_IDDLE=$OK;else	COMPLIANCE_CPU_IDDLE=$NOK;fi
		if [ "$AUTOMOUNT_STATUS" == "active" ];then	COMPLIANCE_AUTOMOUNT=$OK;else	COMPLIANCE_AUTOMOUNT=$NOK;fi
		if [ -z "$FS_FULL" ];then	COMPLIANCE_FS_FULL=$OK;else	COMPLIANCE_FS_FULL=$NOK;fi	
		if [ -z "$DIFF_FS" ];then	COMPLIANCE_DIFF_FS=$OK;else	COMPLIANCE_DIFF_FS=$NOK;fi
		
	# NETWORK SETTINGS
		
		IP_ADDRESS=$(awk '/IP Address:/ {print $3}' /tmp/prtconf_output) 
		INTERFACES=$(ifconfig -a | egrep 'inet|UP') 
		SUBNET=$(awk '/Sub Netmask:/ {print $3}' /tmp/prtconf_output) 
		GATEWAY=$(awk '/Gateway:/ {print $2}' /tmp/prtconf_output)
		TSM_SERVER=$(awk '/TCPServeraddress/ {print $2}' /usr/tivoli/tsm/client/ba/bin64/dsm.sys 2> /dev/null | head -1 | cut -d . -f 1,2,3)
		PRIMARY_INTERFACE=$(netstat -nr | grep $IP_ADDRESS | head -1 | awk '{print $6}')
		BKP_INTERFACE=$(netstat -nr| grep $TSM_SERVER 2> /dev/null | head -1 | awk '{print $6}'); [[ -z "$BKP_INTERFACE" ]] && BKP_INTERFACE=N/A
		BKP_ADDRESS=$(ifconfig $BKP_INTERFACE 2> /dev/null| awk '/inet/ {print $2}')
		NETWORK_ATT=$(lsattr -El ent0) 
		ROUTE_STATS=$(netstat -nsr) 
		NETSVC=$(grep "local, bind4" /etc/netsvc.conf)
		FULLDUPLEX=$(entstat -d $PRIMARY_INTERFACE | awk '/Media Speed Running/ {print $6$7}')
		FULLDUPLEX_BKP=$(entstat -d $BKP_INTERFACE | awk '/Media Speed Running/ {print $6$7}')
		ETH_SPEED=$(entstat -d $PRIMARY_INTERFACE | awk '/Media Speed Selected/ {print $4$5}')
		ETH_SPEED_BKP=$(entstat -d $BKP_INTERFACE | awk '/Media Speed Selected/ {print $4$5}')
		VLAN=$(echo $IP_ADDRESS | cut -f 1,2,3 -d.)
		SUBNET_TPLT=$(grep ^$VLAN $TEMPLATE | awk '{print $2}') 
		GATEWAY_TPLT=$(grep ^$VLAN $TEMPLATE | awk '{print $3}') 

		# COMPLIANCE CHECK
		if [ "$GATEWAY" == "$GATEWAY_TPLT" ]; then	COMPLIANCE_GATEWAY=$OK;else	COMPLIANCE_GATEWAY=$NOK;fi
		if [ "$SUBNET" == "$SUBNET_TPLT" ]; then	COMPLIANCE_NETMASK=$OK;else COMPLIANCE_NETMASK=$NOK;fi
		if [ "$FULLDUPLEX" == "FullDuplex" ];then	COMPLIANCE_FULLDUPLEX=$OK;else	COMPLIANCE_FULLDUPLEX=$NOK;fi; [[ -z "$FULLDUPLEX" ]] && FULLDUPLEX=N/A
		if [ "$FULLDUPLEX_BKP" == "FullDuplex" ];then	COMPLIANCE_FULLDUPLEX_BKP=$OK;else	COMPLIANCE_FULLDUPLEX_BKP=$NOK;fi; [[ -z "$FULLDUPLEX_BKP" ]] && FULLDUPLEX_BKP=N/A
		if [ "$ETH_SPEED" == "100Mbps" ] || [ "$ETH_SPEED" == "1000Mbps" ] || [ "$ETH_SPEED" == "Autonegotiation" ];then	COMPLIANCE_ETH_SPEED=$OK;else	COMPLIANCE_ETH_SPEED=$NOK;fi; [[ -z "$ETH_SPEED" ]] && ETH_SPEED=N/A
		if [ "$ETH_SPEED_BKP" == "100Mbps" ] || [ "$ETH_SPEED_BKP" == "1000Mbps" ] || [ "$ETH_SPEED_BKP" == "Autonegotiation" ];then	COMPLIANCE_ETH_SPEED_BKP=$OK;else	COMPLIANCE_ETH_SPEED_BKP=$NOK;fi; [[ -z "$ETH_SPEED_BKP" ]] && ETH_SPEED_BKP=N/A
		if [ "$NETSVC" == "hosts = local, bind4" ];then COMPLIANCE_NETSVC=$OK;else	COMPLIANCE_NETSVC=$NOK;fi; [[ -z "$NETSVC" ]] && NETSVC=N/A
		if [ ! -z "$BKP_ADDRESS" ]; then	COMPLIANCE_BKP_ADDRESS=$OK;else	COMPLIANCE_BKP_ADDRESS=$NOK;fi; [[ -z "$BKP_ADDRESS" ]] && BKP_ADDRESS=N/A
		
	# SOFTWARE
	
		ODM=$(lslpp -L| grep "EMC.*aix.rte")
		ODM_VERSION=$(lslpp -L| awk '/EMC.*aix.rte/ {print $2}' | sort -u)
		ODM_VERSION_TPLT=$(awk '/AIX-ODM/ {print $2}' $TEMPLATE)
		POWERPATH=$(powermt version)
		POWERPATH_VERSION=$(powermt version | awk '{print $7$8$9$10$11}')
		POWERPATH_VERSION_TPLT=$(awk '/AIX-POWERPATH/ {print $2}' $TEMPLATE)
		/usr/seos/bin/seversion > /tmp/seversion_output 2>&1
		SEOS=$(cat /tmp/seversion_output | awk '/Access/ {print $5}') 
		SEOS_TPLT=$(awk '/AIX-SEOS/ {print $2}' $TEMPLATE)
		
		# COMPLIANCE CHECK
		
		
		if [ "$SEOS" == "$SEOS_TPLT" ]; then	COMPLIANCE_SEOS=$LATEST;else	COMPLIANCE_SEOS=$NLATEST;fi; [[ -z "$SEOS" ]] && SEOS=N/A
		if [ "$ODM_VERSION" == "$ODM_VERSION_TPLT" ]; then	COMPLIANCE_ODM_VERSION=$LATEST;else	COMPLIANCE_ODM_VERSION=$NLATEST;fi
		if [ "$POWERPATH_VERSION" == "$POWERPATH_VERSION_TPLT" ]; then	COMPLIANCE_POWERPATH_VERSION=$LATEST;else	COMPLIANCE_POWERPATH_VERSION=$NLATEST;fi; [[ -z "$POWERPATH_VERSION" ]] && POWERPATH_VERSION=N/A
		
	# PRINTING REPORTS
	
		PrintGlobalReport
		
		clear
		printLog "\n\033[100;1m========================================================\n"
		printLog "\t\tAIX SPECIFIC INFORMATION\t\t\n"
		printLog "========================================================\n\n\033[00m"
		
		printLog "\n-------------\n$(tput bold)LPAR Status$(tput sgr0)\n-------------\n$LPARSTAT\n"
		
		if [ -z "$PKGCHK" ]
		then
			printLog "\n----------------------\n$(tput bold)Packages Inconsistency$(tput sgr0)\n----------------------\nNone inconsistency was found\n"
		else
			printLog "\n----------------------\n$(tput bold)Packages Inconsistency$(tput sgr0)\n----------------------\n$PKGCHK\n"
		fi
		
		printLog "\n------------------\n$(tput bold)VIO Client Check$(tput sgr0)\n------------------\n$VIO\n"
				
		printLog "\n-------------\n$(tput bold)Active Paths$(tput sgr0)\n-------------\n$LSPATH\n"
		printLog "\n------------------\n$(tput bold)Disk Health Check$(tput sgr0)\n------------------\n$HCHECK\n\n"
		printLog "\n-------------\n$(tput bold)PowerPath$(tput sgr0)\n-------------\n$POWERPATH\n\n"
		printLog "\n-------------\n$(tput bold)ODM$(tput sgr0)\n-------------\n$ODM\n\n\n"
		sleep 10
		
		PrintSummaryReport		
			
	;;
	
	(Linux)
	
	# KERNEL
	
		RHEL_VERSION=$(awk '{print $7}' /etc/redhat-release | cut -f1 -d.)
		OS_LEVEL=$(uname -r)
		
		case $RHEL_VERSION in
		
		(5)
			OS_LEVEL_TPLT=$(awk '/RHEL5-KERNEL/ {print $2}' $TEMPLATE)
		;;
		
		(6)
			OS_LEVEL_TPLT=$(awk '/RHEL6-KERNEL/ {print $2}' $TEMPLATE)
		;;
		
		esac
			
		# COMPLIANCE CHECK
		if [ "$OS_LEVEL" == "$OS_LEVEL_TPLT" ]; then	COMPLIANCE_OS_LEVEL=$LATEST;else	COMPLIANCE_OS_LEVEL=$NLATEST;fi
	
	
	# GENERAL SERVER INFORMATION
	
		SYSTEM_MODEL=$(dmidecode -t system | awk '/Manufacturer:/ {print $2$3}' 2> /dev/null)
		PROCESSORS=$(grep -c ^processor /proc/cpuinfo)
		CORES=N/A
		CLOCK_SPEED=$(awk '/MHz/ {print $4}' /proc/cpuinfo | head -1)
		CPU_TYPE=$(uname -p)
				
		
	# HARDWARE
		
		# RAM
		TOTAL_RAM=$(free -g | awk '/Mem:/ {print $2}')
		FREE_RAM=$(free -g | awk '/Mem:/ {print $4}')
		USED_RAM=$(free -g | awk '/Mem:/ {print $3}')		
		RAM_PCT=$(free -g | awk '/Mem:/ {printf ("%5.0f",($4/$2)*100)}'| sed 's/ //g')
		# SWAP
		TOTAL_SWAP=$(free -g | awk '/Swap/ {print $2}')
		FREE_SWAP=$(free -g | awk '/Swap/ {print $4}')
		USED_SWAP=$(free -g | awk '/Swap/ {print $3}')
		SWAP_PCT=$(free -g | awk '/Swap/ {printf ("%5.0f",($4/$2)*100)}'| sed 's/ //g')
		# CPU
		CPU_IDDLE=$(top -b -n 1 | awk '/Cpu/ {print $5}'| cut -f1 -d.)
		# DISKS & FILESYSTEM
		AUTOMOUNT_SERVICE=$(service autofs status)
		AUTOMOUNT_SETTING=$(grep -v ^# /etc/auto.direct) 
		AUTOMOUNT_STATUS=$(service autofs status | awk '/automount/ {print $5}') 
		FS_FULL=$(df | egrep '(8[5-9]%)|(9[0-9]%)|(100%)' | grep -v /sys_apps_01/sys_adm/common | grep -v /mnt | awk ' {print $4 "\t" $5} ' | sort -rn | sed 's/%/%%/g')
		VGS=$(vgs 2> /dev/null)
		LVS=$(lvs 2> /dev/null | sed 's/%/%%/g')
		MOUNT=$(mount | grep -v /boot | grep ^/ | awk '{print $3}' | sort)
		FSTAB=$(grep -v ^# /etc/fstab | grep -v swap | grep ^/ | awk '{print $2}' | sort)
		SDIFF_FS=$(sdiff <(echo "$MOUNT") <(echo "$FSTAB"))
		DIFF_FS=$(diff <(echo "$MOUNT") <(echo "$FSTAB"))
		
		# COMPLIANCE CHECK
			
		if [ "$RAM_PCT" -ge 20 ];then	COMPLIANCE_RAM_PCT=$OK; else	COMPLIANCE_RAM_PCT=$NOK;fi
		if [ "$SWAP_PCT" -ge 20 ];then	COMPLIANCE_SWAP_PCT=$OK;else	COMPLIANCE_SWAP_PCT=$NOK;fi
		if [ "$CPU_IDDLE" -ge 20 ];then	COMPLIANCE_CPU_IDDLE=$OK;else	COMPLIANCE_CPU_IDDLE=$NOK;fi
		if [ "$AUTOMOUNT_STATUS" == "running..." ];then	COMPLIANCE_AUTOMOUNT=$OK;else	COMPLIANCE_AUTOMOUNT=$NOK;fi	
		if [ -z "$DIFF_FS" ];then	COMPLIANCE_DIFF_FS=$OK;else	COMPLIANCE_DIFF_FS=$NOK;fi
		if [ -z "$FS_FULL" ];then	COMPLIANCE_FS_FULL=$OK;else	COMPLIANCE_FS_FULL=$NOK;fi
		
	# NETWORK SETTINGS
		
		IP_ADDRESS=$(grep -w $HOSTNAME /etc/hosts | grep -v ^# | head -1 | awk '{print $1}')
		INTERFACES=$(ifconfig -a)
		TSM_SERVER=$(awk '/TCPServeraddress/ {print $2}'  /opt/tivoli/tsm/client/ba/bin/dsm.sys 2> /dev/null | head -1 | cut -d . -f 1,2,3)
		PRIMARY_INTERFACE=$(route | awk '/default/ {print $NF}')
		BKP_INTERFACE=$(netstat -nr| grep $TSM_SERVER 2> /dev/null | head -1 | awk '{print $NF}'); [[ -z "$BKP_INTERFACE" ]] && BKP_INTERFACE=N/A
		BKP_ADDRESS=$(ifconfig $BKP_INTERFACE 2> /dev/null| awk '/inet/ {print $2}' | cut -d: -f2)
		SUBNET=$(ifconfig -a | awk "/$IP_ADDRESS/" | awk -F ':' '{print $4}')
		GATEWAY=$(route | awk '/default/ {print $2}')
		NETWORK_ATT=$(ethtool $PRIMARY_INTERFACE 2> /dev/null)
		ROUTE_STATS=$(netstat -s | head -11)
		FULLDUPLEX=$(ethtool $PRIMARY_INTERFACE 2> /dev/null | awk '/Duplex/ {print $2}')
		FULLDUPLEX_BKP=$(ethtool $BKP_INTERFACE 2> /dev/null | awk '/Duplex/ {print $2}')
		ETH_SPEED=$(ethtool $PRIMARY_INTERFACE 2> /dev/null | awk '/Auto-negotiation/  {print $2}')
		ETH_SPEED_BKP=$(ethtool $BKP_INTERFACE 2> /dev/null | awk '/Auto-negotiation/  {print $2}') 
		VLAN=$(echo $IP_ADDRESS | cut -f 1,2,3 -d.)
		SUBNET_TPLT=$(grep ^$VLAN $TEMPLATE | awk '{print $2}') 
		GATEWAY_TPLT=$(grep ^$VLAN $TEMPLATE | awk '{print $3}')
		
		# COMPLIANCE CHECK
		if [ "$GATEWAY" == "$GATEWAY_TPLT" ]; then	COMPLIANCE_GATEWAY=$OK;else	COMPLIANCE_GATEWAY=$NOK;fi
		if [ "$SUBNET" == "$SUBNET_TPLT" ]; then	COMPLIANCE_NETMASK=$OK;else COMPLIANCE_NETMASK=$NOK;fi
		if [ "$FULLDUPLEX" == "Full" ]; then	COMPLIANCE_FULLDUPLEX=$OK;else	COMPLIANCE_FULLDUPLEX=$NOK;fi; [[ -z "$FULLDUPLEX" ]] && FULLDUPLEX=N/A
		if [ "$FULLDUPLEX_BKP" == "Full" ]; then	COMPLIANCE_FULLDUPLEX_BKP=$OK;else	COMPLIANCE_FULLDUPLEX_BKP=$NOK;fi; [[ -z "$FULLDUPLEX_BKP" ]] && FULLDUPLEX_BKP=N/A
		if [ "$ETH_SPEED" == "on" ]; then	COMPLIANCE_ETH_SPEED=$OK;else	COMPLIANCE_ETH_SPEED=$NOK;fi; [[ -z "$ETH_SPEED" ]] && ETH_SPEED=N/A
		if [ "$ETH_SPEED_BKP" == "on" ]; then	COMPLIANCE_ETH_SPEED_BKP=$OK;else	COMPLIANCE_ETH_SPEED_BKP=$NOK;fi; [[ -z "$ETH_SPEED_BKP" ]] && ETH_SPEED_BKP=N/A
		if [ ! -z "$BKP_ADDRESS" ]; then	COMPLIANCE_BKP_ADDRESS=$OK;else	COMPLIANCE_BKP_ADDRESS=$NOK;fi; [[ -z "$BKP_ADDRESS" ]] && BKP_ADDRESS=N/A
			
	# SOFTWARE
		/usr/seos/bin/seversion > /tmp/seversion_output 2>&1
		SEOS=$(cat /tmp/seversion_output | awk '/Access/ {print $5}') 
		SEOS_TPLT=$(awk '/RHEL-SEOS/ {print $2}' $TEMPLATE)
		
		# COMPLIANCE CHECK
		if [ "$SEOS" == "$SEOS_TPLT" ]; then	COMPLIANCE_SEOS=$LATEST;else	COMPLIANCE_SEOS=$NLATEST;fi; [[ -z "$SEOS" ]] && SEOS=N/A
	
	# PRINTING REPORTS
	
		PrintGlobalReport
		PrintSummaryReport		
			
	;;
	
	(SunOS)
	
	# KERNEL
	
		OS_LEVEL=$(uname -v | awk -F'_' '{print $2}')
		OS_LEVEL_TPLT=$(awk '/SUNOS-KERNEL/ {print $2}' $TEMPLATE)
					
		# COMPLIANCE CHECK
		if [ "$OS_LEVEL" == "$OS_LEVEL_TPLT" ]; then	COMPLIANCE_OS_LEVEL=$LATEST;else	COMPLIANCE_OS_LEVEL=$NLATEST;fi
	
	
	# GENERAL SERVER INFORMATION
	
		SYSTEM_MODEL=$(prtconf 2> /dev/null | sed '5!d' | sed 's/,/ /')
		PROCESSORS=$(psrinfo -p)
		CORES=$(psrinfo -pv | head -1 | nawk '{sub(/.*has /,"");sub(/ virtual.*/,"");print;}')
		CLOCK_SPEED=$(kstat cpu_info | grep clock_MHz | head -1 | awk '{print $2}')
		CPU_TYPE=$(kstat cpu_info | grep brand | head -1 | awk '{print $2}')
		
		
	# HARDWARE
		
		# RAM
		TOTAL_RAM=$( top | awk '/Memory/ {print $2}' | cut -f 1 -dG)
		FREE_RAM=$(top | awk '/Memory/ {print $5}' | awk -F'M' '{printf ("%5.2f \n",$1/1024)}' | sed 's/ //g') 
		USED_RAM=$(echo "$TOTAL_RAM - $FREE_RAM" | bc)
		RAM_PCT=$(echo "scale=2;$FREE_RAM/$TOTAL_RAM *100" | bc | cut -f 1 -d.)
		# SWAP
		USED_SWAP=$(swap -s | awk '{print $9}' | cut -dk -f1 | awk '{printf ("%5.0f \n",$1/1000/1000)}' | sed 's/ //g')
		FREE_SWAP=$(swap -s | awk '{print $11}' | cut -dk -f1 | awk '{printf ("%5.0f \n",$1/1000/1000)}' | sed 's/ //g')
		((TOTAL_SWAP = USED_SWAP + FREE_SWAP))
		SWAP_PCT=$(echo "scale=2;$FREE_SWAP/$TOTAL_SWAP *100" | bc | cut -f 1 -d.)
				
		# CPU
		CPU_IDDLE=$(top | awk '/CPU states/ {print $3}' | cut -f 1 -d\% ) 
		# DISK & FILESYSTEM
		AUTOMOUNT_SERVICE=$(svcs 2> /dev/null autofs)
		AUTOMOUNT_SETTING=$(grep -v ^# /etc/auto_direct) 
		AUTOMOUNT_STATUS=$(svcs autofs 2> /dev/null | awk '/online/ {print $1}')
		FS_FULL=$(df  -k | egrep '(8[5-9]%)|(9[0-9]%)|(100%)' | grep -v /sys_apps_01/sys_adm/common | grep -v /mnt | awk ' {print $5 "\t" $1} ' | sort -rn | sed 's/%/%%/g')
		VOLUME_MGR=$(zpool list)
		if [ "$VOLUME_MGR" == "no pools available" ]
		then
			VGS=$(vxdg list)
			LVS=$(vxdisk list)
			mount | grep -v swap | grep -v tab | grep -v sys_adm/common | grep -v odm | grep -v /tmp | awk '{print $1}' | sort > /tmp/mount_output
			grep -v ^# /etc/vfstab  | awk '{print $3}' | grep -v ^/tmp | grep -v ^/etc/dfs/sharetab | grep ^/ > /tmp/fstab_output_temp
			vxlist 2> /dev/null | awk '{print $8}' | grep ^/ >> /tmp/fstab_output_temp
			cat /tmp/fstab_output_temp | sort -u > /tmp/fstab_output
			SDIFF_FS=$(sdiff /tmp/mount_output /tmp/fstab_output)
			DIFF_FS=$(diff /tmp/mount_output /tmp/fstab_output)
		else
			VGS=$(zpool list)
			LVS=$(zfs list)
			mount | grep -v swap | grep -v tab | grep -v sys_adm/common | grep -v odm | grep -v ^/tmp | awk '{print $1}' | sort > /tmp/mount_output
			grep -v ^# /etc/vfstab  | awk '{print $3}' | grep -v ^/tmp | grep -v ^/etc/dfs/sharetab | grep ^/ > /tmp/fstab_output_temp
			zfs list 2> /dev/null | awk '{print $5}' | grep -v ^/tmp | grep ^/ | sort -u >> /tmp/fstab_output_temp
			cat /tmp/fstab_output_temp | sort -u > /tmp/fstab_output
			SDIFF_FS=$(sdiff /tmp/mount_output /tmp/fstab_output)
			DIFF_FS=$(diff /tmp/mount_output /tmp/fstab_output)
		fi
		
		# COMPLIANCE CHECK
			
		if [ "$RAM_PCT" -ge 20 ];then	COMPLIANCE_RAM_PCT=$OK; else	COMPLIANCE_RAM_PCT=$NOK;fi
		if [ "$SWAP_PCT" -ge 20 ];then	COMPLIANCE_SWAP_PCT=$OK;else	COMPLIANCE_SWAP_PCT=$NOK;fi
		if [ "$CPU_IDDLE" -ge 20 ];then	COMPLIANCE_CPU_IDDLE=$OK;else	COMPLIANCE_CPU_IDDLE=$NOK;fi
		if [ "$AUTOMOUNT_STATUS" == "online" ];then	COMPLIANCE_AUTOMOUNT=$OK;else	COMPLIANCE_AUTOMOUNT=$NOK;fi	
		if [ -z "$FS_FULL" ];then	COMPLIANCE_FS_FULL=$OK;else	COMPLIANCE_FS_FULL=$NOK;fi
		if [ -z "$DIFF_FS" ];then	COMPLIANCE_DIFF_FS=$OK;else	COMPLIANCE_DIFF_FS=$NOK;fi
	
	# NETWORK DETAILS
	
		IP_ADDRESS=$(grep -w $HOSTNAME /etc/hosts | grep -v ^# | head -1 | awk '{print $1}')
		INTERFACES=$(ifconfig -a)
		SUBNET_HEX=$(ifconfig -a | awk "/$IP_ADDRESS/" | awk '{print $4}')
		SUBNET=$(netmask_h2d $SUBNET_HEX)
		GATEWAY=$(netstat -nr | awk '/default/ {print $2}')
		TSM_SERVER=$(awk '/TCPServeraddress/ {print $2}' /opt/tivoli/tsm/client/ba/bin/dsm.sys 2> /dev/null | head -1 | cut -d . -f 1,2,3)
		PRIMARY_INTERFACE=$(netstat -nr | awk '/default/ {print $NF}')
		BKP_INTERFACE=$(netstat -nr| grep $TSM_SERVER 2> /dev/null | head -1 | awk '{print $NF}'); [[ -z "$BKP_INTERFACE" ]] && BKP_INTERFACE=N/A
		BKP_ADDRESS=$(ifconfig $BKP_INTERFACE 2> /dev/null| awk '/inet/ {print $2}')
		NETWORK_ATT=$(dladm show-dev 2> /dev/null)
		ROUTE_STATS=$(netstat -Ms)
		VLAN=$(echo $IP_ADDRESS | cut -f 1,2,3 -d.)
		SUBNET_TPLT=$(grep ^$VLAN $TEMPLATE | awk '{print $2}') 
		GATEWAY_TPLT=$(grep ^$VLAN $TEMPLATE | awk '{print $3}') 
		FULLDUPLEX=$(dladm show-dev 2> /dev/null | awk '/link: up/ {print $8}' | head -1)
		FULLDUPLEX_BKP=$(dladm show-dev 2> /dev/null | awk '/link: up/ {print $8}' | tail -1)
		ETH_SPEED=$(dladm show-dev 2> /dev/null | awk '/link: up/ {print $5}' | head -1)
		ETH_SPEED_BKP=$(dladm show-dev 2> /dev/null | awk '/link: up/ {print $5}' | tail -1)
		
		# COMPLIANCE CHECK
		if [ "$GATEWAY" == "$GATEWAY_TPLT" ]; then	COMPLIANCE_GATEWAY=$OK;else	COMPLIANCE_GATEWAY=$NOK;fi
		if [ "$SUBNET" == "$SUBNET_TPLT" ]; then	COMPLIANCE_NETMASK=$OK;else COMPLIANCE_NETMASK=$NOK;fi
		if [ "$FULLDUPLEX" == "full" ]; then	COMPLIANCE_FULLDUPLEX=$OK;else	COMPLIANCE_FULLDUPLEX=$NOK;fi; [[ -z "$FULLDUPLEX" ]] && FULLDUPLEX=N/A
		if [ "$FULLDUPLEX_BKP" == "full" ]; then	COMPLIANCE_FULLDUPLEX_BKP=$OK;else	COMPLIANCE_FULLDUPLEX_BKP=$NOK;fi; [[ -z "$FULLDUPLEX_BKP" ]] && FULLDUPLEX_BKP=N/A
		if [ "$ETH_SPEED" == "100" ] || [ "$ETH_SPEED" == "1000" ]; then	COMPLIANCE_ETH_SPEED=$OK;else	COMPLIANCE_ETH_SPEED=$NOK;fi; [[ -z "$ETH_SPEED" ]] && ETH_SPEED=N/A
		if [ "$ETH_SPEED_BKP" == "100" ] || [ "$ETH_SPEED_BKP" == "1000" ]; then	COMPLIANCE_ETH_SPEED_BKP=$OK;else	COMPLIANCE_ETH_SPEED_BKP=$NOK;fi; [[ -z "$ETH_SPEED_BKP" ]] && ETH_SPEED_BKP=N/A
		if [ ! -z "$BKP_ADDRESS" ]; then	COMPLIANCE_BKP_ADDRESS=$OK;else	COMPLIANCE_BKP_ADDRESS=$NOK;fi; [[ -z "$BKP_ADDRESS" ]] && BKP_ADDRESS=N/A
		
	# SOFTWARE
	
		POWERPATH_VERSION=$(pkginfo -l EMCpower 2> /dev/null | awk /'VERSION/ {print $2}')
		POWERPATH_VERSION_TPLT=$(awk '/SUNOS-POWERPATH/ {print $2}' $TEMPLATE)
		/usr/seos/bin/seversion > /tmp/seversion_output 2>&1
		SEOS=$(cat /tmp/seversion_output | awk '/Access/ {print $5}')
		[[ -z "$SEOS" ]] && SEOS=$(cat /tmp/seversion_output | awk '/seversion/ {print $3}' | head -1)
		SEOS_TPLT=$(awk '/SUNOS-SEOS/ {print $2}' $TEMPLATE)
		
		# COMPLIANCE CHECK
		if [ "$SEOS" == "$SEOS_TPLT" ]; then	COMPLIANCE_SEOS=$LATEST;else	COMPLIANCE_SEOS=$NLATEST;fi; [[ -z "$SEOS" ]] && SEOS=N/A
		if [ "$POWERPATH_VERSION" == "$POWERPATH_VERSION_TPLT" ]; then	COMPLIANCE_POWERPATH_VERSION=$LATEST;else	COMPLIANCE_POWERPATH_VERSION=$NLATEST;fi
	
	
	# PRINTING REPORTS
	
		PrintGlobalReport
		
		PrintSummaryReport		
					
	;;
	
	esac
	
	}
	
function PrintGlobalReport {

	# GENERATING OUTPUT	
			
		printLog "\033[100;1m========================================================\n"
		printLog "\t\tGENERAL INFORMATION\t\t\t\n"
		printLog "========================================================\n\n\033[00m"
		printLog "SYSTEM MODEL ------------------- $(tput bold)$SYSTEM_MODEL\n$(tput sgr0)"
		printLog "PROCESSORS --------------------- $(tput bold)$PROCESSORS\n$(tput sgr0)"
		printLog "CORES -------------------------- $(tput bold)$CORES\n$(tput sgr0)"
		printLog "CLOCK SPEED -------------------- $(tput bold)$CLOCK_SPEED MHz\n$(tput sgr0)" 
		printLog "CPU TYPE ----------------------- $(tput bold)$CPU_TYPE\n$(tput sgr0)"
		printLog "OS LEVEL ----------------------- $(tput bold)$OS_LEVEL\n$(tput sgr0)"
		printLog "\n----------------\n$(tput bold)Ulimit Settings$(tput sgr0)\n----------------\n$ULIMIT"
		
	
	# HARDWARE AND USAGE INFORMATION
	
		
		printLog "\n\n\n\033[100;1m========================================================\n"
		printLog "\tHARDWARE AND USAGE INFORMATION\t\t\t\n"
		printLog "========================================================\n\n\033[00m"
		printLog "TOTAL RAM ---------------------- $(tput bold)$TOTAL_RAM G\n$(tput sgr0)"
		printLog "FREE RAM ----------------------- $(tput bold)$FREE_RAM G\n$(tput sgr0)"
		printLog "USED RAM ----------------------- $(tput bold)$USED_RAM G\n$(tput sgr0)"
		printLog "TOTAL SWAP --------------------- $(tput bold)$TOTAL_SWAP G \n$(tput sgr0)"
		printLog "FREE SWAP ---------------------- $(tput bold)$FREE_SWAP G \n$(tput sgr0)"
		printLog "USED SWAP ---------------------- $(tput bold)$USED_SWAP G\n$(tput sgr0)"
		printLog "CPU IDDLE ---------------------- $(tput bold)$CPU_IDDLE %%\n$(tput sgr0)"
		sleep 10
		clear
		
		printLog "\n\033[100;1m========================================================\n"
		printLog "\tDISKS AND FILESYSTEMS\t\t\t\n"
		printLog "========================================================\n\033[00m"
		if [ ! -z "$FS_FULL" ]
		then
			printLog "\n\n-----------------------------\n$(tput bold)File Systems Above Threshold $(tput sgr0)\n-----------------------------\n$FS_FULL\n"
		fi
		printLog "\n\n------------------\n$(tput bold)Automount Service$(tput sgr0)\n------------------\n$AUTOMOUNT_SERVICE\n\n$AUTOMOUNT_SETTING\n"
		printLog "\n\n------------------\n$(tput bold)Temp Filesystem$(tput sgr0)\n------------------\n$TEMPFS\n"
		sleep 10
		clear
		printLog "\n------------------\n$(tput bold)Volume Groups (VG)$(tput sgr0)\n------------------\n$VGS"
		printLog "\n\n------------------\n$(tput bold)Logical Volumes (LV)$(tput sgr0)\n------------------\n$LVS"
		sleep 10
		clear
		printLog "\n---------------------------\n$(tput bold)FileSystems Comparations$(tput sgr0)\n---------------------------\n\n"
		printLog "\033[100;1mMOUNTED FILESYSTEMS\t\t\t\t\t\tFSTAB FILE\033[00m\n\n\n$SDIFF_FS\n"
		sleep 10
			
	# NETWORK SETTINGS
	
		clear
		printLog "\n\033[100;1m========================================================\n"
		printLog "\t\tNETWORK SETTINGS\t\t\t\n"
		printLog "========================================================\n\n\033[00m"
		printLog "PRIMARY IP ADDRESS ------------- $(tput bold)$IP_ADDRESS\n$(tput sgr0)"
		printLog "SUBNET NETMASK ----------------- $(tput bold)$SUBNET\n$(tput sgr0)"
		printLog "GATEWAY ------------------------ $(tput bold)$GATEWAY\n$(tput sgr0)"
		printLog "\n----------------\n$(tput bold)Interfaces$(tput sgr0)\n----------------\n$INTERFACES"
		printLog "\n\n------------------\n$(tput bold)Network Attributes$(tput sgr0)\n------------------\n$NETWORK_ATT"
		sleep 10
		clear
		printLog "\n----------------\n$(tput bold)Routing Tables$(tput sgr0)\n----------------\n$ROUTE_TABLE"
		printLog "\n\n------------------\n$(tput bold)Routing Statistics$(tput sgr0)\n------------------\n$ROUTE_STATS"
		printLog "\n\n----------------\n$(tput bold)DNS Settings$(tput sgr0)\n----------------\n$DNS\n"
		sleep 10		

	# SOFTWARES
		
		clear
		printLog "\n\033[100;1m========================================================\n"
		printLog "\t\tSOFTWARE INFORMATION\t\t\t\n"
		printLog "========================================================\n\033[00m"
		
		if [ -z "$DSMC" ]
		then
			printLog "\n----------------------\n$(tput bold)Tivoli Storage Manager$(tput sgr0)\n----------------------\nNot Configured\n"
		else
			printLog "\n----------------------\n$(tput bold)Tivoli Storage Manager$(tput sgr0)\n----------------------\n$DSMC\n"
		fi
		
		if [ -z "$SENDMAIL_HOSTS" ] && [ -z "$SENDMAIL_CFG" ]
		then
			printLog "\n---------\n$(tput bold)Sendmail$(tput sgr0)\n---------\nNot Configured"
		else
			printLog "\n---------\n$(tput bold)Sendmail$(tput sgr0)\n---------\n$SENDMAIL_HOSTS\n$SENDMAIL_CFG"
		fi
		
		printLog "\n\n----------\n$(tput bold)   NTP$(tput sgr0)\n----------\n$(cat /tmp/ntp_output)\n"
		printLog "\n------------\n$(tput bold)SEOS Version$(tput sgr0)\n------------\n$SEOS\n\n"
		sleep 10
	
}


function PrintSummaryReport {
	
	clear
	tput bold
	printLog "+%-69.69s+%30.30s+\n" "----------------------------------------------------------------------" "------------------------------"
	printLog "|%-69.69s|%-30.30s|\n" "                     COMPLIANCE VERSION CONTROL" "        REFERENCE VALUE"
	printLog "+%-69.69s+%30.30s+\n" "----------------------------------------------------------------------" "------------------------------"
	tput sgr0
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "KERNEL LEVEL" "$OS_LEVEL" "$COMPLIANCE_OS_LEVEL" "$OS_LEVEL_TPLT"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "ACX VERSION" "$SEOS" "$COMPLIANCE_SEOS" "$SEOS_TPLT"
	
	case $PLATFORM in
	
	(AIX)
		
		printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "ODM VERSION" "$ODM_VERSION" "$COMPLIANCE_ODM_VERSION" "$ODM_VERSION_TPLT"
		printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "POWERPATH VERSION" "$POWERPATH_VERSION" "$COMPLIANCE_POWERPATH_VERSION" "$POWERPATH_VERSION_TPLT"
		
		tput bold
		printLog "+%-69.69s+%30.30s+\n" "----------------------------------------------------------------------" "------------------------------"
		printLog "|%-69.69s|%30.30s\n" "                     HARDWARE AND USAGE SUMMARY"
		printLog "+%-69.69s+%30.30s+\n" "----------------------------------------------------------------------" "------------------------------"
		tput sgr0
		printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "PAGE SIZE" "$PAGESIZE" "$COMPLIANCE_PAGESIZE" "4096"
		printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "MAXPROC" "$MAXPROC" "$COMPLIANCE_MAXPROC" "> 2048"
		printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "HCHECK INTERVAL" "$HCHECK_INTERVAL" "$COMPLIANCE_HCHECK_INTERVAL" "True"
		printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "HCHECK INTERVAL" "$HCHECK_MODE" "$COMPLIANCE_HCHECK_MODE" "True"
		printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "LPPCHK" "-" "$COMPLIANCE_PKGCHK" "None"
		printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "NETSVC FILE" "-" "$COMPLIANCE_NETSVC" "hosts = local, bind4"
	
	
	;;
	
	(Linux)
	
		tput bold
		printLog "+%-69.69s+%30.30s+\n" "----------------------------------------------------------------------" "------------------------------"
		printLog "|%-69.69s|%30.30s\n" "                     HARDWARE AND USAGE SUMMARY"
		printLog "+%-69.69s+%30.30s+\n" "----------------------------------------------------------------------" "------------------------------"
		tput sgr0
		
	;;
	
	(SunOS)
	
		printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "POWERPATH VERSION" "$POWERPATH_VERSION" "$COMPLIANCE_POWERPATH_VERSION" "$POWERPATH_VERSION_TPLT"
		
		tput bold
		printLog "+%-69.69s+%30.30s+\n" "----------------------------------------------------------------------" "------------------------------"
		printLog "|%-69.69s|%30.30s\n" "                     HARDWARE AND USAGE SUMMARY"
		printLog "+%-69.69s+%30.30s+\n" "----------------------------------------------------------------------" "------------------------------"
		tput sgr0
			
	;;
	
	esac
	
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "AVAILABLE MEMORY RAM" "$RAM_PCT %" "$COMPLIANCE_RAM_PCT" "> 20%"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "AVAILABLE SWAP" "$SWAP_PCT %" "$COMPLIANCE_SWAP_PCT" "> 20%"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "CPU IDDLE" "$CPU_IDDLE %" "$COMPLIANCE_CPU_IDDLE" "> 20%"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "AUTOMOUNT SERVICE" "$AUTOMOUNT_STATUS" "$COMPLIANCE_AUTOMOUNT" "Active/Running"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "FS ABOVE THRESHOLD" "-" "$COMPLIANCE_FS_FULL" "None"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "MOUNT X FSTAB COMPARISON" "-" "$COMPLIANCE_DIFF_FS" "None difference"
	tput bold
	printLog "+%-69.69s+%30.30s+\n" "-----------------------------------------------------------------------" "------------------------------"
	printLog "|%-69.69s|%30.30s\n" "                     NETWORK SETTINGS SUMMARY"
	printLog "+%-69.69s+%30.30s+\n" "-----------------------------------------------------------------------" "------------------------------"
	tput sgr0
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "PRIMARY IP ADDRESS" "$IP_ADDRESS" "$OK" "Online Interface"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "BACKUP IP ADDRESS" "$BKP_ADDRESS" "$COMPLIANCE_BKP_ADDRESS" "Online Interface"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "GATEWAY" "$GATEWAY" "$COMPLIANCE_GATEWAY" "$GATEWAY_TPLT"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "NETMASK" "$SUBNET" "$COMPLIANCE_NETMASK" "$SUBNET_TPLT"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "DUPLEX MODE PRIMARY" "$FULLDUPLEX" "$COMPLIANCE_FULLDUPLEX" "Full Duplex"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "DUPLEX MODE BACKUP" "$FULLDUPLEX_BKP" "$COMPLIANCE_FULLDUPLEX_BKP" "Full Duplex"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "SPEED MODE PRIMARY" "$ETH_SPEED" "$COMPLIANCE_ETH_SPEED" "> 100 Mbps / Auto Negotiation"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "SPEED MODE BACKUP" "$ETH_SPEED_BKP" "$COMPLIANCE_ETH_SPEED_BKP" "> 100 Mbps / Auto Negotiation"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "DNS DOMAIN" "-" "$COMPLIANCE_DNS_DOMAIN" "DNS Configured"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "DNS SEARCH" "-" "$COMPLIANCE_DNS_SEARCH" "DNS Configured"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "NAME SERVER" "$DNS_SERVER" "$COMPLIANCE_DNS_SERVER" "Name Server Configured"
	tput bold
	printLog "+%-69.69s+%30.30s+\n"  "-----------------------------------------------------------------------" "------------------------------"
	printLog "|%-69.69s|%30.30s\n" "                     SOFTWARE SETTINGS SUMMARY"
	printLog "+%-69.69s+%30.30s+\n"  "-----------------------------------------------------------------------" "------------------------------"
	tput sgr0
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "DSMC" "-" "$COMPLIANCE_DSMC_STATUS" "TSM Configured" 
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "SENDMAIL" "-" "$COMPLIANCE_SENDMAIL" "Sendmail Configured"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "NTP SERVER1" "$NTP_SERVER1" "$COMPLIANCE_NTP_SERVER1" "NTP Configured"
	printLog "|%-25.25s|%30.30s|%25.25s|%30.30s|\n" "NTP SERVER2" "$NTP_SERVER2" "$COMPLIANCE_NTP_SERVER2" "NTP Configured"
	printLog "+%-69.69s+%30.30s+\n" "-----------------------------------------------------------------------" "------------------------------"
		
}

##########
#  MAIN  #
##########
clear

	LoadTemplate
		
	SolarisExceptions
	
	RootExecution
	
	GatherInformation
	[ $? -ne 0 ] && printLog "LOG_FILE: $(tput bold)$LOG_FILE $(tput sgr0)\n\n" && exit 1
	
	# LOG FILE
		
		printLog "\n\n\033[100;1m===============================================================\n"
		printLog "REPORT FILE: $LOG_FILE\n"
		printLog "===============================================================\033[00m\n\n"
				
		perl -e "s/\x1B\[([0-9]{1,3}((;[0-9]{1,3})*)?)?[m|K|B]//g" -p -i $LOG_FILE
		perl -e "s/\x1B\(B//g" -p -i  $LOG_FILE
