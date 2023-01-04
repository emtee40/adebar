#!/bin/bash
# obtaining a backup of any app using "root powers"

ERROR_SYNTAX=1
ERROR_DEVICE_MISSING=2
ERROR_NO_ROOT=3
ERROR_FILE_NOT_FOUND=5

opts='ns:h'

ADBOPTS=
ANDROIDSERIAL=
HELP=0
GETAPK=1
while getopts $opts arg; do
  case $arg in
    :) echo "$0 requires an argument:"; exit $ERROR_SYNTAX ;;
    n) GETAPK=0 ;;
    s) if [[ -n "$(adb devices | grep $OPTARG)" ]]; then
         ADBOPTS="-s $OPTARG"
         ANDROID_SERIAL="$OPTARG"
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
  echo "Obtaining APK and data of a given app using root powers"
  echo
  echo "Syntax:"
  echo "  $0 -h"
  echo -e "  $0 [-s <serial>] [-n] <packageName> [targetDirectory]\n"
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
    echo -e "specified target directory '$2' does not exist, exiting.\n"
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

# --=[ Performing the backup ]=--
echo "Backing up '$pkg' to directory: $BACKUPDIR"
if [[ $GETAPK -gt 0 ]]; then
  ${BINDIR}/getapk $pkg $ANDROID_SERIAL
  [[ "$BACKUPDIR" != "." ]] && {
    if [[ -f "${pkg}.apk" ]]; then
      mv "${pkg}.apk" "$BACKUPDIR"
    elif [[ -d "$pkg" ]]; then
      mv "$pkg" "$BACKUPDIR"
    else
      echo -e "Ouch: could not obtain the APK for '$pkg', sorry…\n";
    fi
  }
fi
adb $ADBOPTS shell -e none -n -T "su -c 'tar cf - data/user/0/${pkg}'" >"${BACKUPDIR}/user-${pkg}.tar"
adb $ADBOPTS shell -e none -n -T "su -c 'tar cf - data/user_de/0/${pkg}'" >"${BACKUPDIR}/user_de-${pkg}.tar"
