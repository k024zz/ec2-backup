#!/bin/bash

help() {
	echo "options:"
	echo "-h	Print a usage statement and exit."
	echo "-m method		Use the given method to perform the backup.	Valid methods are 'dd' and 'rsync'; default is 'dd'."
	echo "-v volume-id  Use the given volume instead of creating a new one."
}

clean() {
	# delete key pair
	key=`aws ec2 describe-key-pairs | grep ec2-backup-key`
	if [ -n "$key"  ]; then
		aws ec2 delete-key-pair --key-name ec2-backup-key
	fi
	# delete pem file 
	if [ ! -d "$pemfile" ]; then
		rm -f $pemfile 
	fi
}

# init 
METHOD="dd"
VOLFLAG="0"

# extract command line options with getopt
while getopts :hm:v: opt
do
	case "$opt" in
	h) help ;;
	m) METHOD=$OPTARG
	   if [ "$METHOD" != "dd" -a "$METHOD" != "rsync" ]; then
	       echo "error: invalid method"
		   exit 127
	   fi
	   echo "option m with value $METHOD" ;; 
	v) VOLFLAG="1"
	   VOLID=$OPTARG
	   echo "option v with value $VOLID" ;;
	*) echo "Unknown option: $opt" ;;	
	esac
done
shift `expr $OPTIND - 1`

# check directory
DIR=$1
if [ ! -d "$DIR" ]; then
	echo "error: directory $DIR does not exist."
	exit 1
fi

# calculate directory size
dirSize=`du -s $DIR | awk '{print($1)}'`
volSize=`echo "$dirSize 524288" | awk '{print($1/$2)}'`
volSize=`echo volSize | awk '{print int($1)==$1?$1:int(int($1*10/10+1))}'`
if [ "$VOLFLAG" == "0" ]; then
	# create a new volume
	# get a avaiable zone
	avaiZone=`aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' | awk -F'"' '{print($2)}'`
		VOLID=`aws ec2 create-volume --size $volSize --availability-zone $avaiZone --volume-type gp2 | grep VolumeId | awk -F'"' '{print($4)}'`
else
	#check avaiable zone and volume size
	curZone=`aws ec2 describe-volumes --volume-id $VOLID --query 'Volumes[0].AvailabilityZone'`
	avaiZone=`aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' | grep "$curZone"`
	if [ -z "$avaiZone" ]; then
		echo "the avaiable zone of volume does not match you"
		exit 1
	fi
	curSize=`aws ec2 describe-volumes --volume-id $VOLID --query 'Volumes[0].Size'`
	if [ $volSize -gt $curSize ]; then
		echo "The size of the volume is not enough"	
		exit 1
	fi
fi	
# create a new security group for ec2 backup
# check if the group ec2-backup exist
group=`aws ec2 describe-security-groups | grep ec2-backup-sg`
if [ -z "$group" ]; then 
	aws ec2 create-security-group --group-name ec2-backup-sg --description "ec2 backup group"
	aws ec2 authorize-security-group-ingress --group-name ec2-backup-sg --protocol -1 --cidr 0.0.0.0/0
	#echo "delete back up sg if it exists" 
	#aws ec2 delete-security-group --group-name ec2-backup-sg	
fi
groupID=`aws ec2 describe-security-groups --group-name ec2-backup-sg | grep GroupId | awk -F'"' '{print($4)}'` 

# create a new key for ec2 backup
# check if the key pair exist
key=`aws ec2 describe-key-pairs | grep ec2-backup-key`
if [ -n "$key"  ]; then
	aws ec2 delete-key-pair --key-name ec2-backup-key
fi

# if the pem file exists, remove it first
pemfile="./ec2-backup.pem"
if [ ! -d "$pemfile" ]; then
	rm -f $pemfile 
fi
aws ec2 create-key-pair --key-name ec2-backup-key --query 'KeyMaterial' --output text > $pemfile
chmod 400 $pemfile

# create instance
instanceId=`aws ec2 run-instances --image-id ami-fce3c696 --security-group-ids "$groupID" --count 1 --instance-type t2.micro --key-name ec2-backup-key --query 'Instances[0].InstanceId' | awk -F'"' '{print($2)}'`
echo $instanceId
status=""
while [ "$status" != '"ok"' ]
do
	echo "wait for instance initializing. status: $status"
	status=`aws ec2 describe-instance-status --instance-ids $instanceId --query 'InstanceStatuses[0].InstanceStatus.Status'`
	sleep 15
done	
echo "ok" 

# attach-volume
aws ec2 attach-volume --volume-id $VOLID --instance-id $instanceId --device /dev/sdf
sleep 5 
echo "attached"

INSTANCE_ADDRESS=`aws ec2 describe-instances --instance-ids $instanceId --query 'Reservations[0].Instances[0].PublicIpAddress' | awk -F'"' '{print($2)}'`
EC2_BACKUP_FLAGS_SSH="-i "$pemfile
echo $INSTANCE_ADDRESS

# todo



exit 0

