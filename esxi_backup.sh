#!/bin/bash
####################################
#
# You need ssh keys installed on ESXi host from linux computer that will run this script. Run commands below as root. Run this script as root.
#
#   On a Linux box, create a key pair without passphrase:
#     	ssh-keygen -N "" -f id_esxi
#          
#	This creates two files - id_esxi and id_esxi.pub.
#	Append the public key to /etc/ssh/keys-root/authorized_keys on your ESXi box from Linux:
#		cat id_esxi.pub | ssh root@HOSTNAME_OR_IP_ADDRESS 'cat >>/etc/ssh/keys-root/authorized_keys'
#		
#	To test, you can ssh into your ESXi box by just using the private key:
#		ssh -i id_esxi root@HOSTNAME_OR_IP_ADDRESS
#		
#		############################
#		
# Backup directory needs to be on ESXi host. If you want to be on a NAS then setup a datastore on ESXi host for the NAS		
#		
####################################

PUBKEY='/root/id_esxi'										# Public SSH key for passwordless access to EXSi
USER_NAME="root"											# Username that has permission to access to ESXi via SSH
BACKUP_DIRECTORY='/vmfs/volumes/NAS/ESXi_Backups'			# Location of backups directory on EXSi
ESXiHosts=( "xxx.xx.x.x" "xxx.xx.x.x" )				    	# Hostname or IP address of your ESXi servers. You can have multiple
EXCLUDE_VM=( "backup" )		    	                        # Hostname or IP address of your ESXi servers to NOT backup
MINUTES_TO_KEEP="+2880"										# Delete backups older then x minutes


for host in "${ESXiHosts[@]}"; do
	# Date format for log filename, set to (YYYY/MM/DD)
    DIRNAME=$(date +%Y%m%d)	
	SERVER_IP=$host
    bDIR="${host//./}"
    
    # Delete old backup files
    deleteOld=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP "find $BACKUP_DIRECTORY -maxdepth 3 -type f -mmin $MINUTES_TO_KEEP -exec rm -vf {} + 2>&1")
	deleteOld=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP " find $BACKUP_DIRECTORY -mindepth 1 -type d -print -exec rmdir {} + 2>&1")
    
 	# GET LIST OF VM ID's
	vm_cmd='vim-cmd vmsvc/getallvms | awk '\''NR>1{print $1}'\'
	VM_LIST=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP $vm_cmd)

	# IF LIST FAILED THEN EXIT
	if [ -z "$VM_LIST" ]; then
    	echo "No virtual machines found at $SERVER_IP"
        continue
    else
    	echo "Virtual machines found at $SERVER_IP"
        # MAKE DIRECTORY FOR BACKUPS IN DATASTORE
		DIRNAME=$DIRNAME"-$bDIR"
		storageLocation=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP mkdir -p "$BACKUP_DIRECTORY"/"$DIRNAME")
	fi

	# WRITE TO LOGFILE
    logMsg=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP "echo "Virtual machines found at"-$SERVER_IP | tee $BACKUP_DIRECTORY"/"$DIRNAME/back.log")
    logMsg=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP "echo "------------" | tee -a $BACKUP_DIRECTORY"/"$DIRNAME/back.log")
	logMsg=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP "echo "ESXi Backups" | tee -a $BACKUP_DIRECTORY"/"$DIRNAME/back.log")
	logMsg=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP "echo "Date-"$(date) | tee -a $BACKUP_DIRECTORY"/"$DIRNAME/back.log")
	logMsg=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP "echo "------------" | tee -a $BACKUP_DIRECTORY"/"$DIRNAME/back.log")

	# CYCLE THROUGH VM BY ID
	for vm in $VM_LIST; do
	
		# GET VM INORMATION NEEDED FOR BACKUP
		hasSnapshot=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP 'vim-cmd vmsvc/get.snapshot' $vm)				
		getSummary="vim-cmd vmsvc/get.summary $vm | grep 'name\|powerState\|vmPathName'"
		summaryResult=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP $getSummary)
		vmDIR="$BACKUP_DIRECTORY"/"$DIRNAME"/"$(echo $summaryResult | awk -F'"' '{print $4}' )"
		poweredOFF=$(echo $summaryResult | awk -F'"' '{print $2}' )
		vmPath="/vmfs/volumes"$(echo $summaryResult | awk -F'"' '{print $6}' | tr [] / | tr -d ' ' )
		vmName=$(echo $summaryResult | awk -F'"' '{print $4}' )
		vmdkPath=$vmDIR"/"$(basename "${vmPath%.*}")".vmdk"
        
		if ! [[ ${EXCLUDE_VM[*]} =~ "$vmName" ]]; then
    		echo "backing up $vmName"
        	#continue
        	
        	# WRITE TO LOGFILE
			logMsg=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP "echo "Backing up-"$vmName | tee -a $BACKUP_DIRECTORY"/"$DIRNAME/back.log")
        	logMsg=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP "echo "Start backing up-"$(date) | tee -a $BACKUP_DIRECTORY"/"$DIRNAME/back.log")
        
        	# CREATE BACKUP DIRECTORY FOR VM
        	echo "Creating backup directory $vmDIR" 
        	vmDirectory=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP mkdir -p "$vmDIR")
		
        	# IF VM IS POWERED OFF COPY OTHERWISE SUSPEND VM COPY THEN RESUME
        	if [[ $poweredOFF == *"Off"* ]]; then
				# COPY VMX FILES TO BACKUP
           		echo "Virtual machine is powered off copying $vmPath to local directory"
            	fileCopy=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP "cp $vmPath $vmDIR")
            	sleep 15
            	# COPY VMDK FILES TO BACKUP
            	echo "Virtual machine is powered off copying $vmdkPath to local directory"
            	fileCopy=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP "vmkfstools -i ${vmPath%vmx}vmdk $vmdkPath")
            	sleep 15
			else
        		echo "backing up $vmName"
                #continue
                
        		echo "Virtual machine is powered on"
            	# IF SNAPSHOT EXISTS SKIP THIS VM. DO NOT BACKUP. ELSE COPY VM FILES TO BACKUP
            
            	if [ -n "$hasSnapshot" ]; then
    				echo "Snapshot found! Not Backing up"
            	else
                	#SUSPEND VM
               		echo "Snapshot NOT found! Backing up"
                	echo "Suspending VM"
                	suspendVM=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP 'vim-cmd vmsvc/power.suspend' $vm)
                	sleep 15
                     
                	# COPY VMX FILES TO BACKUP
                	echo "Virtual machine is powered off copying $vmPath to local directory"
                	fileCopy=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP "cp $vmPath $vmDIR")
                	sleep 15
                	# COPY VMDK FILES TO BACKUP
                	echo "Virtual machine is powered off copying $vmdkPath to local directory"
                	fileCopy=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP "vmkfstools -i ${vmPath%vmx}vmdk $vmdkPath")
                	sleep 15
                    
                	# RESUME VM
                	echo "Resuming VM"
                	resumeVM=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP 'vim-cmd vmsvc/power.on' $vm)
                	sleep 15
    			fi
        	fi
        
    	else
        	echo "not backing up $vmName"
    	fi  
        
    	# WRITE TO LOGFILE
		logMsg=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP "echo "End backing up-"$(date) | tee -a $BACKUP_DIRECTORY"/"$DIRNAME/back.log")
    	logMsg=$(ssh -i $PUBKEY $USER_NAME@$SERVER_IP "echo "------------" | tee -a $BACKUP_DIRECTORY"/"$DIRNAME/back.log")
		echo "----------------"
	done   
    
done
