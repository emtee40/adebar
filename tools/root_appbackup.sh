#!/bin/bash
# obtaining a backup of any app using "root powers"

opts='s:h'

ADBOPTS=
ANDROIDSERIAL=
HELP=0
while getopts $opts arg; do
  case $arg in
    :) echo "$0 requires an argument:"; exit 1 ;;
    s) if [[ -n "$(adb devices | grep $OPTARG)" ]]; then
         ADBOPTS="-s $OPTARG"
         ANDROID_SERIAL="$OPTARG"
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
  echo "Obtaining APK and data of a given app using root powers"
  echo
  echo "Syntax:"
  echo -e "  $0 [-s <serial>] <packageName> [targetDirectory]\n"
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
    echo -e "specified target directory '$2' does not exist, exiting.\n"
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

# --=[ Performing the backup ]=--
echo "Backing up '$pkg' to directory: $BACKUPDIR"
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
adb $ADBOPTS shell -e none -n -T "su -c 'tar cf - data/user/0/${pkg}'" >"${BACKUPDIR}/user-${pkg}.tar"
adb $ADBOPTS shell -e none -n -T "su -c 'tar cf - data/user_de/0/${pkg}'" >"${BACKUPDIR}/user_de-${pkg}.tar"
