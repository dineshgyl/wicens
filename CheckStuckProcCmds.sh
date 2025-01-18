#!/bin/sh
######################################################################
# CheckStuckProcCmds.sh
# To monitor & check if any 'nvram' or 'wl' commands are running
# and see if there's a hang during execution of such commands.
# When such a "stuck" command is found, this script also kills
# the process after a short wait (~10 secs) & logs the event.
#
# EXAMPLE CALLS:
# ./CheckStuckProcCmds.sh
# ./CheckStuckProcCmds.sh -help
# ./CheckStuckProcCmds.sh -setcronjob
# ./CheckStuckProcCmds.sh -setcronjob=2
#---------------------------------------------------------------------
# Creation Date: 2022-Jun-12 [Martinski W.]
# Last Modified: 2022-Dec-27 [Martinski W.]
#
readonly VERSION="0.7.8"
######################################################################

#--------------------------------------------#
# START CUSTOMIZABLE PARAMETERS SECTION.
#--------------------------------------------#
CRON_Mins=5   # Cron Job default frequency in minutes #

# Modify these variables as necessary for your environment #
TheLOGdir="/opt/var/log"          # LOG directory #
TheTRCdir="/opt/var/log/Trace"    # TRACE directory #
#--------------------------------------------#
# END CUSTOMIZABLE PARAMETERS SECTION.
#--------------------------------------------#

set -u

ScriptFName1="${0##*/}"
ScriptFName2="${ScriptFName1%.*}"
ScriptFolder="$(/usr/bin/dirname "$0")"
thePID="$(printf "%05d" "$$")"

DoMyLogger=1
ShowDebugMsgs=0
ShowMyDbgMsgs=0

CRON_Set=0
UseKillCmd=1
DelaySecs=10
MaxDiffSecs=5
MaxTraceIndex=99999
CRON_Tag="CheckStuckCmds"

if [ "$ScriptFolder" != "." ]
then
   ScriptFPath="$0"
else
   ShowDebugMsgs=1
   ScriptFolder="$(pwd)"
   ScriptFPath="$(pwd)/$ScriptFName1"
fi

echoCMD=/bin/echo

_25KBytes=25600
MaxLogSize=$_25KBytes

TheLOGtag=""
TheBKPtag="_BKP"
SetBKPLogFile=1
DEF_LOG_Dir=/tmp/var/tmp
DEF_TRC_Dir=/tmp/var/tmp

[ ! -d "$TheLOGdir" ] && mkdir "$TheLOGdir" 2>/dev/null
[ ! -d "$TheTRCdir" ] && mkdir "$TheTRCdir" 2>/dev/null

[ ! -d "$TheLOGdir" ] && TheLOGdir="$DEF_LOG_Dir"
[ ! -d "$TheTRCdir" ] && TheTRCdir="$DEF_TRC_Dir"
[ ! -d "$TheTRCdir" ] && mkdir "$TheTRCdir" 2>/dev/null

TheLogName="${ScriptFName2}${TheLOGtag}"
BkpLogName="${TheLogName}${TheBKPtag}"

TheLogFile="${TheLOGdir}/${TheLogName}.LOG"
BkpLogFile="${TheLOGdir}/${BkpLogName}.LOG"

ScriptNDXname="${ScriptFName2}.INDX.txt"
StuckCmdsNDXfile="${TheTRCdir}/${ScriptNDXname}"

## File to store LAST known process cmds possibly "stuck" ##
StuckCmdsLOGname="StuckProcCmds"
StuckCmdsLOGfile="${TheLOGdir}/${StuckCmdsLOGname}.LOG.txt"

## 24-hour format (e.g. "2020-03-01 15:19:14") ##
SysLogTimeFormat="%Y-%m-%d %H:%M:%S"

## 12-hour format (e.g. "2020-Mar-01 03:19:14 PM") ##
MyLogTimeFormat="%Y-%b-%d %I:%M:%S %p"

# The "delete mark" #
DelMark="**=OK=**"

##################################################################
_ShowUsage_()
{
   cat <<EOF
-----------------------------------------------
SYNTAX:

./$ScriptFName1 [ -help | -setcronjob | -setcronjob=N ]

Where 'N' is the Cron Job run frequency in minutes.

Current location of log files: [$TheLOGdir]
Current location of trace files: [$TheTRCdir]

You can set new directory locations by modifying the
variables "TheLOGdir" & "TheTRCdir" found at the top
of the script file (CUSTOMIZABLE PARAMETERS SECTION).

EXAMPLE CALLS:

To run & check for any "stuck" 'nvram' or 'wl' commands:
   ./$ScriptFName1

To get this usage & syntax description:
   ./$ScriptFName1 -help

To create a Cron Job to run every 5 minutes [the default]:
   ./$ScriptFName1 -setcronjob

To create a Cron Job to run every 2 minutes [new interval].
   ./$ScriptFName1 -setcronjob=2
-----------------------------------------------
EOF
}

if [ $# -gt 0 ] && [ "$1" = "-help" ]
then _ShowUsage_ ; exit 0 ; fi

if [ $# -gt 0 ] && [ "$1" = "-setdelay" ]
then sleep $DelaySecs ; fi

#################################################################
_GetFileSize_()
{
   local theFileSize=0
   if [ $# -eq 1 ] && [ -n "$1" ] && [ -f "$1" ]
   then
      theFileSize="$(ls -AlF "$1" | awk -F ' ' '{print $5}')"
   fi
   echo "$theFileSize"
}

################################################################
_CheckMyLogFileSize_()
{
   if [ ! -f "$TheLogFile" ] ; then return 1 ; fi

   local TheFileSize=0
   TheFileSize="$(_GetFileSize_ "$TheLogFile")"

   if [ "$TheFileSize" -gt "$MaxLogSize" ]
   then
      if [ "$SetBKPLogFile" -eq 1 ]
      then
         cp -fp "$TheLogFile" "$BkpLogFile"
      fi
      rm -f "$TheLogFile"

      LogMsg="Deleted $TheLogFile [$TheFileSize]"
      _ShowDebugMsg_ "INFO: $LogMsg"
   fi
}

################################################################
_DoInitMyLogFile_()
{
   if [ "$DoMyLogger" -eq 0 ] ; then return 1 ; fi
   _CheckMyLogFileSize_
   if [ ! -f "$TheLogFile" ] ; then touch "$TheLogFile" ; fi
}

################################################################
_ShowMyDGBMsg_()
{
   if [ "$ShowMyDbgMsgs" -eq 0 ] ; then return 1 ; fi

   if [ $# -eq 0 ]
   then echo ""
   elif [ $# -eq 1 ]
   then echo "$1"
   else echo "${1}:" "$2"
   fi
}

##################################################################
_ShowDebugMsg_()
{
   if [ "$ShowDebugMsgs" -eq 0 ] ; then return 1 ; fi

   if [ $# -eq 0 ]
   then echo ""
   elif [ $# -eq 1 ]
   then echo "$1"
   else echo "${1}:" "$2"
   fi
}

################################################################
_GetLastLineFromFile_()
{
   local TheFileSize  TheLastLine=""

   if [ $# -eq 1 ] && [ -n "$1" ] && [ -f "$1" ]
   then
      TheFileSize="$(_GetFileSize_ "$1")"
      if [ "$TheFileSize" -gt 0 ]
      then TheLastLine="$(tail -n 1 "$1")" ; fi
   fi
   echo "$TheLastLine"
}

################################################################
_LastLogFileLineEmpty_()
{
   local TheLastLine=""
   TheLastLine="$(_GetLastLineFromFile_ "$TheLogFile")"
   if [ -z "$TheLastLine" ]
   then return 0
   else return 1
   fi
}

################################################################
_EscapeChars_()
{ printf "%s\n" "$1" | sed 's/[][\/$.*^&-]/\\&/g' ; }

################################################################
_DeleteLastLogFileLineMarked_()
{
   local MarkedLine=0  LastLine

   LastLine="$(_GetLastLineFromFile_ "$TheLogFile")"
   if [ -z "$LastLine" ] ; then return 1 ; fi

   MarkedLine="$($echoCMD "$LastLine" | grep -c "$(_EscapeChars_ "$DelMark")$")"

   if [ "$MarkedLine" -gt 0 ]
   then sed -i '$d' "$TheLogFile" ; fi
}

##################################################################
_AddMsgsToMyLog_()
{
   if [ "$DoMyLogger" -eq 0 ] ; then return 1 ; fi

   local TimeNow  HourMinsNow

   HourMinsNow="$(date +"%I:%M %p")"
   TimeNow="$(date +"$MyLogTimeFormat")"

   if [ $# -eq 0 ]
   then
       echo "" >> "$TheLogFile"
   elif \
      [ $# -eq 1 ]
   then
       echo "$TimeNow $1" >> "$TheLogFile"
   elif \
      [ "$1" = "_NOTIME_" ]
   then
       ## Output *WITHOUT* a TimeStamp ##
       echo "$2" >> "$TheLogFile"
   elif \
      [ "$1" = "_ADDnoMARK_" ] || [ "$1" = "_ADDwithMARK_" ]
   then
       local LogMsg="${TimeNow} ${2}"

       _DeleteLastLogFileLineMarked_

       if [ "$1" = "_ADDnoMARK_" ] || \
          [ "$HourMinsNow" = "12:00 PM" ]
       then
           ## Output msg WITHOUT being "marked" ##
           echo "$LogMsg" >> "$TheLogFile"
       elif \
          [ "$1" = "_ADDwithMARK_" ]
       then
           ## Output "MARKED" msg (to be deleted later) ##
           $echoCMD "$LogMsg $DelMark" >> "$TheLogFile"
       fi
   else
       echo "$TimeNow ${1}: $2" >> "$TheLogFile"
   fi
}

################################################################
_AddMsgToMyLogNoTime_()
{
   _ShowDebugMsg_ "$1"
   _AddMsgsToMyLog_ "_NOTIME_" "$1"
}

################################################################
_AddMsgsToLogs_()
{
   if [ $# -eq 0 ]
   then
       _AddMsgsToMyLog_
   elif [ $# -eq 1 ]
   then
       _AddMsgsToMyLog_ "$1"
   elif [ $# -eq 2 ]
   then
       _AddMsgsToMyLog_ "$1" "$2"
   fi
}

################################################################
_AddDebugLogMsgs_()
{
   if [ $# -eq 0 ]
   then
       _ShowDebugMsg_
       _AddMsgsToMyLog_
   elif [ $# -eq 1 ]
   then
       _ShowDebugMsg_ "$1"
       _AddMsgsToMyLog_ "$1"
   elif [ $# -eq 2 ]
   then
       _ShowDebugMsg_ "$1" "$2"
       _AddMsgsToMyLog_ "$1" "$2"
   fi
}

#################################################################
_ValidCronJobMinutes_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

   local RetCode=1

   case "$1" in
       [1-6] | 10 | 12 | 15 | 20 | 30 | 60)
          RetCode=0 ;;
       *)
          echo "*ERROR*: INVALID number of minutes [$1] for cron job."
          RetCode=1 ;;
   esac
   return "$RetCode"
}

#################################################################
# To avoid using the "cru l" cmd which calls the "nvram" cmd
# which may hang in some cases.
#################################################################
_GetCronJobList_()
{
   local CronJobListFile  CronJobListStr=""
   local CrobTabsDirPath="/var/spool/cron/crontabs"

   if [ ! -d "$CrobTabsDirPath" ] ; then echo "" ; return 1 ; fi

   CronJobListFile="$(ls -1 "$CrobTabsDirPath" | grep -vE "cron.[*]*|.*.new$")"
   if [ -n "$CronJobListFile" ]
   then
      CronJobListStr="$(cat "${CrobTabsDirPath}/$CronJobListFile")"
   fi

   echo "$CronJobListStr"
   return 0
}

##################################################################
_CheckForCronJobSetup_()
{
   if [ "$CRON_Set" -eq 0 ] ; then return 1 ; fi

   local CRU_CMD="/usr/sbin/cru"
   local TheCronMins="*"
   local CronMin=""  CronTag=""  JobPath=""  JobStr=""
   local CRU_Tag="#${CRON_Tag}#"  SetCRONjob=0

   if [ "$CRON_Mins" -gt 1 ]
   then
      if [ "$CRON_Mins" -eq 60 ]
      then TheCronMins="0"
      else TheCronMins="*/$CRON_Mins"
      fi
   fi

   JobStr="$(_GetCronJobList_ | grep " $ScriptFPath ")"

   if [ -n "$JobStr" ]
   then
      CronMin="$(echo "$JobStr" | awk -F ' ' '{print $1}')"
      JobPath="$(echo "$JobStr" | awk -F ' ' '{print $6}')"
      CronTag="$(echo "$JobStr" | awk -F ' ' '{print $7}')"

      if [ "$CronTag" != "$CRU_Tag" ]     || \
         [ "$CronMin" != "$TheCronMins" ] || \
         [ "$JobPath" != "$ScriptFPath" ]
      then
         CronTag="$(echo "$CronTag" | sed "s/#//g")"
         $CRU_CMD d "$CronTag"
         if [ $? -eq 0 ]
         then
            sleep 1
            SetCRONjob=1
            LogMsg="Previous CRON Job [#${CronTag}#] was DELETED."
            _AddDebugLogMsgs_ "INFO: $LogMsg"
         fi
      else
         LogMsg="The CRON Job [#${CronTag}#] is already FOUND."
         _AddDebugLogMsgs_ "INFO: $LogMsg"
         _AddMsgToMyLogNoTime_ "CRON: [$JobStr]"
      fi
   fi

   if [ -z "$JobStr" ] || [ "$SetCRONjob" -eq 1 ]
   then
      $CRU_CMD a $CRON_Tag "$TheCronMins  *  *  *  *  $ScriptFPath"
      if [ $? -eq 0 ]
      then
         sleep 1
         JobStr="$(_GetCronJobList_ | grep " $ScriptFPath ")"

         LogMsg="New CRON Job [$CRU_Tag] was CREATED."
         _AddDebugLogMsgs_ "INFO: $LogMsg"
         _AddMsgToMyLogNoTime_ "CRON: [$JobStr]"
      else
         LogMsg="CANNOT create new CRON Job [$CRU_Tag]"
         _AddDebugLogMsgs_ "CRON_ERROR: $LogMsg"
      fi
   fi
}

##################################################################
_ParseCronJobParameter()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

   local ParamVal=""
   local ParamStr="$(echo "$1" | grep "^-setcronjob")"

   if [ -z "$ParamStr" ] ; then return 1 ; fi

   ParamVal="$(echo "$ParamStr" | grep "=[0-9]\{1,2\}$" | awk -F '=' '{print $2}')"

   if [ -n "$ParamVal" ]
   then
      if _ValidCronJobMinutes_ "$ParamVal"
      then CRON_Mins=$ParamVal
      else return 1
      fi
   fi

   CRON_Set=1
   _CheckForCronJobSetup_
}

_DoInitMyLogFile_

if [ $# -gt 0 ] && [ -n "$1" ] && [ -z "${1##*-setcronjob*}" ]
then _ParseCronJobParameter "$1" ; fi

ProcCount=0
RecheckStuckCmds=0

ProcList=""
ProcEntry1=""
ProcEntryN=""

## Look for 'nvram' or 'wl' commands ##
grepExcept0="grep -w -E nvram|wl"
grepSearch0="grep -w -E 'nvram|wl'"

## Sort PIDs in descending order (from high to low) ##
SortPIDs="sort -n -r -t ' ' -k 1"
FindProcs="top -b -n 1 | $grepSearch0"

##################################################################
_GetTraceFileIndexNumber_()
{
   local TraceIndex  NextTraceIndex

   if [ ! -f "$StuckCmdsNDXfile" ]
   then echo "TraceIndex=1" > "$StuckCmdsNDXfile" ; fi

   TraceIndex="$(grep "^TraceIndex=" "$StuckCmdsNDXfile" | awk -F '=' '{print $2}')"

   if [ -z "$TraceIndex" ] || [ "$TraceIndex" -lt 1 ]
   then TraceIndex=1 ; fi

   NextTraceIndex="$(($TraceIndex + 1))"
   if [ "$NextTraceIndex" -gt "$MaxTraceIndex" ]
   then NextTraceIndex=1 ; fi

   echo "## Next Trace File Index ##" > "$StuckCmdsNDXfile"
   echo "TraceIndex=$NextTraceIndex" >> "$StuckCmdsNDXfile"

   TraceIndex="$(printf "%05d" "$TraceIndex")"

   echo "$TraceIndex"
}

##################################################################
_GetTraceFilePath_()
{
   local TraceFName  TraceIndex
   TraceIndex="$(_GetTraceFileIndexNumber_)"
   TraceFName="${StuckCmdsLOGname}_${TraceIndex}_${thePID}.TRC.txt"
   echo "${TheTRCdir}/${TraceFName}"
}

##################################################################
_ResetStuckProcessCmdsFile_()
{
   if [ -f "$StuckCmdsLOGfile" ]
   then
      local TraceFilePath=""
      TraceFilePath="$(_GetTraceFilePath_)"
      cp -fp "$StuckCmdsLOGfile" "$TraceFilePath"
      rm -f "$StuckCmdsLOGfile"
   fi
}

##################################################################
_ShowParentProcEntry_()
{
   local ProcEntry  ProcCPID  ProcPPID
   local CPID_List=""  PPID_List=""  PPIDfind

   while read -r ProcEntry
   do
      ProcCPID="$(echo $ProcEntry | awk -F ' ' '{print $1}')"
      ProcPPID="$(echo $ProcEntry | awk -F ' ' '{print $2}')"

      if [ -z "$CPID_List"  ]
      then CPID_List="$ProcCPID"
      else CPID_List="$CPID_List $ProcCPID"
      fi

      if [ -z "$PPID_List"  ]
      then PPID_List="$ProcPPID"
      else
         PPIDfind="$(echo "$PPID_List" | grep -cw "$ProcPPID")"
         if [ $PPIDfind -eq 0 ]
         then PPID_List="$PPID_List $ProcPPID" ; fi
      fi
   done <<EOT
$(echo "$1")
EOT

   local NumCnt=1  ProcEntryX=""  MaxCnt=0
   MaxCnt="$(echo "$PPID_List" | wc -w)"

   while [ "$NumCnt" -le "$MaxCnt" ]
   do
      ProcPPID="$(echo "$PPID_List" | cut -d ' ' -f $NumCnt)"
      PPIDfind="$(echo "$CPID_List" | grep -cw "$ProcPPID")"

      if [ "$ProcPPID" -gt 1 ] && [ "$PPIDfind" -eq 0 ]
      then
         ProcEntry="$(top -b -n 1 | grep -w "^[ ]*$ProcPPID")"

         if [ -n "$ProcEntry" ]
         then
            _AddMsgToMyLogNoTime_ "$ProcEntry"

            if [ -z "$ProcEntryX" ]
            then ProcEntryX="$ProcEntry"
            else ProcEntryX="$(printf "%s\n%s\n" "$ProcEntryX" "$ProcEntry")"
            fi
         fi
      fi

      NumCnt=$(($NumCnt + 1))
   done

   if [ -n "$ProcEntryX" ]
   then
      ProcList="$(printf "%s\n%s\n" "$ProcList" "$ProcEntryX")"
      _ShowParentProcEntry_ "$ProcEntryX"
   fi
}

##################################################################
_InsertListOfPIDs_()
{
   local ProcEntry  NumCnt=1
   while IFS= read -r ProcEntry
   do
      sed -i "$NumCnt i $1 $ProcEntry" "$StuckCmdsLOGfile"
      NumCnt=$(($NumCnt + 1))
   done <<EOT
$(echo "$2")
EOT
}

##################################################################
_StuckProcessCmdsRunning_()
{
   ProcCount="$(eval $FindProcs | grep -cv "$grepExcept0")"

   if [ "$ProcCount" -gt 0 ] && [ $# -eq 0 ]
   then
      sleep 3   ## Let's wait some time to double check ##
      ProcCount="$(eval $FindProcs | grep -cv "$grepExcept0")"
   fi

   if [ "$ProcCount" -eq 0 ]
   then LogMsg="FOUND: [$ProcCount]"
   else LogMsg="FOUND_${thePID}: [$ProcCount]"
   fi
   _ShowDebugMsg_ "$LogMsg"

   if [ $# -eq 1 ] && [ "$1" = "-ShowMsg" ]
   then
       _AddMsgsToMyLog_ "_ADDnoMARK_" "$LogMsg"
   elif \
      [ "$ProcCount" -eq 0 ]
   then
       _AddMsgsToMyLog_ "_ADDwithMARK_" "$LogMsg"
   fi

   if [ "$ProcCount" -gt 0 ] ; then return 0 ; fi
   return 1
}

##################################################################
_GetStuckProcessCmds_()
{
   local ProcState="?"
   ProcEntry1=""  ProcEntryN=""  ProcList=""
   ProcCount="$(eval $FindProcs | grep -cv "$grepExcept0")"

   if [ "$ProcCount" -gt 0 ]
   then
      ProcEntry1="$(eval $FindProcs | eval $SortPIDs | \
                    grep -m 1 -v "$grepExcept0")"

      ProcEntryN="$(eval $FindProcs | eval $SortPIDs | \
                    grep -m $ProcCount -v "$grepExcept0")"

      ProcState="$(echo "$ProcEntry1" | awk -F ' ' '{print $4}')"

      if [ "$ProcState" != "S" ] && [ "$ProcState" != "Z" ]
      then ProcEntry1="" ; fi
   fi

   if [ "$ProcCount" -eq 0 ] || [ -z "$ProcEntry1" ]
   then
      LogMsg="FOUND_${thePID}: [$ProcCount][$ProcState]"
      _AddMsgsToMyLog_ "_ADDnoMARK_" "$LogMsg"
   fi
}

##################################################################
_SaveStuckProcessCmds_()
{
   local ProcXPID  ProcPPID  KillEntryLog
   local NowTimeSecs  LastTimeSecs  TimeDiffSecs
   local ProcFound  ProcStrX  ProcStrN  LastTime  CmdState

   _GetStuckProcessCmds_

   if [ -n "$ProcEntry1" ] && [ -n "$ProcEntryN" ]
   then
      ProcList="$ProcEntryN"
      NowTime="$(date +"$SysLogTimeFormat")"

      _AddMsgToMyLogNoTime_ "$ProcEntryN"
      _ShowParentProcEntry_ "$ProcEntryN"

      if [ ! -f "$StuckCmdsLOGfile" ]
      then echo -n " " > "$StuckCmdsLOGfile" ; fi

      ProcStrX="$(_EscapeChars_ "$ProcEntry1")"
      ProcFound="$(grep -c "${ProcStrX}$" "$StuckCmdsLOGfile")"

      LogMsg="FOUND_${thePID}: [$ProcFound][$ProcEntry1]"
      _AddDebugLogMsgs_ "$LogMsg"

      if [ "$ProcFound" -eq 0 ]
      then
         _InsertListOfPIDs_ "$NowTime" "$ProcList"
         RecheckStuckCmds=0
      fi

      if [ "$ProcFound" -gt 0 ] && [ "$UseKillCmd" -eq 1 ]
      then
         ProcStrN="$(grep -m 1 "${ProcStrX}$" "$StuckCmdsLOGfile")"

         if [ -n "$ProcStrN" ]
         then
            LastTime="$(echo "$ProcStrN" | awk -F ' ' '{print $1,$2}')"
            ProcXPID="$(echo "$ProcStrN" | awk -F ' ' '{print $3}')"
            ProcPPID="$(echo "$ProcStrN" | awk -F ' ' '{print $4}')"
            CmdState="$(echo "$ProcStrN" | awk -F ' ' '{print $6}')"

            NowTimeSecs=$(date +%s -d "${NowTime}")
            LastTimeSecs=$(date +%s -d "${LastTime}")
            TimeDiffSecs=$(($NowTimeSecs - $LastTimeSecs))
            KillEntryLog="$NowTime ${ProcEntry1} [KILLED]"

            if [ "$TimeDiffSecs" -ge "$MaxDiffSecs" ]
            then
               LogMsg="PID_${thePID}: [$ProcXPID][$ProcPPID], [$TimeDiffSecs >= $MaxDiffSecs] secs."
               _AddDebugLogMsgs_ "$LogMsg"

               if [ -n "$ProcXPID" ] && [ -n "$ProcPPID" ] && \
                  { [ "$CmdState" = "S" ] || [ "$CmdState" = "Z" ] ; }
               then
                  if [ "$CmdState" = "Z" ]
                  then
                     kill -9 $ProcPPID
                     LogMsg="[kill -9 $ProcPPID][$?]"
                  fi
                  if [ "$CmdState" = "S" ]
                  then
                     kill -9 $ProcXPID
                     LogMsg="[kill -9 $ProcXPID][$?]"
                  fi
                  _AddDebugLogMsgs_ "CMD_${thePID}: $LogMsg"
                  sed -i "1 i $KillEntryLog" "$StuckCmdsLOGfile"
                  sleep 2
                  RecheckStuckCmds=1
               fi
            else
               LogMsg="PID_${thePID}: [$ProcXPID], [$TimeDiffSecs < $MaxDiffSecs] secs."
               _AddDebugLogMsgs_ "$LogMsg"
            fi
         fi
      fi
      return 0
   fi
   return 1
}

#################################
# Initial Quick Check & Exit.
#-------------------------------#
if ! _StuckProcessCmdsRunning_
then
   _ResetStuckProcessCmdsFile_
   exit 0
fi

if ! _LastLogFileLineEmpty_
then echo "" >> "$TheLogFile" ; fi

_AddDebugLogMsgs_ "START_$thePID" "[$0]"

if [ -n "$*" ]
then _AddDebugLogMsgs_ "ARGs_${thePID}: [$*]" ; fi

############################################
if _StuckProcessCmdsRunning_ "-ShowMsg"
then
   _SaveStuckProcessCmds_

   if _StuckProcessCmdsRunning_ "-ShowMsg" && \
      { [ "$ProcCount" -lt 4 ] || \
        [ "$(pidof "$ScriptFName1" | wc -w)" -lt 3 ] ; }
   then $ScriptFPath -setdelay &
   fi

   if [ "$RecheckStuckCmds" -eq 1 ] && \
      ! _StuckProcessCmdsRunning_ "-ShowMsg"
   then _ResetStuckProcessCmdsFile_ ; fi
else
   _ResetStuckProcessCmdsFile_
fi

_AddDebugLogMsgs_ "EXIT_$thePID" "OK."
_AddDebugLogMsgs_

exit 0

#EOF#
