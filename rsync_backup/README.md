# Backup script example

This is a really simple incremental backup script with rsync. Just change the locations
to your source and dest, plug in your external drive, and run it.

You'll get a bunch of folders of full filesystem mirrors using hard links to save space.

It even resumes the last interrupted backup if you stop the script or unplug the drive. 
The resume feature won't detect any other errors, but maybe you can fix that.

Be sure to use a persistant disk name like /dev/disk/by-id so you can juts plug it in and run.

Based on code from [https://blog.interlinked.org/tutorials/rsync_time_machine.html]
