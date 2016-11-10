#!/bin/bash
#
# A SUSE Linux start/stop script for Java daemons.
#
# Home page: http://www.source-code.biz
# License:   GNU/LGPL V2.1 (http://www.gnu.org/licenses/lgpl.html)
# Copyright 2006 Christian d'Heureuse, Inventec Informatik AG, Switzerland.
#
# History:
# 2006-06-27 Christian d'Heureuse: Script created.
# 2006-07-02 chdh: Minor improvements.
# 2006-07-10 chdh: Changes for SUSE 10.0.
# 2009-08-21 chdh: Changes for SUSE 11.1.
#   (The name of the Java binary reported by "ps -o comm" may be "java.bin" instead of "java")
# 2009-09-16 chdh: nohup replaced by setsid.

### BEGIN INIT INFO
# Provides:                   javaDaemonTest
# Required-Start:             $network $local_fs $remote_fs
# X-UnitedLinux-Should-Start: $named sendmail
# Required-Stop:              $network $local_fs $remote_fs
# X-UnitedLinux-Should-Stop:  $named sendmail
# Default-Start:              3 5
# Default-Stop:               0 1 2 6
# Short-Description:          JavaDaemonTest
# Description:                A Java daemon for testing.
### END INIT INFO


scriptFile=$(readlink -fn $0)                   # the absolute, dereferenced path of this script file
scriptDir=$(dirname $scriptFile)                           # absolute path of the script directory

serviceName="JavaDaemonTest"                               # service name
javaArgs="-cp ./dist/JavaProject3.jar JavaDaemonTest"                                  # arguments for Java launcher
serviceUser="www-data"                                     # OS user name for the service
serviceGroup="www-data"                                    # OS group name for the service
maxShutdownTime=15                                         # maximum number of seconds to wait for the daemon to terminate normally

######## derived variables
applDir="$scriptDir"                                       # home directory of the service application
serviceNameLo="${serviceName,,}"                             # service name with the first letter in lowercase
serviceLogFile="/var/log/$serviceNameLo.log"               # log file for StdOut/StdErr
pidFile="/var/run/$serviceNameLo.pid"                      # name of PID file (PID = process ID number)
javaExe="/usr/bin/java"                                   # file name of the Java application launcher executable
javaCommandLine="$javaExe $javaArgs"                       # command line to start the Java service application
javaCommandLineKeyword="$serviceName"                    # a keyword that occurs on the commandline, used to detect an already running service process and to distinguish it from others

serviceUserHome="$applDir"                                 # home directory of the service user
rcFileBaseName="rc$serviceNameLo"                          # basename of the "rc" symlink file for this script
rcFileName="/usr/local/sbin/$rcFileBaseName"               # full path of the "rc" symlink file for this script
etcInitDFile="/etc/init.d/$serviceNameLo"                  # symlink to this script from /etc/init.d
#debug=y  #display the variables before executing

 if [ ! -z "$debug" ]; then
echo "########################debug"
echo scriptFile $scriptFile
echo scriptDir $scriptDir
echo applDir $applDir
echo serviceName $serviceName
echo serviceNameLo $serviceNameLo
echo serviceUser $serviceUser
echo serviceUserHome $serviceUserHome
echo serviceGroup $serviceGroup
echo serviceLogFile $serviceLogFile
echo maxShutdownTime $maxShutdownTime
echo pidFile $pidFile
echo javaCommand $javaCommand
echo javaExe $javaExe
echo javaArgs $javaArgs
echo javaCommandLine $javaCommandLine
echo javaCommandLineKeyword $javaCommandLineKeyword
echo rcFileBaseName $rcFileBaseName
echo rcFileName $rcFileName
echo etcInitDFile $etcInitDFile
echo "########################debug"
fi

######################## rc.status functions
# /etc/rc.status
# Definition of boot script return messages
#
_rc_status=0
_rc_status_all=0

rc_check ()
{
    _rc_status_ret=$?
    test $_rc_status_ret -eq 0 || _rc_status=$_rc_status_ret
    test $_rc_status     -eq 0 || _rc_status_all=$_rc_status
    return $_rc_status_ret
}

rc_reset ()
{
    _rc_status=0
    _rc_status_all=0
    rc_check
    return 0
}


rc_status ()
{
    rc_check
    _rc_status_ret=$_rc_status
    echo ""
    return $_rc_status_ret
}


rc_failed ()
{
    rc_reset
    case "$1" in
    [0-7]) _rc_status=$1 ;;
    "")    _rc_status=1
    esac
    rc_check
    return $_rc_status
}

rc_exit ()
{
    exit $_rc_status_all
}
######################## rc.status functions



# Makes the file $1 writable by the group $serviceGroup.
makeFileWritable() {
   local filename="$1"
   touch $filename || return 1
   chown $serviceUser:$serviceGroup $filename || return 1
   chgrp $serviceGroup $filename || return 1
   chmod g+w $filename || return 1
   return 0;
   }

# Returns 0 if the process with PID $1 is running.
checkProcessIsRunning() {
   local pid="$1"
   if [ -z "$pid" -o "$pid" == " " ]; then return 1; fi

   if [ ! -e /proc/$pid ]; then return 1; fi

   return 0; }

# Returns 0 if the process with PID $1 is our Java service process.
checkProcessIsOurService() {
   local pid="$1"
   local cmd="$(ps -p $pid --no-headers -o comm)"
   if [ -z "$cmd" ]; then return 1; fi
   if [ "$cmd" != "java" ]; then return 1; fi
   grep -q --binary -F "$javaCommandLineKeyword" /proc/$pid/cmdline
   if [ $? -ne 0 ]; then return 1; fi
   return 0; }

# Returns 0 when the service is running and sets the variable $servicePid to the PID.
getServicePid() {
   if [ ! -f $pidFile ]; then return 1; fi
   servicePid="$(<$pidFile)"

   checkProcessIsRunning $servicePid || return 1
   checkProcessIsOurService $servicePid || return 1
   return 0; }

startServiceProcess() {
   cd $applDir || return 1
   rm -f $pidFile
   makeFileWritable $pidFile || return 1
   makeFileWritable $serviceLogFile || return 1
   local cmd="setsid $javaCommandLine >>$serviceLogFile 2>&1 & echo \$! >$pidFile"
   echo "Executing $cmd"
   su $serviceUser -s $SHELL -c "$cmd" || return 1
   sleep 0.1
   servicePid="$(<$pidFile)"
   if checkProcessIsRunning $servicePid; then :; else
      echo -ne "\n$serviceName start failed, see logfile."
      return 1
      fi
   return 0; }

stopServiceProcess() {
   kill $servicePid || return 1
   for ((i=0; i<$maxShutdownTime*10; i++)); do
      checkProcessIsRunning $servicePid
      if [ $? -ne 0 ]; then
         rm -f $pidFile
         return 0
         fi
      sleep 0.1
      done
   echo -e "\n$serviceName did not terminate within $maxShutdownTime seconds, sending SIGKILL..."
   kill -s KILL $servicePid || return 1
   local killWaitTime=15
   for ((i=0; i<killWaitTime*10; i++)); do
      checkProcessIsRunning $servicePid
      if [ $? -ne 0 ]; then
         rm -f $pidFile
         return 0
         fi
      sleep 0.1
      done
   echo "Error: $serviceName could not be stopped within $maxShutdownTime+$killWaitTime seconds!"
   return 1; }

runInConsoleMode() {
   getServicePid
   if [ $? -eq 0 ]; then echo "$serviceName is already running"; return 1; fi
   cd $applDir || return 1
   su $serviceUser  -s $SHELL  -c "$javaCommandLine" || return 1
   if [ $? -eq 0 ]; then return 1; fi
   return 0; }

startService() {
   getServicePid
   if [ $? -eq 0 ]; then echo -n "$serviceName is already running"; rc_failed 0; rc_status -v; return 0; fi
   echo -n "Starting $serviceName   "
   startServiceProcess
   if [ $? -ne 0 ]; then rc_failed 1; rc_status -v; return 1; fi
   rc_failed 0
   rc_status -v
   return 0; }

stopService() {
   getServicePid
   if [ $? -ne 0 ]; then echo -n "$serviceName is not running"; rc_failed 0; rc_status -v; return 0; fi
   echo -n "Stopping $serviceName   "
   stopServiceProcess
   if [ $? -ne 0 ]; then rc_failed 1; rc_status -v; return 1; fi
   rc_failed 0
   rc_status -v
   return 0; }

# Returns (0 to the system) when the service is running
checkServiceStatus() {
   echo -n "Checking for $serviceName:   "
   # Returns 0 when the service is running
   if getServicePid; then
      echo "active"
      rc_failed 0
    else
      echo "*Not* active"
      rc_failed 3
      fi
   rc_status -v
   return 0; }

installService() {
   getent group $serviceGroup >/dev/null 2>&1
   if [ $? -ne 0 ]; then
      echo Creating group $serviceGroup
      groupadd -r $serviceGroup || return 1
      fi
   id -u $serviceUser >/dev/null 2>&1
   if [ $? -ne 0 ]; then
      echo Creating user $serviceUser
      useradd -r -c "user for $serviceName service" -g $serviceGroup -G users -d $serviceUserHome $serviceUser
      fi
   ln -s $scriptFile $rcFileName || return 1
   ln -s $scriptFile $etcInitDFile || return 1
   insserv $serviceNameLo || return 1
   echo $serviceName installed.
   echo You may now use $rcFileBaseName to call this script.
   return 0; }

uninstallService() {
   insserv -r $serviceNameLo || return 1
   rm -f $rcFileName
   rm -f $etcInitDFile
   echo $serviceName uninstalled.
   return 0; }

main() {
   rc_reset

   case "$1" in
      console)                                             # runs the Java program in console mode
         runInConsoleMode
         ;;
      start)                                               # starts the Java program as a Linux service
         startService
         ;;
      stop)                                                # stops the Java program service
         stopService
         ;;
      restart)                                             # stops and restarts the service
         stopService && startService
         ;;
      status)                                              # displays the service status
         checkServiceStatus
         ;;
      install)                                             # installs the service in the OS
         installService
         ;;
      uninstall)                                           # uninstalls the service in the OS
         uninstallService
         ;;
      *)
         echo "Usage: $0 {console|start|stop|restart|status|install|uninstall}"
         exit 1
         ;;
      esac
   rc_exit;

   }

main $1
