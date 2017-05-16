#Backup script based on https://blog.interlinked.org/tutorials/rsync_time_machine.html
#All credit to them, I just modified it a bit

#You may need to manually get rid of old backups to free up space with this.
#Pretty sure this will only work for local filesystem backups.

########################CONFIG#############################

#Get the current date in the specified format.  You can change this to change the format.
date=`date "+%Y-%m-%dT%H:%M:%S"`
#This should be the folder you want to back up. Theses have to be absolute paths for the hardlinks
#To work it seems
#If you use a trailing slash, the generated backup folders will be copies of this
#If you do not, generated folders will _contain_ a folder that is a copy.
#Slight difference, be consistant.
backup_source="ABS_PATH_TO_FOLDER_YOU_WANT_TO_BACK_UP"
#This is where you want to back it up to. It's going to have a folder called "current"
#plus one folder for each incremental dump
backup_location="ABS_PATH_TO_BACKUP_LOCATION"

############################################################################

#If there was a backup in progress but not completed, now we want to resume that one.
if [ -f "$backup_location/inprogress.txt" ]; then
    folder=`cat "$backup_location/inprogress.txt"`
    absfolder="$backup_location/$folder"
    echo "resuming backup to $folder"
else
    echo "$folder" > "$backup_location/inprogress.txt"
    folder="back-$date"
    absfolder="$backup_location/$folder"
    echo "backing up to $folder"
fi


#If we have no previous backup to link against, assume this is a new backup repo, and
#mkdir an empty /current folder, and make a symlink to that.
if [ ! -h "$backup_location/current" ]; then
mkdir "$backup_location/0_empty"
ln -s "0_empty" "$backup_location/current" 
fi

#Make a backup, but if any file hasn't changed, just hardlink it to the old one.
rsync -aP --link-dest="$backup_location/current" "$backup_source" "$absfolder"
#Remove the now outdated symlink called current
rm -f "$backup_location/current"
#make new symlink "current" to the latest backup we made
ln -s "$folder" "$backup_location/current"

#If we had to make the 0 dir, delete it now that we don't need it anymore.
if [ -d "$backup_location/0_empty" ]; then
rmdir "$backup_location/0_empty"
fi

#if the symlink exists, we can assume that the disk drive is still connected and we can
#delete the file that marks in progress
if [ -L "$backup_location/current" ]; then
rm "$backup_location/inprogress.txt"
fi
