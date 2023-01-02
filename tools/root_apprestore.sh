#!/bin/bash
# restoring an app backup obtained by root_appbackup.sh using root powers
#
# !!! WARNING !!!
# !!! This is totally untested. Use at your own risk !!!
# !!! DRAGONS !!! BOMBS !!! TOMATOES !!!
#
# If you're nuts enough to give this a try, please report your success.

opts='s:h'

ADBOPTS=
HELP=0
while getopts $opts arg; do
  case $arg in
    :) echo "$0 requires an argument:"; exit 1 ;;
    s) if [[ -n "$(adb devices | grep $OPTARG)" ]]; then
         ADBOPTS="-s $OPTARG"
       else
         echo "Device with serial $OPTARG is not present."
         exit 2
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
  echo -e "  $0 [-s <serial>] <packageName> [sourceDirectory]\n"
  echo "Examples:"
  echo "  $0 com.foo.bar"
  echo -e "  $0 com.foo.bar backups\n"
  [[ $HELP -gt 0 ]] && exit 0
  exit 1
}

# --=[ Parameters ]=--
BINDIR="$(dirname "$(readlink -mn "${0}")")" #"
pkg=$1
if [[ -n "$2" ]]; then
  if [[ -d "$2" ]]; then
    BACKUPDIR="$2"
  else
    echo -e "specified source directory '$2' does not exist, exiting.\n"
    exit 5
  fi
else
  BACKUPDIR="."
fi

# --=[ root-check ]=--
adb $ADBOPTS shell "su -c 'ls /data'" >/dev/null 2>&1
rc=$?
[[ $rc -ne 0 ]] && {
  echo -e "Sorry, looks like the device is not rooted: we cannot call to 'su'.\n"
  exit $rc
}

#--=[ check if all files are available ]=--
[[ ! -f "${BACKUPDIR}/user-${pkg}.tar" ]] && {
  echo -e "could not find '${BACKUPDIR}/user-${pkg}.tar', aborting.\n"
  exit 5
}
[[ ! -f "${BACKUPDIR}/user_de-${pkg}.tar" ]] && {
  echo -e "could not find '${BACKUPDIR}/user_de-${pkg}.tar', aborting.\n"
  exit 5
}
[[ ! -f "${BACKUPDIR}/${pkg}.apk" && ! -d "${BACKUPDIR}/${pkg}" ]] && {
  echo -e "could not find any APK for '$pkg' in '${BACKUPDIR}', exiting.\n"
  exit 5
}

# --=[ do the restore ]=--
USER_TAR="${BACKUPDIR}/user-${pkg}.tar"
USER_DE_TAR="${BACKUPDIR}/user_de-${pkg}.tar"

set -ex

# Install APK(s)
if [[ -f "${BACKUPDIR}/${pkg}.apk" ]]; then
    adb $ADBOPTS install "${BACKUPDIR}/${pkg}.apk"
elif [[ -d "${BACKUPDIR}/${pkg}" ]]; then
    multipath="${BACKUPDIR}/${pkg}/*.apk"
    adb $ADBOPTS install-multiple $multipath
else
    echo -e "Ooops! No APKs to install?\n"
    exit 99
fi

# Find the PKGUID to (later) own the data to. If we cannot identify it, processing should be stopped
PKGUID=$(adb $ADBOPTS shell "su -c 'cat /data/system/packages.list'" | grep "${pkg} " | cut -d' ' -f2)
[[ -z $PKGUID ]] && PKGUID=$(adb $ADBOPTS shell "dumpsys package ${pkg}" | grep "userId" | head -n1 | cut -d'=' -f2)
[[ $(echo "$PKGUID" | grep -E '^[0-9]+$') ]] || {   # UID must be numeric and not NULL
    echo "Cannot find PKGUID, exiting."
    exit 101
}

# Make sure the app closes and stays closed
adb $ADBOPTS shell "su -c 'pm disable $pkg'"
adb $ADBOPTS shell "su -c 'am force-stop $pkg'"
adb $ADBOPTS shell "su -c 'pm clear $pkg'"

# Restore data files
cat "$USER_TAR" | adb $ADBOPTS shell -e none -T "su -c 'tar xf -'"
cat "$USER_DE_TAR" | adb $ADBOPTS shell -e none -T "su -c 'tar xf -'"

# Remove cache contents
adb $ADBOPTS shell "su -c 'rm -rf /data/user{,_de}/0/${pkg}/{cache,code_cache}'"

# Adapt to new UID
adb $ADBOPTS shell "su -c 'chown -R $PKGUID:$PKGUID /data/user/0/${pkg} /data/user_de/0/${pkg}'"

# Restore SELinux contexts
adb $ADBOPTS shell "su -c 'restorecon -F -R /data/user/0/${pkg}'"
adb $ADBOPTS shell "su -c 'restorecon -F -R /data/user_de/0/${pkg}'"

# Reenable package
adb $ADBOPTS shell "su -c 'pm enable $pkg'"
