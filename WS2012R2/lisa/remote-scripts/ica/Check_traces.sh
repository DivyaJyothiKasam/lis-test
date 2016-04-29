#!/bin/bash

#####################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved.
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
#####################################################################

# Description:
#	This script checks if "Call Trace" message appears in the system logs
# and runs in the background.


function CheckForError()
{   while true; do
        [[ -f "/var/log/syslog" ]] && logfile="/var/log/syslog" || logfile="/var/log/messages"
        content=$(grep -i "Call Trace" $logfile)
        if [[ -n $content ]]; then
            LogMsg "Warning: System get Call Trace in $logfile"
            echo "Warning: System get Call Trace in $logfile" >> ~/summary.log
            break
        fi

    done
}


CheckForError &

exit 0