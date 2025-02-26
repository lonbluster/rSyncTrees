#!/bin/bash
#feb25
#set -x
custom_config=/etc/rsynctrees
##Always better to have the config file in place with the variables shown on the help.
##All colors with names
RED=$'\e[31m'
BLUE=$'\e[36m'
hdROSE=$'\e[38;5;204m'
GREEN=$'\e[32m'
U_LINED=$'\e[1;4m'
RESET=$'\e[0m'
INVERT=$'\e[7m'
YELLOW=$'\e[93m'
quick="\n Available options for >rSyncTrees: \n \
	du/due/duA/dup : Disk Usage \n \
	clean [path]: serial killer \n \
	old [pattern]: manage and remove previous versions \n \
	Rs : Restore files and directories \n \
	rp/Rrp : Recovery point creation and restore \n \
	exlogs : expire logs in config dir \n \
	speed : write test to Storage \n \
	help : activates help if was off \n \
	-* : (man rsync Options :-) runs faster than with no options \n \
	[/valid/path]..." 

[[ -f "$custom_config" ]] && source $custom_config

if [[ -d "$STORAGE" ]] ;  
	then rsync_root=$(echo $STORAGE | sed 's:/*$::') ; 
#if STORAGE is set, variable is set withouth trailing /
#sed could be replaced by "echo ${STORAGE%/}"
#2 alternative storages, and 1 extra var, and HOME
	else  
		if [[ -d "$otherStorage" ]]; then
			rsync_root=$otherStorage; 
		else		
			rsync_root=${HOME}/backup; 
		fi
fi



if [[ -z "$rstHOME" ]] || [[ ! -d "$rstHOME" ]] || [[ ! -w "$rstHOME" ]]; then 
	rstHOME=$HOME/rSyncTrees ; 
	if [[ ! -d "$rstHOME" ]]; then mkdir $rstHOME ; fi
fi
# Check write acces on Config dir/Create the config dir specified on the config file, or as subfolder in Home , 
# Default transfer size for speed measurement from $custom_config (/etc/rsynctrees)
if [[ -z "$ttestMb" ]]; then 
ttestMb=555; 
fi

backup_root=${rsync_root}/$(hostname)
month=$(date +%m.%Y)
starthour=$(date +%d%h_%H:%M)
bkdate=$(date +.rST_%d%h_h%H)
#gbFree=$(df -h $rsync_root | awk '{print $4}')
lastmonth=$(date --date='-1 month' +'%m.%Y')

####Interactive#########################
#if Rsync and bash and nano do not start well on SMB fs , better changing base dir. cd $HOME
if tty -s ; then clear && cd $HOME;
#set -x
#check if the storage is set
	if [[ ! -d "$rsync_root" ]] && [[ ! -d "$STORAGE" ]] ; then 
	
#if the backup folder has been deleted or STORAGE is not set
#list available file systems on their mountpoints, with % available and GB remaining
		df -H --output=target,pcent,avail,source
		echo -e "\n - Input your capient $RED$U_LINED STORAGE FOLDER $RESET full path, \n - or type $U_LINED backup $RESET for /home/you/backup... \n - or run as root to enable otherStorage in $custom_config. \n"
		read -e -r store 
	#read variable
			if [[ -n "$store" ]]; then  
		#or- if [[ ! -z ${store} ]] ?
#if input is given
#and is a valid path , create necessary subdirs and refresh previous vars, or show invalid message
				if [[ "$store" == backup ]]; then  
					echo "Setting backup on home directory " ; rsync_root=${HOME}/backup;  backup_root=${rsync_root}/$(hostname) ; mkdir -pv $backup_root; sleep 3; 
				elif [[ ! -d "$store" ]]; then echo "$YELLOW $store is not valid... U&e!"; exit;
				elif [[ -d "$store" ]]; then  #and is a valid directory
				rsync_root=$(echo $store | sed 's:/*$::'); backup_root=${rsync_root}/$(hostname) && mkdir -v $backup_root; sleep 2
				echo STORAGE=${store} >> ${custom_config};
				fi
			else echo -e "Input something or set $GREEN $custom_config. $YELLOW U&e!$RESET" && exit
			fi
	elif [[ ! -d "$backup_root" ]]; then mkdir -v $backup_root; 
	fi
#
fi
####Interactive#########################

sync_dir=${backup_root}/$month 
if [[ ! -d $sync_dir ]] ; then 
	mkdir -v $sync_dir ; sleep 1
fi
#monthly dir needs be created
# the other 2 will eventually be created by rsync
extras=${backup_root}/extras
previous=${backup_root}/previous

cleaner ()
			{
			echo -e "$hdROSE"r"$RESET""$GREEN""$U_LINED"Sync"$RESET"{"$BLUE"Back,Clean,"$RED"Rest"$RESET"}{"$GREEN"up,"$GREEN"ore"$RESET"}
			echo -e "$hdROSE"@@"$RESET""$GREEN"Sync"$RESET"{"$BLUE"Back,"$YELLOW"Clean,"$RED"Rest"$RESET"}{"$GREEN"%%,"$YELLOW"##"$RESET"}
##banner colored
## function to input  new dir, or setting default
			prompt ()	
				{
					echo -e "\r"
					echo "newdir:$newdir"
					echo "cleandir:$cleandir"

					if [[ -z "$cleandir" ]] || [[ ! -d "$cleandir" ]]; then
						if [[ -f "$newdir" ]]; then echo "Selecting container directory of input file.." ; cleandir=$(dirname $newdir); 
						elif [[ -d "$newdir" ]]  ; then cleandir=$newdir; 
						else read -r -p "(quit with q) Enter or Input to change current $RED $cleandir #>" -e newdir; fi
						if [[ -z $newdir ]]; then echo "Invalid dir, selecting your storage.."; cleandir=$backup_root; fi
						fi
							#	elif [[ ! -d "$newdir" ]] || [[ ! -f "$newdir" ]]; then echo -e "Invalid Path:$GREEN$newdir$RESET"; 
								
					#elif [[ -f "$newdir" ]]  ; then echo "Selecting container directory" ; cleandir=$(dirname $newdir); fi
				echo "max 10 seconds for space calculation.."&& timeout 10 du -sh $cleandir && du -sh $cleandir/*|| ls -lha $cleandir;
				}
					#echo "Selezione da linea $2"
					#if [[ $newdir == 'q' ]]; then exit; fi
				#}
							
			if [[ -d "$1" ]]  || [[ -f "$1" ]]; then cleandir=$1; else newdir=$1; fi

			while [[ $newdir != 'q' ]]; do
			prompt
# unless  you quit return to  prompt
# remove trailing  and show size
			cleandir=$(echo $cleandir | sed 's:/*$::'); 				
				echo -e "\r $RESET"
				#list () {
				#find ${cleandir} -maxdepth 1 -type d,f
					#echo $cleandir
				#	}
				#echo "wait...max 10 seconds" && list
				echo -e "\r $RED"
				sleep 2
				COLUMNS=1
				PS3=$(echo -e "\r$RESET"; REPLY=''; echo -e "\n Select and destroy :enter Number\n ..or paste new Path to select.. $BLUE#")
				IFS=$'\n';
					select item in $( find ${cleandir} -maxdepth 1 -type d,f ) 
					# max 9 spaces in file name!!
					#select item in $(du -sh $cleandir/*| awk -F '\n';{print $2}')
					#select item in $(find ${cleandir} -maxdepth 1 -type d,f );  #| sort -hk1| awk '{print $2}'
					do 	
					#item=$(echo $item | sed -e 's/[[:space:]]*$//g')
						if [ -f $REPLY ] || [ -d $REPLY ]; then newdir=$REPLY; cleandir=$REPLY; break; fi
						echo -e "\r"
						echo -e "Content of selection $REPLY:-$item :"
						ls -la $item #show hidden items in directory
						echo -e "$hdROSE"
						#du -sh $item
						echo "Wiping the above? Enter to CLEAN"
						read
						sleep 1
						echo -e "$RESET"
						if [[ -d $item ]] || [[ -f $item ]] ; then # cleandir= $(dirname $item); echo "cleandir: $cleandir"
						rm -rf $item && echo "Something was performed..."; 
						else echo "Invalid input"; fi
						sleep 1
						echo -e "\r $BLUE"
					break
					done
			done
			}

###################Interactive#########
if tty -s; then 

	if [ -n "$1" ]; then echo -e "\r $U_LINED..rSyncTrees cmd Options..$RESET "
		
		case $1 in
		-*)
		argu=$1
		;;

		duA)
			echo -e "$hdROSE Disk usage for Machine trees in $YELLOW $backup_root :"
			ls -lh $backup_root
			echo -e "\r $BLUE"
			echo "Calculating sizes...4s"
			for dir in $(ls -d ${backup_root}/*/ | sed 's:/*$::'); do 
				timeout 4 du -sh ${dir}/* || echo "THICK:"$dir ;
			done | sort -hk1; 
			echo -e "\r $RESET"
			exit
			;;
		dup)
			echo -e " $hdROSE Disk usage for Previous versions \r$RESET $YELLOW \v $previous"
			ls -lh $previous
			echo -e "\r $BLUE"
			echo "Calculating sizes...7s"

			for dir in ${previous}/*; do
				timeout 7 du -sh $dir || echo "THICK:"$dir ; 
			done | sort -hk1
			echo -e "\r $RESET"
			exit
			;;
		due)	
			echo -e " $hdROSE Disk usage for the Extras tree \r$RESET $YELLOW \v $extras"
			ls -lh $extras
			echo -e "\r $BLUE"
			echo "Calculating sizes...7s"
			for dir in ${extras}/* ${previous}/extras/*; do
				timeout 7 du -sh $dir || echo "THICK:"$dir ; 
			done | sort -hk1
			echo -e "\r $RESET"
			sleep 1
			exit
			;;
			
		du)
			echo -e " $hdROSE Disk usage for the Sync tree \r$RESET $YELLOW \v $sync_dir"
			ls -lh $sync_dir
			echo -e "\r $BLUE"
			echo "Calculating sizes...max 9s per THICK folder "
		
			for dir in ${sync_dir}/*; do
				timeout 9 du -sh $dir || echo "THICK:"$dir ; 
			done | sort -hk1
			echo -e "\r $RESET"
			exit
			;;
			
		exlogs)
			read -r -p "$YELLOW ...Enter to keep latest 15 logs only in .tgz ?$RESET"
			mv ${rstHOME}/exLogs.tgz ${rstHOME}/${starthour}_exLogs.tgz 
			cd ${rstHOME} &&	ls -t ./Bkup_date-* | head -15 | xargs tar -cz -f ${rstHOME}/exLogs.tgz && rm ${rstHOME}/Bkup_date-*.log
			echo -e "Previous tar list: $hdROSE"
			tar --list -f ${rstHOME}/${starthour}_exLogs.tgz
			echo -e "$RESET Compressed tar list exLogs.tgz: $hdROSE"
			tar --list -f ${rstHOME}/exLogs.tgz
			echo -e "$RESET Config Dir: $YELLOW ${rstHOME}"
			echo -e "Content: $RED"
			du -h ${rstHOME}/*
			echo -e "$RESET"
 			exit
			;;
			
		old)
			#set -x
			week1="_0[1-9]"
			#if [ -d $2 ] && [[ $2 != "." ]]; then previous=$2; fi
			echo -e "$YELLOW Find previous versions. Enter for default filters ! \n$RESET !avoid multiple filters for faster results"
			echo -e "\r $YELLOW"
			
				if [[ -n $2 ]]; then 
#if the filter was given on command line
					filter=$2; 
				else
					echo -e "$YELLOW $U_LINED any $RESET$YELLOW string to match...\n$GREEN@ _1[0-2] for day 10 to 12 @\n@ _[0-1][0-9] for day 01 to 19 @ \n@ _[0-3]1 for days 01,11,21,31 @ $RESET"

					read -e filter
				fi
			echo -e "any specific day of month...? $RESET"; 
			read -t 5 day
			echo -e "$YELLOW Finding previous versions...\n"
	
			oldmatch=*_[0-3][0-9]*_h*
			#too vague, should be more specific  
			match=*.rST_*
			
			echo -e "...using find match $GREEN $match $RESET"
			if [[ -n $filter ]]; then echo -e "..using grep filter $GREEN $filter $RESET"; fi 

			sleep 1
			#if [ -z $filter ]; then match="$previous"; fi
			echo "$RED Remove? y and Enter... $RESET"
			read -t 3 remove
			echo -e "\r $GREEN Searching $previous... $RESET"

			found ()
			{
			 find $previous -type f -name "$match"
			}
			
	 		_filter=$filter
		if [[ $remove =~ ^[Yy]$ ]]; then
				if [[ -z $filter ]]; then echo "Use string match for removing stuff."; exit; 
				else
					for item in $(found|grep $_filter); do
						echo -e "$GREEN REMOVING $item $RESET"; rm -vf $item; 
					done
				fi
		else 
			if [[ -z $day ]] && [[ -z $filter ]]; then 
	#if both filter and day are not set			
			echo "Listing all previous files"; sleep 2; 
			found;
			fi
			if [[ -z $day ]] && [[ -n $filter ]]; then 
	#if day is not set and filter is
			echo -e "..using grep filter $GREEN $filter $RESET"; sleep 2;
			found |grep $_filter;
			fi
			if [[ -n $day ]] && [[ -z $filter ]]; then 
	#if day is set and filter is empty
				echo -e "..using grep filter $GREEN _$day $RESET"; sleep 2;
				found |grep _$day;
			fi
			if [[ -n $day ]] && [[ -n $filter ]]; then
	#if both are set
			echo -e "..using grep filter $GREEN $filter $RESET"
			echo -e "..using grep filter $GREEN _$day $RESET"; sleep 2;
			found | grep $_filter | grep _$day ; 
			fi
		fi
		# echo "$RED Remove files older than 2 months? y or n.# of months to keep Enter... $RESET"
		# read -t 3 removeold
		# echo -e "\r $GREEN Searching and Deleting old files $previous... $RESET"
				# sleep 3
			# if [[ $removeold =~ ^[Yy]$ ]]; then
						# matchOld=
			# OldFiles ()
			# {
			 # find $previous -type f -name "$matchOld"
			# }
					# for item in $(OldFiles|grep $_filter); do
						# echo -e "$GREEN REMOVING $item $RESET"; rm -vf $item; 
					# done
			# fi
					exit
					;;
	
		clean) 
		IFS="";
			if [[ -n $2 ]]; then cleanPath=$2;fi
			cleaner $cleanPath
			;;

		Rs) 
			Rs=1
			if [ -n $2 ]; then cmd_path=$2; fi
			;;
			 
		rp) echo -e "\r"
			echo -e "..creating the Restore Point of $INVERT"
			timeout 5 du -sh $sync_dir 
			echo -e "$RESET \r................to :"
			echo -e "$RESET\n $hdROSE $backup_root$bkdate.tar.gz $RESET"
			echo -e "\r"
			df -h $backup_root 
			echo -e "\r"
			read -r -p "Enter to continue.. S/s and Enter to run sync first." -e sync_first
			echo -e "\r"
			read -r -p "$BLUE Optional arguments for Tar ( -v -S ) ?:" -e tararg
			echo -e "\r"
#rSyncTrees should exist in path
			if [[ $sync_first =~ ^[Ss]$ ]]; then echo -e "\n$RED Stand by to update sync $RESET"; nohup rSyncTrees && wait ; echo "Sync Complete..beginning compression.." && sleep 3; fi
			cd $backup_root && tar $(echo $tararg) -cz -f "$(hostname)_$bkdate.tar.gz" $month
			echo -e "\r$RED There you have it in $GREEN $backup_root $RESET"
			ls -lh $backup_root | sort -hk5
			echo -e "\r$RESET"
			exit
			;;
			
		Rrp)
			echo -e "\r"
			PS3=$(echo -e "$RESET \n ###### Where to restore form ? \n- Number and Enter to select.. $RED#")
			select tar in $(ls ${backup_root}/*tar.gz); do
				read -e -r -p "Where to restore TO - Enter to restore?" untardir
				if [[ ! -d $untardir ]]; then 
					echo "No dir chosen...selecting Storage restore!!"
					untardir="$backup_root"
					read  -p "Sure to overwrite S/s?" -e confirm
				fi
				if [[ -d $untardir ]] || [[ $confirm =~ ^[Ss]$ ]]; then
					tar -xv -f $tar -C $untardir
					echo "#####################" 
					echo "Untar Complete" 
					exit
				else echo "Overwrite not confirmed.";
				exit
				fi			
			done
			;;

		speed)  
			if [ -w "$rsync_root" ]; then 
				echo -e "$hdROSE..running backup Speed test... do NOT cancel now!..please" 			
				echo -e "$hdROSE..Starting with 234 mb.." 
				fallocate -l 234M transfer.test; sleep 3; 
				rsync -h transfer.test $rsync_root --progress ; sleep 3; rm transfer.test; rm ${rsync_root}/transfer.test 
				echo -e "$RED..then with $ttestMb mb.." 
				fallocate -l "$ttestMb"M transfer.test2; sleep 3; 
				rsync -h transfer.test2 $rsync_root --progress --modify-window=1 ; sleep 3; rm transfer.test2; rm ${rsync_root}/transfer.test2; sleep 7
			else echo "Access Denied...Check folder ownership."; exit; 
			fi 
				#echo -e "\r\e[0m   ..exclude?:"
			;;

		help) 
			HELP=on
			;;
				
		*) 	if [[ -d $1 ]] || [[ -f $1 ]] || [[ "$1" == *@*:* ]]; then 
				cmd_path=$1; 
			else
			echo -e  "\n Is this a valid path?:$YELLOW[$1]$RESET I don't know this option... yet! $hdROSE" $quick && exit 1;
			fi	
		esac 
	fi
fi
###################Interactive#########
#set -x
###Interactive#########################
if tty -s; then clear;
#Starting main header
#Checking if disk space is enough
#if $minGb is not set on the config file, if less than 9Gb will trigger the warning
#type ync >/dev/null 2>&1 || { echo >&2 "rsync is installed in your linux?"; exit 1}

	echo -e "$RED##############Backup destination: $GREEN $backup_root"
	gbFree=$(df -h $sync_dir | awk '{print $4}')
	if [[ ${gbFree//[^0-9]/} -lt ${minGbfree:-9} ]]; then echo "$hdYELLOW $U_LINED !! Disk space < ${minGbfree:-9}G !!$RESET"; fi
	echo -e "\r $RESET"
	df -H --output=source,pcent,avail,target $rsync_root 
#inform about storage and file system
#check storage is writable, then show the PID, and sourced files 
	echo -e '\r'
	if [[ ! -w "$sync_dir" ]]; then echo -e "Storage write $INVERT access DENIED $RESET";fi
	echo "rSyncTreesPID:"$$
	echo "Inc/Exclusion and log files from and to ${rstHOME}/*"
	if [ -f "${custom_config}" ]; then
	echo "Reading custom settings from ${custom_config}"; fi
fi
###Interactive#########################
#
##
#-####HELP

HELPless=("# rSyncTrees.sh
### :+1: Created on BackBox (Ubuntu), tested in Debian, Suse, CentOS, Windows-SL, Pfsense, Google cloud, etcetera.. :+1:

--------Q and backup.Press Q or q. Q and Enter 2 or more times to backup.---------
Q to quit this Help and continue to backup.

Find full doc on the README.md or at
https://github.com/lonbluster/rSyncTrees.git

@@@@@@@@@@This message will be disable when HELP=off in /etc/.rsynctrees.

#Requirements for rSyncTrees
#'Rsync' should be installed! And 'Bash' too! 
#Also 'mailx' if you mind to configure the mail sending variables.

Enjoy Trees!
"
)

if ! [ -x "$(command -v rsync)" ]; then
  echo -e "\n \n $U_LINED -- Error: rsync is not installed. -- $RESET\n Maybe:  \n sudo apt install rsync \n ;-)  \n \n" >&2
  exit 1
fi

#-####HELP
##
#set -x
prompt_dir()
	{
	if [[ "$Rs" != 1 ]]; then
		if [[ -z "$cmd_path" ]] ; then  
#-displaying Backup prompt...  if it wasn't given on command line
			echo -e "$RED #### -2-  Ctrl-C to quit any moment - Enter or Input&Enter \n \
 $U_LINED Just Enter ! $RESET  ...or input Any full $U_LINED PATH TO BACKUP $RESET...and Enter.  \n \
 @-HELP: /etc/dir > /etc/dir/-@\n  \
 @-Remote and Wildcard for one-time backup only.-@ \n  \
 @-Remote user@machine:/home/*-@$GREEN \n" 
			read -e extradir 
			else extradir=$cmd_path
		fi
	elif [[ -n "$cmd_path" ]]; then extradir=$cmd_path; 
#use the path for backup if given, skipping the prompt

#-displaying Restore input prompt, with recent backups
	else 
	recent=$(find $rstHOME -name "Bk*"  -print0 | xargs -r -0 ls -1 -t | head -3)
	#grep -o "date-*-*.*"
	echo -e "Latest backups $RED\v ${recent}"
	echo -e "$RESET Input $U_LINED PATH TO RESTORE $RESET \n @! Not from the storage !@"
	read -e extradir 
	fi
	}
#echo $extradir
#echo $extradir

#exit
#creating function for checking the input dir
list_bytes()
	{
		IFS=''
	extradir=$(echo $extradir | echo "${extradir%/}")  
##Rules out the input of / alone, and cleans trailing
#unless provided on command line, a restore path needs be seized
	while [[ -z "$extradir" ]] ; do 
		echo "Input something specific"; prompt_dir; 
	done	
	
	if [[ "$Rs" == 1 ]]; then
		while [[ ! -f "$extradir" ]] && [[ ! -f ${sync_dir}/"$extradir" ]] && [[ ! -f ${extras}/"$extradir" ]] && [[ ! -f ${previous}/"$extradir" ]] && [[ ! -d "$extradir" ]] && [[ ! -d ${sync_dir}/"$extradir" ]] && [[ ! -d ${extras}/"$extradir" ]]  ; do 
			echo -e "$RED ${extradir} $RESET: No File or Directory found on Storage or System."; exit
					#unset extradir; unset cmd_path; unset 2; unset 1; prompt_dir  #
		done
#check the presence of the file somewhere, in all storage trees, and on running system
#check that a full path was given, U&e! ...this will need be repeated for Full backups later on.
		while [[ ! "${extradir}" = /* ]] || [[ "${extradir}" = . ]]; do 
			echo "Always use full local paths !!";  echo "$RED $extradir invalid...U&e! $RESET"; exit  
		done
	fi
#set -x	
	echo -e "$GREEN Listing Bytes...";
	if [[ -d "$extradir" ]] || [[ -d ${sync_dir}/"$extradir" ]] || [[ -d ${extras}/"$extradir" ]]; then 
			echo -e "\r Listing DIR to restore"
			for dir in ${extradir}/*; do
			timeout 3 du -sh $dir || echo "THICK:"$dir ; 
			done | sort -hk1
			echo -e "\r $RESET"
			echo -e "\r"
			echo -e "$U_LINED++Selected on current system:$RESET"
			timeout 3 du -sh $extradir || ls -d $extradir
			echo -e "$GREEN$U_LINED++Same directory synchronized on Storage:$RESET"
			if [[ -d ${sync_dir}$extradir ]]; then timeout 10 du -sh ${sync_dir}$extradir || ls -d ${sync_dir}$extradir; fi
			echo -e "$RED"
			echo -e "$U_LINED++Previous versions: $RESET$RED"
			if [[ -d ${previous}$extradir ]]; then timeout 10 du -sh ${previous}$extradir || ls -d ${previous}$extradir ; fi
			if [[ -d ${previous}/extras"$extradir" ]]; then timeout 10 du -sh ${previous}/extras"$extradir" || ls -d ${previous}/extras"$extradir"; fi
			if [[ -d ${backup_root}/${lastmonth}$extradir ]]; then timeout 10 du -sh ${backup_root}/${lastmonth}$extradir || ls -d ${backup_root}/${lastmonth}$extradir; fi
			echo -e "$RED"
			echo -e "$U_LINED++Extra copies: $RESET$RED"			
			if [[ -d ${extras}$extradir ]]; then timeout 10 du -sh ${extras}$extradir || ls -d ${extras}$extradir ; fi
					echo -e "$RESET"
#show all versions found for the same dir
#and all versions for the same file
		else 
			echo -e "\r Listing FILE to restore"
			echo -e "\r"
			echo -e "$RESET $U_LINED++On current system: $RESET"
			ls -lh ${extradir}*; 
			echo -e "$GREEN$U_LINED++Same file synchronized on Storage:$RESET"
			if [ -f ${sync_dir}$extradir ];then 
				ls -lh ${sync_dir}$extradir;
				echo -e "\r $RED"
				echo -e "$U_LINED++Previous and Similar:$RESET$RED"
				[ -f ${previous}${extradir} ] && ls -lh ${previous}${extradir}*; 
				[ -f ${previous}/extras${extradir} ] && ls -lh ${previous}/extras${extradir}*; 
				[ -f ${backup_root}/${lastmonth}${extradir} ] && ls -lh ${backup_root}/${lastmonth}${extradir}*;
			fi	
			echo -e "$U_LINED++Extra:$RESET$RED"
			if [ -f ${extras}$extradir ];then ls -lh ${extras}$extradir; fi
			echo -e "$RESET"
		fi
}
#end list_bytes function
#set -x

			
if [[ $1 =~ ^[/]$ ]] || [[ $1 =~ ^[.]$ ]]; then
	echo $' \n Backup of / will be done on Full backup, with standard exclusions.  \n Please input something more specific...or no arguments for Full backup. \n '; exit
	fi
#inform command line  argument needs be a full path
##############Interactive##############
if tty -s; then
		if [[ ! $UID -eq "0" ]]; then  #if root account
			echo -e "!!AAA!! You are $INVERT NOT root $RESET,$RED Full backup will not run... !!AAA!! $RESET \n"; fi
		prompt_dir
#check if root and display prompt	
#and help display, unless disabled on config file
		if [[ ! $HELP == "off" ]]; then echo -e "$RED"; echo -e "$HELPless" "$quick" | less ; fi
	
########
############
###############----RESTORE ---###########################################################
	if [[ $1 == "Rs" ]]; then 

		echo -e "\r $BLUE"
		cal -3
		echo -e "\r $RESET"
		echo "##RESTORE MODE##"
#shows the calendar for 3 months
#exit if the path includes the storage path (suffixes as well should be matched in future)
			if [[ $2 =~ ${backup_root}/* ]]; then 
				echo -e " Did you mean $YELLOW $(echo $2 | grep -oP "^${backup_root}\K.*") ? \n Please remove the Storage path and suffixes as well. $RESET"; 
				exit
			fi
#check if other copies are in other storages
			old_sync_dir=$sync_dir
			old_extras=$extras
			old_previous=$previous
			old_backup_root=$backup_root
			if [[ -n "$otherStorage" ]] && [[ -d "$otherStorage" ]]; then 
				echo -e " $YELLOW---- Selecting OTHER backup storages ----$RESET";
				sync_dir=$otherStorage/$(hostname)/$month
				extras=$otherStorage/$(hostname)/extras
				previous=$otherStorage/$(hostname)/previous
				backup_root=$otherStorage/$(hostname)
				echo -e "$RED $backup_root $RESET";
#replace list_bytes variables before executing, and after
				list_bytes; 
				echo -e "$YELLOW---- Change default backup storage to restore the above ! ----";
				echo -e "\r --------------------------$RESET";
			fi
			sync_dir=$old_sync_dir
			extras=$old_extras
			previous=$old_previous
			backup_root=$old_backup_root
			#set -x
			echo -e "\r"
#list restorable from current storage
			echo -e " ======== Selecting CURRENT storage ======== $RESET"
			echo -e "\r $backup_root";
			echo -e "\r"
			list_bytes
			echo -e "========  ========"
				echo -e "\n Let s move on to restore one of those...\n$RESET Enter to continue to restore the current system,\n or input alternative $U_LINED RESTORE TARGET:$RESET$GREEN" 
				read -e restore_fs ; 	
				echo -e "$RED####################Ok, choose the right one, then..."
				if [[ ! -d "$restore_fs" ]] ; then 
					if [[ -d "$extradir" ]]; then restore_fs=$(dirname ${extradir});
#unless a different backup destination was given
#the input extradir will now be the rsync destination
					elif [[ -f "$extradir" ]]; then	restore_fs=${extradir};
					fi
				fi
				
				Select_version()
					{
					PS3=$(echo -e "$RESET \n ###### Where to restore form ? \n- Number and Enter to list content..Q/q to break $RED#")
					if [[ ! -d "${sync_dir}${extradir}" ]] && [[ ! -d "${extras}${extradir}" ]] ; then
#unless they are in the sync or extra trees
#directories don't have backup suffixes, so restoring them would insert all old files, Avoiding selection for those.
					extradir=$(echo $extradir | sed 's:/*$::')
						if [[ -d "$extradir" ]]; then 
							echo "No Previous copies for Directories. Retry with a file instead."; exit; 
						fi
					echo "FILE selected..."			
						select rfile in  $(ls ${sync_dir}${extradir}* 2> /dev/null) $(ls ${previous}${extradir}* 2> /dev/null) $(ls ${extras}${extradir} 2> /dev/null) $(ls ${backup_root}/${lastmonth}${extradir}* 2> /dev/null); do 
#choice needs be made for all similar Files found
							if [[ $REPLY  =~ ^[Qq]$ ]]; then echo -e "$RESET" && exit; fi
							du -sh $rfile; echo -e "--------------- \n   ------ \n      --- \n";
							echo -e "$hdROSE######Restoring file:"
							ls -lh $rfile 
							echo -e '\r' 
							echo -e "$GREEN in/over here:$restore_fs ######"
							ls -lh $restore_fs
							echo -e '\r' 
							echo -e '\r' 
							read  -r -p "$GREEN ###-###-###-###-###-### Y/y and Enter to continue replacing file." -e confirm
							restore=$rfile
							option1=""
							break
						done
					else
#or for all Directories found
					echo "$RESET DIR selected..."			
						select rdir in $(ls -d ${sync_dir}${extradir} 2> /dev/null) $(ls -d ${previous}${extradir} 2> /dev/null) $(ls -d ${extras}${extradir} 2> /dev/null) $(ls -d ${backup_root}/${lastmonth}${extradir} 2> /dev/null) ; do 
						if [[ $REPLY =~ ^[Qq]$ ]]; then echo -e "$RESET" && exit ; fi
							ls -l $rdir; echo -e "---------------\n   ------ \n      --- \n"; 
							restore=$(echo $rdir | sed 's:/*$::')
							echo -e "$hdROSE #### Resyncing dir:$RESET ${extradir}$hdROSE from"
							timeout 5 du -sh $restore || echo "$(ls -d $restore)"
							echo -e '\r' 
							echo -e "$GREEN in parent dir ####"
							timeout 5 du -sh $restore_fs || ls -dh $restore_fs
							echo -e '\r' 
							echo -e '\r'
							read -r -p "###-###-###-###-###-### Y/y and enter to continue replacing dir $RESET" -e confirm
							option1="-d --recursive"
							break
						done
					fi
					}
				Select_version

			echo -e "Restore target: $YELLOW $restore_fs"
			while [[ ! $confirm =~ ^[Yy]$ ]] ; do read -r -p "No restore confirmed. Please  Enter & select number & Enter..." && Select_version; done
			pre_restore=$HOME/preRestore
			if [ -z $pre_restore ]; then mkdir $pre_restore; fi
#show target, reprompt for confimation, and set previous versions backup dir
#read extra option and run rsync Restore, then show restore dir content
			echo -e "$BLUE - More options for rsync \n (-vv --progress) ?" -e option2	
			read -e option2
			if [[ $confirm =~ ^[Yy]$ ]]; then
					rsync -vv -b $option1 $option2 --backup-dir=$pre_restore $restore $restore_fs; 
						if [[ -z "${restore_fs// }" ]] ; then 
							echo -e "$hdROSE Currently how does it look inside...?$RESET"		
							ls -lh $extradir*; 
						fi
					exit
			fi 
	fi
################
############----BACKUP----############################################################
########
	if [[ ${gbFree//[^0-9]/} -lt 2 ]]; then 
		echo -e "$hdYELLOW $U_LINED !! Disk space < 2G !! $RESET \n Starting cleaner in 4s..."; sleep 4; cleaner $backup_root; 
		#set -- "clean" "$backup_root" "${@:3:4}"
	fi
#start cleaner if disk space <2GB  
#if the input is not a directory or a file full path, and isn't a remote path
	if [[ -e "${extradir}" ]] || [[ -e "$cmd_path" ]] ; then
		if [[ "$extradir" == *@*:* ]]; then :; else 
	list_bytes
		fi
		echo -e "\r $RESET"
		if [[ -n $1 ]] && [ $1 != "Rs" ]; then onetimebk=o;
				if [[ ! $UID -eq "0" ]]; then
					echo "ONEtime backup only for non-root users.";
				fi
#activate Onetime only  if the command line was given
#or ask to activate, else  the Full backup will run along Onetime
		else 
		echo -e "$hdROSE- O/o/R/r to run ONE-time/remote $RESET backup and no Full backup (if target is found) -\n"

		read -t 5 -r onetimebk ;
		fi

	fi
#
fi
##############Interactive##############

stdINC="\n/home\n/etc\n/var\n/root\n/boot"
include_file=${rstHOME}/INCbackup.txt
if [[ ! -f $include_file ]]; then 
echo -e $stdINC > "$include_file"; fi
#

########################Interactive#####
if tty -s; then

		if [[ ! $onetimebk =~ ^[OoRr]$ ]];then 
			until [[ "${extradir}" == /* ]] || [[ -z "${extradir}" ]] || [[ "${extradir}" == *@*:* ]]; do 
			echo "Full backups refuse relative paths !!";  echo "$RED $extradir $RESET invalid...$YELLOW U&e! $RESET"; exit  
			done
		fi
#if Onetime was NOT selected ( & NO path on command line, nor at prompt) , only full paths will be accepted for Full backup
#Full path can be added as permanent if root user
		if [[ $UID -eq "0" ]] && [[ -e "${extradir}" ]]; then
			read -t 5 -r -p "$RESET - Y/y to add it as permanent inclusion for NEXT LOCAL backups -" perminc ; 
			echo -e "\r $GREEN"
		fi
		
		if [[ $perminc =~ ^[Yy]$ ]]; then
			   echo -e '\r' && echo $cmd_path >> $include_file; 
		fi
#The / is backed up only according to rsync --files-from= --recursive 
fi
########################Interactive#####

#Create Exclude file and add Standard exclusions.
#
exclude_file=${rstHOME}/EXCbackup.txt
stdEXC="/dev\n/proc\n/sys\n/run\n/lost+found\n\n"
oneEXC="/var/lib\n"
otherEXC="$HOME/Downloads\n/var/run\n/var/cache\n"
if [[ ! -f $exclude_file ]]; then echo -e $otherEXC >> "$exclude_file"; fi
oneEXC_file=${rstHOME}/oneEXCbackup.txt

#
#########Interactive#################
if tty -s; then
#
	if [[ ! $onetimebk =~ ^[OoRr]$ ]] ; then  
#if Full backup
#and user is root, show includes disk usage
		if [[ $UID -eq "0" ]]; then  
			echo -e "$GREEN+ Will be synced in Full monthly backup:";
			for incl in $(cat $include_file); do
				if [ ! -d $incl ] && [ ! -f $incl ]; then 
					echo "NOT THERE" $incl; else timeout 2 du -sh $incl || echo "THICK:"$incl ; 
				fi; 
			done | sort -hk1
		fi  
		echo -ne '\n'
	fi
	
	if [[ -n "${extradir}" ]]; then
		echo -e "$GREEN$U_LINED+ Backup to the Extras folder:$RESET$GREEN \r"; 
		if [[ ! -f $oneEXC_file ]]; 
			then echo -e $oneEXC >> "$oneEXC_file"; 
		fi
		timeout 5 du -sh $extradir || echo "Thick: "$extradir ;
		echo -e "\r"
	fi 
#eventually create the exclusion file for  Onetime and show excludes disk usage .
#non root can run only Onetime backup of input, if storage is writable
	if [[ ! $UID -eq "0" ]] && [[ -z "${extradir}" ]]; then # if is not root and the path entered is not writable
			echo -e "$YELLOW No Full backup unless Root...\n Nothing to backup ? U&e!! Up and Enter !$RESET"; exit 1;
	fi
	if [[ ! $UID -eq "0" ]] && [[ ! -w $extras ]]; then
	echo -e "\n\n\n $YELLOW! Warning ! ########## \n $RESET access denied to $RED${extras}$RESET and subfolders. \n Set directory permissions for current user, or backup WILL fail.\n"; sleep 5; 
	fi
	
	echo -e "\n $GREEN   ###-1- We will backup the above.......\n $RESET \n- Some $U_LINED PATH TO EXCLUDE $RESET from this backup ?? : \n @-HELP: same or more specific than the above paths-@ \n \n ..Continues in 21s..            ..exclude $YELLOW#";	#read#EXCLU
	read -t 21 -e exclu
	
	if [[ -n "${exclu}" ]]; then
		read -e -t 15 -r -p $'      ##1/2 - Another exclusion?- :' exclu2 ;
	fi
	if [[ -z "${onetimebk}" ]]; then	
		if [[ -n "${exclu}" ]]; then
			timeout 5 du -sh $exclu || echo  $exclu
			timeout 5 du -sh $exclu2 || echo  $exclu2
			read -t 15 -r -p $'      ...p/P to make them permanent ? - :' permesc  
		fi
		if [[ $permesc =~ ^[Pp]$ ]]; then
			if [[ ! -d $exclu ]] && [[ ! -f $exclu ]]; then
			echo $exclu":Invalid path won't be excluded"; else
			echo -e '\r' & echo "$exclu" >> "$exclude_file"; 
			fi
		
			if [[ -n $exclu2 ]]; then
				if [[ ! -d $exclu2 ]] && [[ ! -f $exclu2 ]]; then
				echo $exclu2":Invalid path won't be excluded"; else
				echo -e '\r' & echo "$exclu2" >> "$exclude_file"; 
				fi
			fi
		fi
	echo -e "$YELLOW:: All Full backup EXCLUSIONS ::"
	else	
	echo -e "- From Onetime exclusions file:$RED $oneEXC_file $YELLOW" ;
	for excl in $(cat $oneEXC_file); do
			if [ ! -d $excl ] && [ ! -f $excl ]; then 
			echo "NOT THERE:" $excl; else timeout 3 du -sh $excl || echo  $excl; fi; 
	done;
	fi
#read 2 exclusions inputs and show disk usage and ask to make permanent to the exclude file,  
#then show all active exclusions	 
	echo -e "\r$YELLOW- Backup storage excluded:"
	if [[ $UID -eq "0" ]]; then
		timeout 3 du -sh $backup_root || echo $backup_root; 
		else echo $rsync_root;
	fi	
	echo -e "\r"


	


########################

	
	echo -e "\r"
	#if [[ ! -z "${onetimebk// }" ]]; 
	
	
	if [ ! -z $exclu ]; then timeout 5 du -sh $exclu || echo  $exclu; 
		echo -e "$YELLOW- This job excludes:"
	fi
	if [ ! -z $exclu2 ]; then timeout 5 du -sh $exclu2 || echo  $exclu2; fi
	
	echo -e '\r'
	
	if [[ ! $onetimebk =~ ^[OoRr]$ ]]; then
		echo -e "- From exclude file: $RED $exclude_file $YELLOW";
		#cat $exclude_file
		#sed 's/^ *//; s/ *$//; /^$/d' "$exclude_file"
		for excl in $(cat $exclude_file); do
			if [ ! -d $excl ]; then echo "NOT THERE" $excl ; 
			else timeout 2 du -sh $excl || echo "THICK:"$excl ; 
			fi 
		done | sort -hk1
		echo -e '\r' #carriage return
		echo -e "For full backup exclusions:";
		echo -e "$stdEXC"; 
	fi
#finally provide examples of optional command line switches
	echo -e "              $RESET $U_LINED## -0- READY to rsync ?-##$RESET \n $BLUE \n --debug=del2,acl,backup | -q | --dry-run \n --progress -vv --info=ALL4 | --whole-file \n - Input other arguments for rsync ? $RESET(departing in 9 seconds..):" ;
if [ -z $argu ]; then
	read -t 9 argu
fi
	##read variable
	echo -e '\r'
	echo -e '\r'
#
fi
#########Interactive#################

log="${rstHOME}/backup.log"
echo $starthour > $log
stdexc () { 
	for i in $(echo -e $stdEXC); do echo --exclude $i; done 
	}
##--suffix=$bkdate
df -H  --output=source,pcent,avail $rsync_root >> $log
######################################################
#####
###
##
rsync_fs()
	{ rsync -azhRb --files-from=$include_file --recursive --backup-dir=$previous --suffix=$bkdate --max-size=321mb --safe-links --info=BACKUP2,DEL2,COPY2,PROGRESS2 --exclude-from=$exclude_file --exclude $backup_root --exclude "$exclu" --exclude "$exclu2" $(stdexc) --delete-excluded $argu --log-file=$log --log-file-format="%''B %''i %''l %''b %''o %''n %L" --modify-window=1 / $sync_dir
	}
#man rsync
#-b, --backup                make backups (see --suffix & --backup-dir)
rsync_extra()
	{ rsync -azLhWRvv --recursive --safe-links --munge-links --info=BACKUP2,DEL2,COPY2,PROGRESS2 --exclude-from=$oneEXC_file --exclude $rsync_root --exclude "$exclu" --delete-excluded $argu --log-file=$log $extradir $extras
	}
#-a, --archive               archive mode; equals -rlptgoD (no -H,-A,-X)
#-z, --compress              compress file data during the transfer
#-L, --copy-links            transform symlink into referent file/dir
#-h, --human-readable        output numbers in a human-readable format
#-W, --whole-file            copy files whole (w/o delta-xfer algorithm)
#-R, --relative              use relative path names
##--recursive is needed for rsync to backup / by keeping the original tree in RSYNC execution
#######################################################
#
###########EXEC#####Onetime/remote to folder Extra#######
if [[ -f $1 ]] || [[ -d $1 ]] || [[ "$1" == *@*:* ]]; then extradir=$1 && onetimebk='o'; fi
		if [[ ! -z "${extradir// }" ]]; then #if extradir is NOT empty ?
			echo "$(date +%D" "%r): Beginning backup of input dir $extradir" >> $log
				if tty -s; then
				echo "--------------------------------------";
				echo -e "$(date +%D" "%r):$INVERT Beginning Onetime backup of input $extradir$RESET$BLUE" ;
				echo "--------------------------------------";	
				fi
set -x
rsync_extra;
set +x
		fi

###########EXEC#####Full backup if root user#######
	if [[ $UID -eq "0" ]]; then
		if [[ ! $onetimebk =~ ^[OoRr]$ ]]; then
			echo "$(date +%D" "%r): Beginning backup of /" >> $log
			if tty -s; then
				echo "--------------------------------------";
				echo -e "$(date +%D" "%r):$INVERT Beginning Full backup of / $RESET$BLUE";
				echo "--------------------------------------"; 
			fi
set -x
rsync_fs;
set +x
		fi
	fi
##
###
#####
#######################################################
hour=$(date +date-%d%h-%H:%M)
newlog=$rstHOME/Bkup_"$hour".log

#####Interactive#################
if tty -s; then
	echo -e '\r'; echo "$hour"; echo "Rsync completed. Storage stats:";
	df -H  --output=source,pcent,avail $rsync_root;
	echo -e '\r'; echo -e "$RESET Backup LOG at :-) $newlog - and at \n - $backup_root/backup.log (-:"
fi
#####Interactive#################

#######################################################
echo "-----##-------SCRIPT-rSyncTrees--------##------" >> "$log"
(
#cat "$_rsync_script" ;
echo "-----##-------VARIABLES--------##------" ;
echo "Using configuration files from dir" $rstHOME
echo -e '\r' ; echo "#" ;
echo "INCluded Local:" ; cat "$include_file" ; echo -e '\r' ; echo "#" ;
echo "ONEtime to folder Extras:" ; echo "$extradir" ; echo "##" ;
echo "Added shell arguments:" ; echo "$argu" ; echo -e '\r' ; echo "###" ;
echo "EXCluded:" ; cat "$exclude_file" ; echo -e '\r' ; echo "$exclu" ; echo "$exclu2" ; echo "$rsync_root"; if [[ $onetimebk =~ ^[OoRr]$ ]];then :; else echo -e "$stdEXC";fi ; echo "####"
)>> "$log"
##better have new Log next time, or else it will grow too big with >>
cp -f "$log" "$backup_root"
if [ ! -z $forward_mail ] && [ ! -z $smtp_server ]; then
mailx -n -s 'rSyncTrees-'$(hostname) -a $log -S smtp=smtp://$smtp_server $forward_mail < $custom_config 
fi
mv "$log" $newlog


