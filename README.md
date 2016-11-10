# java-daemon

How to run a Java Program as a daemon on Debian &amp; Ubuntu

Borrowed from:

> How to run a Java Program as a daemon (service) on Linux (SUSE/openSUSE) using a shell script
> http://www.source-code.biz/snippets/java/7.htm

**I just adapted it to Debian 7**

Changes I made (so far):

- no external dependancy to other scripts : removed dependancy to rc.status (not existing in Debian)
- 1 or 2 quickfix (chown was absent, shell variables, checkProcessIsOurService..)
- replaced sudo by su (why sudo?)
- I separated the derived variables from the main variables


# Why I did it?

I first used the Apache Jakarta Commons Daemon package (Jsvc) http://jakarta.apache.org/commons/daemon/.
The problem is... on prod, after a while it ate 80% CPU.
For no reason (because it happens when the program is waiting on inotify events).
No time to try to fix this.

(side note: I did not consider the Java Service Wrapper http://wrapper.tanukisoftware.org/: not open source, it will not run on my servers)

Then I was about to write a quick script based on nohup, when I found that one.

I find it easier to debug/understand than the /etc/init.d/skeleton
start-stop-deamon is far too opaque to me.



# Features
The shell script (javaDaemonTest.sh) provides the following functionality:

- Start/stop the Java daemon process, according to the Linux system init script convention.
- Run the Java daemon as a different (non-root) Linux user.
- Log error messages and redirect StdOut/StdErr output into a log file.
- Install/uninstall the daemon as a Linux service.
  (The "install" procedure installs the script in /etc/init.d, enables the service in the configured default runlevels,
  creates the "rc" command (symlink) and creates the Linux user (as a system account) and group if necessary).


# Thanks

Thanks to the original Author Christian d'Heureuse for sharing this.

