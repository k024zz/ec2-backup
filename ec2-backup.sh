#!/bin/sh

# init 
METHOD="DD"
VOLFLAG="0"

# check directory
DIR=${@:-1}
if [ ! -d "$DIR" ]; then
	echo "error: directory $DIR does not exist."
	exit 127
fi

# extract command line options with getopt
while getopts :hm:v: opt
do
	case "$opt" in
	h) echo "output help" ;;
	m) echo "option m with value $OPTARG" ;; 	 
	v) echo "option v with value $OPTARG" ;;
	*) echo "Unknown option: $opt" ;;	
	esac
done

# create a new volume
# get a avaiable zone
avaiZone=`aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' | awk -F'"' '{print($2)}'`
dirSize=`du -s $DIR | awk '{print($1)}'`
volSize=`echo "$dirSize 524288" | awk '{print($1/$2)}'`
volSize=`echo volSize | awk '{print int($1)==$1?$1:int(int($1*10/10+1))}'`
VOLID=`aws ec2 create-volume --size $volSize --availability-zone $avaiZone --volume-type standard | grep VolumeId | awk -F'"' '{print($4)}'`
echo $VOLID

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
	#echo "delete key pair if it exists"
	aws ec2 delete-key-pair --key-name ec2-backup-key
fi
# if the pem file exists, remove it first
pemfile="ec2-backup.pem"
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
aws ec2 attach-volume --volume-id $VOLID --instance-id $instanceId --device /dev/sdp
sleep 5 
echo "attached"

instanceIp=`aws ec2 describe-instances --instance-ids $instanceId --query 'Reservations[0].Instances[0].PublicIpAddress' | awk -F'"' '{print($2)}'`
INSTANCE_ADDRESS=`echo "$pemfile $instanceIp" | awk '{print("-i "$1" ubuntu@"$2)}'`
echo $INSTANCE_ADDRESS

# todo



exit 0

