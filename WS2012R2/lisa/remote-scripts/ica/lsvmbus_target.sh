#!/bin/bash
########################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved.
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
########################################################################

ICA_TESTRUNNING="TestRunning"
ICA_TESTCOMPLETED="TestCompleted"
ICA_TESTFAILED="TestFailed"
network_counter=0
scsi_counter=0

LogMsg()
{
    echo "$(date "+%a %b %d %T %Y")" : "${1}"
}

UpdateSummary()
{
    echo "$1" >> ~/summary.log
}

UpdateTestState()
{
    echo "$1" > ~/state.txt
}


#######################################################################
#
# Main script body
#
#######################################################################

# Create the state.txt file so ICA knows we are running
UpdateTestState $ICA_TESTRUNNING

# Source the constants file
if [ -e constants.sh ]; then
    . constants.sh
else
    LogMsg "WARN: Unable to source the constants file."
fi

# Cleanup any old summary.log files
if [ -e ~/summary.log ]; then
    rm -rf ~/summary.log
fi

if [ -e ~/lsvmbus.log ]; then
    rm -rf ~/lsvmbus.log
fi

if [ ! "${TC_COVERED}" ]; then
    LogMsg "The TC_COVERED variable is not defined!"
    echo "The TC_COVERED variable is not defined!" >> ~/summary.log
fi

echo "This script covers test case: ${TC_COVERED}" >> ~/summary.log

dos2unix utils.sh
. utils.sh

vmbus_version=$(dmesg | grep "Vmbus version" | awk -F: '{print $(NF)}' | awk -F. '{print $1}')
if [ "$vmbus_version" -lt 3 ]; then
	LogMsg "Info: Host version older than 2012R2. Skipping test."
	UpdateSummary "Info: Host version older than 2012R2. Skipping test."
	SetTestStateSkipped
	exit 1
fi

GetDistro
case $DISTRO in
    redhat_5|centos_5*)
        LogMsg "Error: RedHat/CentOS 5.x not supported."
        UpdateSummary "Error: RedHat/CentOS 5.x not supported."
        UpdateTestState $ICA_TESTFAILED
        exit 1
    ;;
esac

if [[ "$DISTRO" =~ "redhat" ]] || [[ "$DISTRO" =~ "centos" ]] || [[ "$DISTRO" =~ "fedora" ]]; then
    if ! rpm -q hyperv-tools; then
        yum install -y hyperv-tools
    fi
fi

# check if lsvmbus exists
lsvmbus_path=$(command -v lsvmbus)
if [ -z "$lsvmbus_path" ]; then
    LogMsg "Error: lsvmbus tool not found!"
    UpdateSummary "Error: lsvmbus tool not found!"
    UpdateTestState $ICA_TESTFAILED
    exit 1
fi

$lsvmbus_path -vvv >> lsvmbus.log

#Check number of NICs on VM
nics=$( grep -o "Synthetic network adapter" lsvmbus.log | wc -l)
if [ "$nics" -gt 1 ]; then
  LogMsg "Counting the cores spread only for the first NIC.."
  UpdateSummary "Counting the cores spread only for the first NIC..."
  sed -i ':a;N;$!ba;s/Synthetic network adapter/ignored adapter/2' lsvmbus.log && \
  sed -i '/ignored adapter/,$d' lsvmbus.log
fi

while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line =~ "Synthetic network adapter" ]]; then
        token="adapter"
    fi

    if [[ $line =~ "Synthetic SCSI Controller" ]]; then
        token="controller"
    fi

    if [ $token ] && [[ $line =~ "target_cpu" ]]; then
        if [[ $token == "adapter" ]]; then
            ((network_counter++))
        elif [[ $token == "controller" ]]; then
            ((scsi_counter++))
        fi
    fi
done < "lsvmbus.log"
# the cpu count that attached to the network driver is less than 8
# the cpu count that attached to the scsi controller is (N+3)/4
if [ "$VCPU" -gt 8 ];then
    network_CPU=8
else
    network_CPU=$VCPU
fi

if [ "$network_counter" != "$network_CPU" ] && [ "$scsi_counter" != $((VCPU+3))/4 ]; then
    error_msg="Error: values are wrong. Expected for network adapter: $network_CPU and actual: $network_counter;
    expected for scsi controller: 2, actual: $scsi_counter."

    LogMsg "$error_msg"
    UpdateSummary "$error_msg"
    UpdateTestState $ICA_TESTFAILED
    exit 1
fi

UpdateSummary "Network driver is spread on $network_counter core(s) as expected, actual cpu count in os is '$VCPU'."
UpdateSummary "Storage driver is spread on all $scsi_counter core(s) as expected."

UpdateSummary "Test completed successfully."
UpdateTestState $ICA_TESTCOMPLETED
exit 0
