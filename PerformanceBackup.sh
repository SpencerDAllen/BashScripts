#!/bin/bash

# Spencer Allen
# June 1st 2013
# Performance backup

#### Declare variables
# Color strings
strGreen="\E[32m"
strYellow="\E[33m"
strRed="\E[31m"
strDefault="\033[0m"

# Label strings
strInfoLabel="echo -e $strGreen [INFO] $strDefault"
strWarnLabel="echo -e $strYellow [WARNING] $strDefault"
strErrorLabel="echo -e $strRed [ERROR] $strDefault"

# Normal Strings
strExclude="--exclude=./proc --exclude=./tmp --exclude=./mnt --exclude=./media --exclude=./dev --exclude=./sys "
strTargetDir=$(getent passwd $SUDO_USER | cut -d: -f6)"/"
strLogDest="/dev/null "
strFileName="$(hostname).tar.bz2"
strLogName="$(hostname)-Backup.log"

# Boolean flags
fDestUsed=0
fExcludeUsed=0
fThreadUsed=0
fTimeUsed=0
fLogUsed=0

# RegEx
iPositiveRE='^[0-9]+$'

#### Add functions
fnDestinationDir () {
	if [ "$fDestUsed" = "0" ]; then
		if [ -d $1 ]; then
			fDestUsed=1
			strTargetDir=$1
			if [[ $strTargetDir != *"/" ]]; then strTargetDir=$strTargetDir"/"; fi
			$strInfoLabel"The destination directory is " $strTargetDir
		else
			$strWarnLabel"The directory $1 does not exits using home directory"
		fi
	else
		$strWarnLabel"Sorry, only one destination directory can be used"
	fi
}

fnExclude () {
	if [[ "$1" != /* ]]; then
		$strWarnLabel$1" is not an absolute path and cannot be excluded."
	else
		if [ -d $1 ]; then
			fExcludeUsed=1
			strUserExclude=$strUserExclude"--exclude=.$1 "
			$strInfoLabel"Excluding directory " $1
		elif [ -f $1 ]; then
			fExcludeUsed=1
			strUserExclude=$strUserExclude"--exclude=.$1 "
			$strInfoLabel"Excluding file " $1
		else
			$strWarnLabel$1" cannot be excluded because it does not exist"
		fi
	fi
}

fnProcs () {
	if [[ $1 =~ $iPositiveRE ]]; then
		fThreadUsed=1
		strThreads=" -p"$1" "
		$strInfoLabel"Using the specified $1 processing threads"
	else
		$strWarnLabel"Invalid input, thread entry must be an interger"
	fi
}

fnTime () {
	fTimeUsed=1
	strFileName="$(date +%Y-%m-%d_%H:%M)-$(hostname).tar.bz2"
	strLogName="$(date +%Y-%m-%d_%H:%M)-$(hostname)-Backup.log"
}

fnLogging () {
	fLogUsed=1
	strLogDest="$strTargetDir$strLogName"
}

fnHelp () {
        echo -e \
"NAME:\n"\
"	Performance backup - a high performance backup script.\n\n"\
"SYNOPSIS:\n"\
"	PerformanceBackup.sh -d [options] -e [options] -p [options] -t -l -h\n\n"\
"DESCRIPTION:\n"\
"	Quickly creates a highly compressed tar backup of your entire system while providing\n"\
"	a progress bar for monitoring. For conveniance and to avoid errors certain root\n"\
"	directories are excluded from the backup by default and must be recreated when restoring\n"\
"	from the backup. They are as follows /proc /tmp /mnt /media /dev and /sys. Backup and log\n"\
"	files will be named HOSTNAME.tar.bz2 and HOSTNAME-Backup.log.\n\n"\
"PREREQUISITES:\n"\
"	This script must run as root and it requires the use of PV and PBZIP2 to complete it's tasks.\n"\
"	Please install them prior to running this script.\n\n"\
"OPTIONS:\n"\
"  -d		Used to specify the directory that the backup will be created in. This directory can\n"\
"		be local or remote. If this option is ommited the users home directory will be used.\n"\
"                Example: -d /backup/directory\n\n"\
"  -e		Used to exclude additional files or directories. The use of multiple exclude paths is\n"\
"		permissable. If this option is ommited only the default directories are ommited. Relitive\n"\
"		paths can't be excluded, provide absolute paths instead.\n\n"\
"		Example: -e /exclude\n"\
"		Excludes the /exclude directory\n\n"\
"		Example: -e /path/exclude.file\n"\
"		Excludes the exclude.file file in the /path directory.\n\n"\
"		Example: -e /first/exclude -e /second/exclude\n"\
"		Excludes both specified directories.\n\n"\
"  -p		Used to specify the number of processing threads to use for compression. If this option is\n"\
"		ommited the autodetected number of processors will be used or two processing threads\n"\
"		will be used if autodetect is not supported.\n"\
"		Example: -p 4\n\n"\
"  -t		Used to append a timestamp to the beginning of all files names. The timestamp will\n"\
"		appear as YYYY-MM-DD_HH:MM. If this option is ommited no timestamp will be added.\n"\
"		Example -t\n\n"\
"  -l		Used to create a log file of the backup process. Log files will be saved to the same\n"\
"		directory as the backup. If this option is ommited no log file will be created.\n"\
"		Example: -l\n\n"\
"  -h		Shows this Help menu.\n\n"\
"ADDITIONAL EXAMPLES:\n"\
"	Options can be used in conjuction with each other to provide granular control.\n\n"\
"	Example: -d /path/to/backup/directory -e ~/Music\n"\
"	This example will will place backup file in the directory /path/to/backup/directory and exclude\n"\
"	the directory ~/Music. Autodetection will be used to find the number of processing threads\n"\
"	to use or two processing threads will be used if autodetect is not supported. No timestamp will\n"\
"	be added in this example.\n\n"\
"	Example: -e ~/Music -p 4 -t -l\n"\
"	This example will place the backup and log files, named with a timestamp, in the users home\n"\
"	directory as well as excluding the directory ~/Music while using four proccessing threads for\n"\
"	compression."\ 
	exit 1
}

#### Check for requirments.
if [ $EUID -ne 0 ]; then $strErrorLabel"Only root can do that. Aborting."; fnHelp; fi
hash pv 2>/dev/null || { $strErrorLabel"I require pv but it's not installed.  Aborting."; fnHelp; }
hash pbzip2 2>/dev/null || { $strErrorLabel"I require pbzip2 but it's not installed.  Aborting."; fnHelp; }

#### Process arguments
while getopts d:e:p:tlh option
do
        case "${option}"
        in
		d) fnDestinationDir ${OPTARG};;
		e) fnExclude ${OPTARG};;
		p) fnProcs ${OPTARG};;
		t) fnTime;;
		l) fnLogging;;
		h) fnHelp;;
		\?) fnHelp;;
	esac
done

# Change directory to root...
pushd / 1>/dev/null

# Exclude backup file to prevent circular compression...
strExclude=$strExclude"--exclude=.$strTargetDir$strFileName "

# Checking for destination directory...
if [ "$fDestUsed" = "0" ]; then
	$strInfoLabel"No destination directory was specified using home directory " $strTargetDir
	$strInfoLabel"The backup file will be created at " $strTargetDir$strFileName
else
	$strInfoLabel"The backup file will be created at " $strTargetDir$strFileName
fi

# Checking for excluded directories or files...
if [ "$fExcludeUsed" = "0" ]; then $strInfoLabel"No additional exclude directories were specified using defaults"; fi

# Checking for processing thread limit...
if [ "$fThreadUsed" = "0" ]; then $strInfoLabel"No specific amount of processing threads were specified attempting to autodetect"; fi

# Checking for time appending...
if [ "$fTimeUsed" = "0" ]; then $strInfoLabel"No timestamp will be added to the filenames"; fi

# Checking for logging...
if [ "$fLogUsed" = "0" ]; then
	$strInfoLabel"No log file will be created"
else
	# Exclude log file to prevent circular compression...
	strExclude=$strExclude"--exclude=.$strLogDest "
	# Begin writing to log file...
	$strInfoLabel"A log file will be created at "$strLogDest
	echo -e "The backup file does not contain the following files or directories" > $strLogDest
	echo -e $strExclude$strUserExclude | sed -E 's/--.{8}\.//g' >> $strLogDest
	echo -e "Below is a list of everything that was included in your backup" >> $strLogDest
fi

# We're ready to run our command...
tar -cvpf - $strExclude$strUserExclude. 2>>$strLogDest | pv -s $(du -sb $strExclude$strUserExclude. 2>>/dev/null | awk '{print $1}') | pbzip2 -cf$strThreads> $strTargetDir$strFileName

$strInfoLabel"Script Finished!"
exit 0
