#!/bin/bash

# Spencer Allen
# June 1st 2013
# Performance backup

#### Declare variables
# Color strings
colRed="\E[31m"
colGreen="\E[32m"
colYellow="\E[33m"
colDefault="\033[0m"

# Strings
strDefaultExclude="--exclude=./proc --exclude=./tmp --exclude=./mnt --exclude=./media --exclude=./dev --exclude=./sys"
strTargetDir=$(getent passwd $SUDO_USER | cut -d: -f6)"/"
strLogDest="/dev/null "
strFileName="$(hostname).tar.bz2"
strLogName="$(hostname)-Backup.log"

# Boolean
booDestUsed=0
booExcludeUsed=0
booThreadUsed=0
booTimeUsed=0
booLogUsed=0

# Label strings
labInfo="$colGreen [INFO] $colDefault"
labWarn="$colYellow [WARNING] $colDefault"
labError="$colRed [ERROR] $colDefault"

#### Add functions
DestinationDir () {
	if [ -d $1 ]; then
		booDestUsed=1
		strTargetDir=$1
		if [[ $strTargetDir != *"/" ]]; then
			strTargetDir=$strTargetDir"/"
		fi
		echo -e $labInfo"The target directory is " $strTargetDir
	else
		echo -e $labError"The directory $1 does not exits using home directory"
	fi
}

ExcludeDirs () {
	if [ -d $1 ]; then
		booExcludeUsed=1
		strUserExclude=$strUserExclude"--exclude=.$1 "
		echo -e $labInfo"Excluding directory " $1
	else
		echo -e $labWarn $1" cannot be excluded because it does not exist"
	fi
}

Procs () {
	if [ "$1" -eq "$1" 2>/dev/null ]; then
		booThreadUsed=1
		strThreads=" -p"$1" "
		echo -e $labInfo"Using the specified $1 processing threads"
	else
		echo -e $labError"Invalid input, thread entry must be an interger"
	fi
}

Time () {
	booTimeUsed=1
	strFileName="$(date +%Y-%m-%d_%H:%M)-$(hostname).tar.bz2"
	strLogName="$(date +%Y-%m-%d_%H:%M)-$(hostname)-Backup.log"
}

Logging () {
	booLogUsed=1
	strLogDest="$strTargetDir$strLogName"
	strUserExclude=$strUserExclude"--exclude=.$strLogDest "
}

Help () {
	echo -e \
"NAME:\n"\
"	Performance backup - a high performance backup script.\n\n"\
"SYNOPSIS:\n"\
"	PerformanceBackup.sh -d [options] -e [options] -t [options] -l \n\n"\
"DESCRIPTION:\n"\
"	Quickly creates a highly compressed tar backup of your entire system while providing\n"\
"	a progress bar for monitoring.\n"\
"	For conveniance and to avoid errors certain root directories are excluded from the\n"\
"	backup by default.\n"\
"	These directories must be recreated when restoring from the backup.\n"\
"	The default excluded directories are /proc /tmp /mnt /media /dev and /sys\n"\
"	Backup files will be named HOSTNAME.tar.bz2\n"\
"	Log files will be named HOSTNAME-Backup.log\n\n"\
"PREREQUISITES:\n"\
"	This script must run as root and it requires the use of PV and PBZIP2 to complete it's tasks.\n"\
"	Please install them prior to running this script.\n\n"\
"OPTIONS:\n"\
"  -d		Used to specify the directory that the backup will be created in.\n"\
"		This directory can be local or remote.\n"\
"		If this option is ommited the users home directory will be used.\n"\
"                Example: -d /path/to/backup/directory\n\n"\
"  -e		Used to exclude additional directories, files, or patterms.\n"\
"		The use of multiple exclude paths is permissable.\n"\
"		If this option is ommited only the default directories are ommited.\n\n"\
"		Example: -e /directory/to/exclude\n"\
"		Excludes the /directory/to/exclude directory\n\n"\
"		Example: -e /path/to/file/to.exclude\n"\
"		Excludes the to.exclude file in the /path/to/file directory.\n\n"\
"		Example: -e /path/to/file/*.exclude\n"\
"		Excludes all files ending in .exclude found in the /path/to/file directory\n\n"\
"		Example: -e /path/to/first/exclude -e /path/to/second/exclude\n"\
"		Excludes both specified directories.\n\n"\
"  -p		Used to specify the number of processing threads used for compression.\n"\
"		If this option is ommited the autodetected # of processors will be used.\n"\
"		(or 2 processing threads will be used if autodetect is not supported).\n"\
"		Example: -p 4\n\n"\
"  -t		Used to append a date timestamp to the beginning of all files names.\n"\
"		The date timestamp will appear as YYYY-MM-DD_HH:MM.\n"\
"		If this option is ommited no date timestamp will be added.\n"\
"		Example -t\n\n"\
"  -l		Used to create a log file of the backup process.\n"\
"		Log files will be saved to the same directory as the backup.\n"\
"		If this option is ommited no log file will be created.\n"\
"		Example: -l\n\n"\
"  -h		Shows this help menu.\n\n"\
"ADDITIONAL EXAMPLES:\n"\
"	Options can be used in conjuction with each other to provide granular control.\n\n"\
"	Example: -d /path/to/backup/directory -e ~/Music\n"\
"	This example will will place backup file in the directory /path/to/backup/directory\n"\
"	and exclude the directory ~/Music. Autodetection will be used to find the number\n"\
"	of processing threads to use (or 2 processing threads will be used if autodetect\n"\
"	is not supported)\n\n"\
"	Example: -e ~/Music -p 4 -l\n"\
"	This example will place the backup and log files in the users home directory as well as\n"\
"	excluding the directory ~/Music while using four proccessing threads for compression."\ 
	exit 1
}

# Check for requirments.
if [ $EUID -ne 0 ]; then
	echo -e $labError"Only root can do that. Aborting."
	Help
fi
hash pv 2>/dev/null || { echo -e $labError"I require pv but it's not installed.  Aborting."; Help; }
hash pbzip2 2>/dev/null || { echo -e $labError"I require pbzip2 but it's not installed.  Aborting."; Help; }

#### Process arguments
while getopts d:e:p:tlh option
do
        case "${option}"
        in
		d) DestinationDir ${OPTARG};;
		e) ExcludeDirs ${OPTARG};;
		p) Procs ${OPTARG};;
		t) Time;;
		l) Logging;;
		h) Help;;
		\?) Help;;
	esac
done

# Change directory to root...
pushd / 1>/dev/null

# Check for a destination directory...
if [ "$booDestUsed" = "0" ]; then
	echo -e $labInfo"No target directory was specified using home directory " $strTargetDir
	echo -e $labInfo"The backup file will be created at " $strTargetDir$strFileName
else
	echo -e $labInfo"The backup file will be created at " $strTargetDir$strFileName
fi

# Check for excluded directories...
if [ "$booExcludeUsed" = "0" ]; then
	echo -e $labInfo"No additional exclude directories were specified using defaults"
fi

# Check for processing thread limit
if [ "$booThreadUsed" = "0" ]; then
	echo -e $labInfo"No specific amount of processing threads were specified attempting to autodetect"
fi

# Check for time appending
if [ "$booTimeUsed" = "0" ]; then
	echo -e $labInfo"No date time stamp will be added to the filenames."
fi

# Check for logging...
if [ "$booLogUsed" = "0" ]; then
	echo -e $labInfo"No log file will be created"
else
	echo -e $labInfo"A log file will be created at "$strLogDest
	echo -e "The backup was created with the following tar command" > $strLogDest
	echo -e "It is included here for use as a reference when rebuilding from your backup" >> $strLogDest
	echo -e "tar -cjpf --exclude=.$strTargetDir$strFileName $strDefaultExclude $strUserExclude" >> $strLogDest
	echo -e "Below is a list of everything that was included in your backup" >> $strLogDest
fi

# We're ready to run our command...
tar -cvpf - --exclude=.$strTargetDir$strFileName $strDefaultExclude $strUserExclude. 2>>$strLogDest | pv -s $(du -sb --exclude=.$strTargetDir$strFileName $strDefaultExclude $strUserExclude. 2>>/dev/null | awk '{print $1}') | pbzip2 -cf$strThreads> $strTargetDir$strFileName

echo -e $labInfo"Script Finished!"
exit 0
