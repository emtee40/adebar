#!/usr/bin/env bash
# restoring an app backup obtained by root_appbackup.sh using root powers
#
# !!! WARNING !!!
# !!! This is totally untested. Use at your own risk !!!
# !!! DRAGONS !!! BOMBS !!! TOMATOES !!!
#
# If you're nuts enough to give this a try, please report your success.

ERROR_SYNTAX=1
ERROR_DEVICE_MISSING=2
ERROR_NO_ROOT=3
ERROR_FILE_NOT_FOUND=5
ERROR_NO_APK=99
ERROR_NOT_INSTALLED=101

opts='ns:h'

ADBOPTS=
HELP=0
SETAPK=1
while getopts $opts arg; do
  case $arg in
    :) echo "$0 requires an argument:"; exit $ERROR_SYNTAX ;;
    n) SETAPK=0 ;;
    s) if [[ -n "$(adb devices | grep $OPTARG)" ]]; then
         ADBOPTS="-s $OPTARG"
       else
         echo "Device with serial $OPTARG is not present."
         exit $ERROR_DEVICE_MISSING
       fi ;;
    h) HELP=1 ;;
  esac
done
shift $((OPTIND-1))

# --=[ Syntax ]=--
[[ -z "$1" || $HELP -gt 0 ]] && {
  echo -e "\n\033[1;37mroot_backup\033[0m"
  echo "Restoring APK and data of a given app using root powers"
  echo
  echo "Syntax:"
  echo "  $0 -h"
  echo -e "  $0 [-s <serial>] [-n] <packageName> [sourceDirectory]\n"
  echo "Parameters:"
  echo "  -h         : show this help"
  echo "  -n         : noAPK (backup data only)"
  echo -e "  -s <serial>: serial of the device (needed if multiple devices are connected)\n"
  echo "Examples:"
  echo "  $0 com.foo.bar"
  echo -e "  $0 com.foo.bar backups\n"
  [[ $HELP -gt 0 ]] && exit 0
  exit $ERROR_SYNTAX
}

# --=[ Parameters ]=--
BINDIR="$(dirname "$(readlink -mn "${0}")")" #"
pkg=$1
if [[ -n "$2" ]]; then
  if [[ -d "$2" ]]; then
    BACKUPDIR="$2"
  else
    echo -e "specified source directory '$2' does not exist, exiting.\n"
    exit $ERROR_FILE_NOT_FOUND
  fi
else
  BACKUPDIR="."
fi

# --=[ root-check ]=--
adb $ADBOPTS shell "su -c 'ls /data'" >/dev/null 2>&1
rc=$?
[[ $rc -ne 0 ]] && {
  echo -e "Sorry, looks like the device is not rooted: we cannot call to 'su'.\n"
  exit $ERROR_NO_ROOT
}

#--=[ check if all files are available ]=--
[[ ! -f "${BACKUPDIR}/user-${pkg}.tar" ]] && {
  echo -e "could not find '${BACKUPDIR}/user-${pkg}.tar', aborting.\n"
  exit $ERROR_FILE_NOT_FOUND
}
[[ ! -f "${BACKUPDIR}/user_de-${pkg}.tar" ]] && {
  echo -e "could not find '${BACKUPDIR}/user_de-${pkg}.tar', aborting.\n"
  exit $ERROR_FILE_NOT_FOUND
}
[[ $SETAPK -gt 0 && ! -f "${BACKUPDIR}/${pkg}.apk" && ! -d "${BACKUPDIR}/${pkg}" ]] && {
  echo -e "could not find any APK for '$pkg' in '${BACKUPDIR}', exiting.\n"
  exit $ERROR_FILE_NOT_FOUND
}

# --=[ do the restore ]=--
USER_TAR="${BACKUPDIR}/user-${pkg}.tar"
USER_DE_TAR="${BACKUPDIR}/user_de-${pkg}.tar"
EXTDATA_TAR="${BACKUPDIR}/extdata-${pkg}.tar"

set -ex

# Install APK(s)
if [[ $SETAPK -gt 0 ]]; then
  if [[ -f "${BACKUPDIR}/${pkg}.apk" ]]; then
    adb $ADBOPTS install "${BACKUPDIR}/${pkg}.apk"
  elif [[ -d "${BACKUPDIR}/${pkg}" ]]; then
    multipath="${BACKUPDIR}/${pkg}/*.apk"
    adb $ADBOPTS install-multiple $multipath
  else
    echo -e "Ooops! No APKs to install?\n"
    exit $ERROR_NO_APK
  fi
fi

# Find the PKGUID to (later) own the data to. If we cannot identify it, processing should be stopped
PKGUID=$(adb $ADBOPTS shell "su -c 'cat /data/system/packages.list'" | grep "${pkg} " | cut -d' ' -f2)
[[ -z $PKGUID ]] && PKGUID=$(adb $ADBOPTS shell "dumpsys package ${pkg}" | grep "userId" | head -n1 | cut -d'=' -f2)
[[ $(echo "$PKGUID" | grep -E '^[0-9]+$') ]] || {   # UID must be numeric and not NULL
  if [[ -z "(adb $ADBOPTS shell pm list packages|grep package:${pkg})" ]]; then
    echo "Cannot find PKGUID; package '${pkg}' is not installed. Exiting."
  else
    echo "Cannot find PKGUID, exiting."
  fi
  exit $ERROR_NOT_INSTALLED
}

# Make sure the app closes and stays closed
adb $ADBOPTS shell "su -c 'pm disable $pkg'"
adb $ADBOPTS shell "su -c 'am force-stop $pkg'"
adb $ADBOPTS shell "su -c 'pm clear $pkg'"

# Restore data files
cat "$USER_TAR" | adb $ADBOPTS shell -e none -T "su -c 'tar xf -'"
cat "$USER_DE_TAR" | adb $ADBOPTS shell -e none -T "su -c 'tar xf -'"
[[ -f "$EXTDATA_TAR" ]] && cat "$EXTDATA_TAR" | adb $ADBOPTS shell -e none -T "su -c 'tar xf -'"

# Remove cache contents
adb $ADBOPTS shell "su -c 'rm -rf /data/user{,_de}/0/${pkg}/{cache,code_cache}'"

# Adapt to new ownership
adb $ADBOPTS shell "su -c 'chown -R $PKGUID:$PKGUID /data/user/0/${pkg} /data/user_de/0/${pkg}'"
[[ -f "$EXTDATA_TAR" ]] &&
    adb $ADBOPTS shell "su -c 'chgrp -R $((PKGUID+20000)) /data/media/0/Android/data/${pkg}'"

# Restore SELinux contexts
adb $ADBOPTS shell "su -c 'restorecon -F -R /data/user/0/${pkg}'"
adb $ADBOPTS shell "su -c 'restorecon -F -R /data/user_de/0/${pkg}'"
adb $ADBOPTS shell "su -c 'restorecon -F -R /data/media/0/Android/data/${pkg}'"

# Reenable package
adb $ADBOPTS shell "su -c 'pm enable $pkg'"
