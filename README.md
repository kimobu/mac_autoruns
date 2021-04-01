# Mac Autoruns
This program performs some of the same functions as the Sys Internals tool autoruns. It enumerates a subset of the persistence locations identified by SentinelOne.

# Requirements
N/A
# Usage

The program takes no arguments.
`./MAC\ Autoruns`

`sudo` is required to enumerate cron entries and system level plist files. The program can be run with normal user privileges, but the data returned will be incomplete.

## Information

The program will enumerate the programs called by Launch Agents/Daemons and hash those programs. For cron jobs, each cron entry will be returned, but no hashing will occur.

# Resources
* [Autoruns](https://docs.microsoft.com/en-us/sysinternals/downloads/autoruns)
* [How Malware Persists on MacOS](https://www.sentinelone.com/blog/how-malware-persists-on-macos/)

# Changelog
20200621 - Added first take at extracting items from the background items plist; displaying certificate chain

20200607 - Added Swift build action
