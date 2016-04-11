#!/bin/sh

export INSTANCE_ADDRESS
# ="ec2-52-201-225-114.compute-1.amazonaws.com"
export EC2_BACKUP_FLAGS_SSH="-i ec2-backup.pem"
export DIR="/MyBackUp"
export VOLFLAG=0
export origin_dir
# /home/xfan7/xxx
export backupDir="/ec2-back-up"
make_file()
{
    count=0
    while :
   do
        [ -n "${EC2_BACKUP_VERBOSE}"  ] && echo "make file..." >&2
        sleep 3
        ssh -q -t -oStrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH ubuntu@ {INSTANCE_ADDRESS} "sudo mkfs.ext4 /dev/xvdf;"
        if [ $? -eq 0  ];then
        break
        fi
        count=$(($count+1))
        if [ $cnt -eq 30  ];then
            return 2
        fi
    done
    echo "make file completed"

}
mount_DIR()
{
    if [ $VOLFLAG -eq 0  ];then
        count=0
        while :
        do
            [ -n "${EC2_BACKUP_VERBOSE}"  ] && echo "mount..." >&2
            sleep 3
            ssh -q -t -oStrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH ubuntu@${INSTANCE_ADDRESS} "sudo mkdir $DIR"
            ssh -q -t -oStrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH ubuntu@${INSTANCE_ADDRESS} "sudo mount /dev/xvdf $DIR"
            if [ $? -eq 0  ];then
                break
            fi
            count=$(($count+1))
            if [ $cnt -eq 30  ];then
                return 2
            fi
        done
    fi
    echo "mount completed"

}
umount_DIR()
{
    count=0
    while :
    do
        [ -n "${EC2_BACKUP_VERBOSE}"  ] && echo "umount..." >&2
        sleep 3
        ssh -q -t -oStrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH ubuntu@${INSTANCE_ADDRESS} "sudo umount $DIR"
        if [ $? -eq 0  ];then
            break
        fi
        count=$(($count+1))
        if [ $cnt -eq 30  ];then
            return 2
        fi
    done
    echo "umount completed"

}
back_up_dd()
{
    count=0
    time=$(date | sed "s/ /-/g")
    while :
    do
        [ -n "${EC2_BACKUP_VERBOSE}"  ] && echo "backing up! (dd)..." >&2
        sleep 3
        ssh -t -q -oStrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH ubuntu@${INSTANCE_ADDRESS} "    sudo mkdir $DIR/$time/"
        temp_name=$(echo $origin_dir |  sed "s/\//_/g")
        tar -cPf - "$origin_dir" | ssh -q -t -oStrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH ubuntu@${INSTANCE_ADDRESS} sudo dd of=$DIR/$time/$temp_name.tar.gz >/dev/null 2>&1
        if [ $? -eq 0  ];then
            break
        fi
        count=$(($count+1))
        if [ $count -eq 30  ];then
            return 2
        fi
    done
    echo "back-dd"

}

back_up_rsync()
{
    count=0
    time=$(date | sed "s/ /-/g")
    while :
    do
        [ -n "${EC2_BACKUP_VERBOSE}"  ] && echo "mkfs and mount on $addr
        ..." >&2
        sleep 3
        rsync -azP "$origin_dir" ubuntu@${INSTANCE_ADDRESS}:/home/ubuntu$backupDir -e "ssh ${EC2_BACKUP_FLAGS_SSH}" >/dev/null 2>&1
        if [ $? -eq 0  ];then
            break
        fi
        count=$(($count+1))
        if [ $count -eq 30  ];then
            return 2
        fi
    done
    ssh -t -q -oStrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH ubuntu@${INSTANCE_ADDRESS} "sudo mkdir $DIR/$time/"
    ssh -t -q -oStrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH ubuntu@${INSTANCE_ADDRESS} "sudo mv /home/ubuntu$backupDir/* $DIR/$time/"
    echo "back-rsync"

}

make_file
mount_DIR
back_up_dd
back_up_rsync
umount_DIR
exit 0
