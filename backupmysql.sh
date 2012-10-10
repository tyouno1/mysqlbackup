#! /bin/bash

# Ameir Abdeldayem
# http://www.ameir.net
# You are free to modify and distribute this code,
# so long as you keep my name and URL in it.

# your MySQL server's name
SERVER=`hostname -f`

# directory to backup to
BACKDIR=~/backups/mysql

# date format that is appended to filename
DATE=`date +'%m-%d-%Y-%H%M'`

#----------------------MySQL Settings--------------------#

# your MySQL server's location (IP address is best)
HOST=localhost

# MySQL username
USER=root

# MySQL password
PASS=password

# List all of the MySQL databases that you want to backup in here, 
# each separated by a space
DBS="db1 db2"

# set to 'y' if you want to backup all your databases. this will override
# the database selection above.
DUMPALL=y


#----------------------Mail Settings--------------------#

# set to 'y' if you'd like to be emailed the backup (requires mutt)
MAIL=y

# email addresses to send backups to, separated by a space
EMAILS="address@yahoo.com address@usa.com"

SUBJECT="MySQL backup on $SERVER ($DATE)"

#----------------------FTP Settings--------------------#

# set "FTP=y" if you want to enable FTP backups
FTP=y

# FTP server settings; group each remote server using arrays
# you can have unlimited remote FTP servers
FTPHOST[0]="ftphost"
FTPUSER[0]="username"
FTPPASS[0]="password"
FTPDIR[0]="backups"

FTPHOST[1]="ftphost"
FTPUSER[1]="username"
FTPPASS[1]="password"
FTPDIR[1]="mybackups/mysql"

FTPHOST[2]="ftphost"
FTPUSER[2]="username"
FTPPASS[2]="password"
FTPDIR[2]="backups"

# directory to backup to; if it doesn't exist, file will be uploaded to 
# first logged-in directory; the array indices correspond to the FTP info above

#-------------------Deletion Settings-------------------#

# delete old files?
DELETE=y

# how many days of backups do you want to keep?
DAYS=30

#----------------------End of Settings------------------#

# check of the backup directory exists
# if not, create it
if  [ ! -d $BACKDIR ]; then
	echo -n "Creating $BACKDIR..."
	mkdir -p $BACKDIR
	echo "done!"
fi

if  [ $DUMPALL = "y" ]; then
	echo -n "Creating list of all your databases..."
	DBS=`mysql -h $HOST --user=$USER --password=$PASS -Bse "show databases;"`
	echo "done!"
fi

echo "Backing up MySQL databases..."
for database in $DBS
do
	echo -n "Backing up database $database..."
	mysqldump -h $HOST --user=$USER --password=$PASS $database > \
		$BACKDIR/$SERVER-$database-$DATE-mysqlbackup.sql
	gzip -f -9 $BACKDIR/$SERVER-$database-$DATE-mysqlbackup.sql
	echo "done!"
done

# if you have the mail program 'mutt' installed on
# your server, this script will have mutt attach the backup
# and send it to the email addresses in $EMAILS

if  [ $MAIL = "y" ]; then
	BODY="Your backup is ready! Find more useful scripts and info at http://www.ameir.net. \n\n"
	BODY=$BODY`cd $BACKDIR; for file in *$DATE-mysqlbackup.sql.gz; do md5sum ${file};  done`
	ATTACH=`for file in $BACKDIR/*$DATE-mysqlbackup.sql.gz; do echo -n "-a ${file} ";  done`

	echo -e "$BODY" | mutt -s "$SUBJECT" $ATTACH -- $EMAILS
	if [[ $? -ne 0 ]]; then 
		echo -e "ERROR:  Your backup could not be emailed to you! \n"; 
	else
		echo -e "Your backup has been emailed to you! \n"
	fi
fi

if  [ $FTP = "y" ]; then
	echo "Initiating FTP connection..."
	if  [ $DELETE = "y" ]; then
		OLDDBS=`cd $BACKDIR; find . -name "*-mysqlbackup.sql.gz" -mtime +$DAYS`
		REMOVE=`for file in $OLDDBS; do echo -n -e "delete ${file}\n"; done`
	fi

	cd $BACKDIR
	ATTACH=`for file in *$DATE-mysqlbackup.sql.gz; do echo -n -e "put ${file}\n"; done`

for KEY in "${!FTPHOST[@]}"
do
	echo -e "\nConnecting to ${FTPHOST[$KEY]} with user ${FTPUSER[$KEY]}..."
	ftp -nvp <<EOF
	open ${FTPHOST[$KEY]}
	user ${FTPUSER[$KEY]} ${FTPPASS[$KEY]}
	tick
	cd ${FTPDIR[$KEY]}
	$REMOVE
	$ATTACH
	quit
EOF
done

	echo -e  "FTP transfer complete! \n"
fi

if  [ $DELETE = "y" ]; then
	cd $BACKDIR; for file in $OLDDBS; do rm ${file}; done
	if  [ $DAYS = "1" ]; then
		echo "Yesterday's backup has been deleted."
	else
		echo "The backups from $DAYS days ago and earlier have been deleted."
	fi
fi

echo "Your backup is complete!"
