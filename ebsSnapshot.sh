#!/usr/bin/env bash
printf "Example: i-0628856e00b7999f2,i-0fb5019d39a0f6f18,i-06811151dc50e2101 %s\n"
read -p "Please enter the instance id's separated by commas with no spaces:" -r insname
read -p "Please enter the region where the instance(s) are located:" -r region
insnames=$(echo $insname | tr -d ' ' | tr , '\n')
#changeregion=$(region $region)
#/usr/local/bin region $region
​
#Set array equal to instance id's
insarr=($insnames)
#printf "%s\n" "$insnames"
​
​
#describevol=$(aws ec2 describe-volumes --region $region --filters Name=attachment.instance-id,Values=$insnames Name=attachment.device,Values=/dev/sda1 --query 'Volumes[].VolumeId' | tr -d '"' | tr -d '[' | tr -d ']' | tr -d ' ' |tr -d ',' | sed -r '/^\s*$/d') 
#printf "%s\n" "The volumes are: $(echo ${describevol}) %s\n"
​
#insvol=$(aws ec2 describe-volumes --region $region --filters Name=attachment.instance-id,Values=$insnames Name=attachment.device,Values=/dev/sda1 --query 'Volumes[].Attachments[].InstanceId' | tr -d '"' | tr -d '[' | tr -d ']' | tr -d ' ' |tr -d ',' | sed -r '/^\s*$/d') 
​
​
#Sets counter for iteration through for loop
counter=0
currentdate=$(date -u +"%F")
hour=$(date -u +"%H:%M:%S.000")
inputdate="$currentdate""T""$hour""Z"
#printf "The date was set to: $inputdate %s\n"
snaparr2=()
​
for i in ${insarr[@]};
do
	#insinfo=$(aws ec2 describe-instances --instance-ids $i)
	insrootedevicename=$(aws ec2 describe-instances --instance-id $i --query "Reservations[*].Instances[*].RootDeviceName" --output text)
	insname=$(aws ec2 describe-instances --instance-id $i --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value] " --output text)
	#printf "The root device name is $insrootedevicename %s\n"
	describeinsvol=$(aws ec2 describe-volumes --region $region --filters Name=attachment.instance-id,Values=$i Name=attachment.device,Values=$insrootedevicename --query 'Volumes[].VolumeId' --output text) 
	printf "%s\n" "-------------------------------------------"
	printf "The Instance name is: $(echo ${insname}) %s\n"
	printf "The volume id is: $(echo ${describeinsvol}) %s\n"
done
printf "%s\n" "-------------------------------------------"
​
PS3="Do you want to continue with creating the snapshots for all the instances?(1/2): "
	
#Takes in input of the user to determine whether or not to test for an y or n
select ans in Yes No 	
do
	case $ans in
		Yes)
			for i in ${insarr[@]};
			do
				#insinfo=$(aws ec2 describe-instances --instance-ids $i)
				insrootedevicename=$(aws ec2 describe-instances --instance-id $i --query "Reservations[*].Instances[*].RootDeviceName" --output text)
				insname=$(aws ec2 describe-instances --instance-id $i --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value] " --output text)
				#printf "The root device name is $insrootedevicename %s\n"
				describeinsvol=$(aws ec2 describe-volumes --region $region --filters Name=attachment.instance-id,Values=$i Name=attachment.device,Values=$insrootedevicename --query 'Volumes[].VolumeId' --output text) 	
				#printf "The Instance name is: $(echo ${insname}) %s\n"
				#printf "The volume id is: $(echo ${describeinsvol}) %s\n"
				printf "We will proceed with taking the snapshot of $(echo ${insname}) %s\n"
				createsnapshot=$(aws ec2 create-snapshot --volume-id $describeinsvol --description "Snapshot for $(echo ${insname})")
				printf "The snapshot process has started! %s\n"
				#printf "The snapshot id is: $(echo ${createsnapshot} | jq ".SnapshotId" ) %s\n"
				snaparr2[$counter]="$(echo ${createsnapshot} | jq ".SnapshotId" | tr -d '"')"
				counter=$[counter+1]
			done
			break
			;;
		No)
			printf "We will not proceed with taking snapshot %s\n"
			break
			;;
		*)		
			printf "Error: Please try again (select 1..2)! %s\n"
			;;		
	esac
done
​
​
#printf "The value of the array is $snaparr2 %s\n"
​
#testsnap=$(aws ec2 describe-snapshots --filters Name=status,Values=pending --query 'Snapshots[].SnapshotId' | tr -d '"' | tr -d '[' | tr -d ']' | tr -d ' ' |tr -d ',' | sed -r '/^\s*$/d' |tr -d '{' |tr -d '}')
#snaparr=($testsnap)
snapprogress=$(aws ec2 describe-snapshots --filters Name=status,Values=pending --query 'Snapshots[?StartTime>=`$inputdate`].{Description:Description,Id:SnapshotId,VId:VolumeId,Size:VolumeSize,StartTime:StartTime}' | tr -d '"' | tr -d '[' | tr -d ']' | tr -d ' ' |tr -d ',' | sed -r '/^\s*$/d')
#snapcount=0
​
​
#printf "The value of snapprogress is: $(echo ${snapprogress}) %s\n"
​
checkcount=1
while ! [ -z "$snapprogress" ]
do
	echo "$(aws ec2 describe-snapshots --filters Name=status,Values=pending --query 'Snapshots[*].{Progress:Progress}' | tr -d '"' | tr -d '[' | tr -d ']' | tr -d ' ' |tr -d ',' | sed -r '/^\s*$/d' |tr -d '{' |tr -d '}' | sed -r '/^\s*$/d')"
	#printf "$(echo ${progress}) %s\n"
	printf "Waiting... This is check number $checkcount %s\n"
	sleep 30
	#printf "The date was set to: $currentdate""T""$hour""Z %s\n"
	snapprogress=$(aws ec2 describe-snapshots --filters Name=status,Values=pending --query 'Snapshots[?StartTime>=`$inputdate`].{Description:Description,Id:SnapshotId,VId:VolumeId,Size:VolumeSize,StartTime:StartTime}' | tr -d '"' | tr -d '[' | tr -d ']' | tr -d ' ' |tr -d ',' | sed -r '/^\s*$/d')
	checkcount=$[checkcount+1]
done
​
printf "The snapshot(s) have been created! %s\n"
​
#echo "$(aws ec2 describe-snapshots --filters Name=status,Values=completed --query 'Snapshots[?StartTime>=`$inputdate`].{Description:Description,Id:SnapshotId,VId:VolumeId,Size:VolumeSize,StartTime:StartTime}')"
for r in ${snaparr2[@]};
do
	#printf "$r %s\n"
	echo "$(aws ec2 describe-snapshots --snapshot-id $r --output table)"
	#snapcount=$[snapcount+1]
done
​
​
for i in ${insarr[@]};
do
	#insinfo=$(aws ec2 describe-instances --instance-ids $i)
	#insrootedevicename=$(aws ec2 describe-instances --instance-id $i --query "Reservations[*].Instances[*].RootDeviceName" --output text)
	insip=$(aws ec2 describe-instances --instance-id $i --query "Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddresses[*].PrivateIpAddress" --output text)
	insname=$(aws ec2 describe-instances --instance-id $i --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value] " --output text)
	#printf "The root device name is $insrootedevicename %s\n"
	#describeinsvol=$(aws ec2 describe-volumes --region $region --filters Name=attachment.instance-id,Values=$i Name=attachment.device,Values=$insrootedevicename --query 'Volumes[].VolumeId' --output text) 
	printf "%s\n"
#	printf "%s\n" "-------------------------------------------"
	printf "$(echo ${insname}) , $(echo ${insip})" "%s\n"
	#printf "The volume id is: $(echo ${describeinsvol}) %s\n"
done
​
#printf "%s\n" "-------------------------------------------"
