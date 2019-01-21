#!/bin/bash

# By Georgiy Sitnikov.
#
# Will do NC backup and upload to remote server via SSH with key authentication
#
# AS-IS without any warranty

SSHIdentityFile=/path/to/file/.ssh/id_rsa
SSHUser=user
RemoteAddr=IP_or_host
RemoteBackupFolder=/path/to/backup
NextCloudPath=/var/www/nextcloud

# Folder and files to be excluded from backup.
# - data/updater* exclude updater backups and dowloads 
# - *.ocTransferId*.part exclude partly uploaded files
#
# This is reasonable "must have", everything below is just to save place:
#
# - data/appdata*/preview exclude Previews - they could be newle generated
# - data/*/files_trashbin/ exclude users trashbins
# - data/*/files_versions/ exclude users files Versions

excludeFromBackup="--exclude=data/updater*\
 --exclude=*.ocTransferId*.part\
 --exclude=data/appdata*/preview\
 --exclude=data/*/files_trashbin/\
 --exclude=data/*/files_versions/"

# Compress to needs to have archivemount and sshfs installed.
CompressToArchive=false
WhereToMount=/mnt/remoteSystem # Needs to be set if CompressToArchive is true
RemoteArchiveName=backup.tar.gz # Needs to be set if CompressToArchive is true

#########

InstallerCheck () {
	# Check if all Programms are installed
	hash $1 2>/dev/null || { echo >&2 "It requires $1 but it's not installed. Aborting."; exit 1; }
}

# Check if config.php exist
[[ -e $NextCloudPath/config/config.php ]] || { echo >&2 "Error - сonfig.php could not be found under "$NextCloudPath"/config/config.php. Please check the path"; exit 1; }

# Fetch data directory place from the config file
DataDirectory=$(grep datadirectory $NextCloudPath/config/config.php | cut -d "'" -f4)

RsyncOptions="-aP --no-o --no-g --delete"

InstallerCheck rsync

if [ "$CompressToArchive" == true ]; then

	InstallerCheck sshfs
	InstallerCheck archivemount

	RsyncOptions="-aP --delete"

	mkdir -p $WhereToMount;
	mkdir -p $WhereToMount_$(date);

	echo Mount remote system
	sshfs -o allow_other,default_permissions,IdentityFile=$SSHIdentityFile $SSHUser@$RemoteAddr:$RemoteBackupFolder:$RemoteBackupFolder $WhereToMount

	sleep 2

	echo Mount remote Archive
	archivemount $WhereToMount/$RemoteArchiveName $WhereToMount_$(date)

	echo Rsync of NC into Archive
	rsync $RsyncOptions $excludeFromBackup $NextCloudPath $WhereToMount_$(date)

	echo Wait to finish sync
	sleep 5

	echo Unmount Archive
	umount $WhereToMount_$(date)

	echo Wait to finish sync
	sleep 5

	echo Unmount Remote FS
	umount $WhereToMount

else

	echo Run Rsync of NC root folder.
	rsync $RsyncOptions --exclude=data --exclude=$DataDirectory -e "ssh -i $SSHIdentityFile" $NextCloudPath $SSHUser@$RemoteAddr:$RemoteBackupFolder/nextcloud/

	echo Run Rsync of NC Data folder.
	rsync $RsyncOptions $excludeFromBackup -e "ssh -i $SSHIdentityFile" $NextCloudPath $SSHUser@$RemoteAddr:$RemoteBackupFolder/nextcloud/

fi

echo Ready.
exit 0
