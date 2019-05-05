# rSyncBackup.sh
Optional Variables:
-STORAGE=/the/main/disk/with/space
-otherStorage=/disk/with/space
-rsbHOME=/any/dir/forLogsAndConfig
-HELP=off
-ttestMb=555 #by default transfer speed
-forward_mail=user@domain.ext
-smtp_server=mail@domain.ext(:25)
-minGbfree=9 #by default disk space remaining triggering warning


Command Line [Options] for #rSyncBackup 

[/dir/path] - short for ONEtime backup - displays ordered size of subfolders or files with similar name
du  - show Sync dir usage
due - for the Extras dir
dup - for the Previous dir
duA - list all storage subfolders
Rs - restores files and directories 
rp - creates gz.tar of the sync directory
Rrp - restores the rp to a folder or to current sync dir
speed - test rsync backup on configured storage
old [pattern] - query/remove previous versions | optional grep pattern filter: rSyncBackup old mtab_[0-3][0-9]
clean [path] - serial destroyer | optional dir to clean: rSyncBackup clean /home/you/folder
* - invalid


Created on BackBox (Ubuntu), tested in Debian, Suse, CentOS, Windows-SL
Rsync should be installed!

The script will run 2 rsync jobs:
- 1 for remote or One-time only, 
to a sub folder called -Extras-;
in verbose mode (-vv) on terminal and minimal log;
has no default --backup option ;
has fewer standard exclusions. Hence is more dangerous - (anyway the backup storage is always excluded);
can run Onetime only without or along with -Full backup-;
will run excluding the Full backup if a path was specified as rSyncBackup argument;
can run as basic non-root user;
won't allow to backup the root / of the filesystem ;

- 1 to mirror your chosen subfolders of  “/”, is the -Full backup-:
has a new folder every month -02.2019- for February;
runs in info mode on terminal and delivers detailed log;
backups / with --include-from-file=//INCbackup.txt, and with standard exclusions;
is optimized for SMB storage; 
has the backup option to put previous files versions in folder -Previous- with a new date suffix every hour (that is, supposing you modify the file and back it up every hour);
will run only as root user.

- BOTH jobs  
 the modified files in this folder have suffix of the hour backup time most recent after the file was modified: hence there can be a new file every hour;
ask what dir/file to backup, validate it exists; and ask you to make it permanent for next backups;
ask whether to exclude something from the current backup; and whether to make it permanent;
are bound to exclusion files;
will display the size of the inclusions and exclusions in MB;
are able to run non-interactively as crontab job (use #crontab -e) or as nohup;

The first time you run it, it will:
-ask you to choose or create a backup directory in your home; it will create the 3 subdirs: 1 for synchronization, 1 for backup, 1 for onetime/remote jobs;
-create an exclude EXCbackup.txt with  and an include INCbackup.txt file in your home, with common ex/inclusions. If you delete them it will recreate them. Also oneEXCbackup.txt is created when Onetime backup runs.


At every run it will:
- if the backup directory is not found it can backup to an alternative storage, defined in /etc/.rsyncbackup; 
- never create directories if the storage is not defined, but only as subdirs of the Storage;
- allow to run a one-time backup of the chosen path, remote or local;
- show you the disk allocation for the chosen path (if existing) in the 3 storage folders (eg.: /var/log/messages will be found with multiple entries with date suffixes);
- run in Onetime if the directory is specified on command line;
- allow to add the paths entered as permanent in/exclusions.
- otherwise synchonize the included files/dirs to the monthly folder (and delete files no longer present); backup the changes to the “previous” backup directory; backup the extra input to the extra folder.
- create a backup log with end date in the name, and deliver the most recent to the backup directory.
- allow to insert other rsync options (man rsync).
- use "mailx" to send a mail to the server and address specified in the /etc/.rsyncbackup with the log attached
