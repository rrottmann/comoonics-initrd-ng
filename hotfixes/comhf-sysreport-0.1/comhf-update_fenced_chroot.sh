#!/bin/bash

#****h* comoonics-bootimage/hotfixes/com-sysinfo/update_fenced_chroot.sh
#  NAME
#    update_fenced_chroot.sh
#    $id $
#  DESCRIPTION
#*******
#
# $Id: comhf-update_fenced_chroot.sh,v 1.1 2007-04-19 15:42:27 mark Exp $
#
# @(#)$File$
#
# Copyright (c) 2007 ATIX GmbH.
# Einsteinstrasse 10, 85716 Unterschleissheim, Germany
# All rights reserved.
#
# This software is the confidential and proprietary information of ATIX
# GmbH. ("Confidential Information").  You shall not
# disclose such Confidential Information and shall use it only in
# accordance with the terms of the license agreement you entered into
# with ATIX.
#

# This package is only a temporary workaround for the following fixes:
# 1. dynamically update the local chroot environment (fenceack-server)
# 2. collect system information from a fenceack-server shell

#path where the comoonics-bootimage files reside
basedir="/opt/atix/comoonics-bootimage"

# include libraries
. $basedir/create-gfs-initrd-lib.sh
if [ -e $basedir/boot-scripts/etc/boot-lib.sh ]; then
  source $basedir/boot-scripts/etc/boot-lib.sh
  initEnv
fi


function usage() {
	echo "`basename $0` [ [-h] | [-v] ]"
	echo "  -h help "
	echo "  -v be chatty"
	echo "  -V show version"	
}

logfile=/var/log/update_fenced_chroot.log
function log() {
	if [ "$verbose" ]; then
		echo $*
	fi
	echo "$(date): $*" >> $logfile
}

function rc2str() {
	if [ $1 -ne 0 ]; then
		echo "[ ERROR ]"
	else
		echo "[   OK  ]"
	fi
}


# overwrites function in create-gfs-initrd-lib.sh
function copy_file() {
  local filename=$1
  local dest=$2
  cp -auf $filename ${dest}
}


while getopts vhV option ; do
	case "$option" in
	    V) # version
		echo "$0 Version '$Revision $'"
		exit 0
		;;
	    h) # help
		usage
		exit 0
		;;
		v) #verbose
		verbose=1
		;;
	    *)
		echo "Error wrong option."
		usage
		exit 1
		;;
	esac
done
shift $(($OPTIND - 1))

log "starting update_fenced_chroot"


# dep_filename is the file where all dependent files are to be taken from
dep_filename=/etc/comoonics/comhf-update_fenced_chroot/files.list

if [ ! -e $dep_filename ]; then
	log "dependency file $dep_filename does not exist"
	exit 1
fi

#
# rpm_filename is the file where all dependent files are to be taken from
rpm_filename=/etc/comoonics/comhf-update_fenced_chroot/rpms.list

if [ ! -e $rpm_filename ]; then
	log "rpm_filename $rpm_filename does not exist!"
fi

# defauts
# directory, where the chroot environment lives
FENCE_CHROOT=/tmp/fence_tool

#include /etc/sysconfig/cluster

if [ -e /etc/sysconfig/cluster ]; then
	. /etc/sysconfig/cluster
fi

chrootdir=$FENCE_CHROOT

# extracting rpms
if [ -n "$rpm_filename" ] && [ -e "$rpm_filename" ]; then
  extract_all_rpms $rpm_filename $chrootdir $rpm_dir $verbose
  rc=$?
  log "Extracted rpms: $(rc2str $rc)" 
fi

log "Retreiving dependent files"

files=( $(get_all_files_dependent $dep_filename $verbose | sort -u | grep -v "^.$" | grep -v "^..$") )
rc=$?

log "found ${#files[@]}: $(rc2str $rc)"

log "Copying files..."
cd $chrootdir
i=0
while [ $i -lt ${#files[@]} ]; do
  file=${files[$i]}
  #copy directories
  if [ -d $file ]; then
    log "Directory $file => ${mountpoint}/$file"
    create_dir ${chrootdir}/$file
    copy_file $file ${chrootdir}/$(dirname $file)
  #copy @map srcfile dest
  elif [ ! -e "$file" ] && [ "$file" = '@map' ]; then
    i=$(( $i+1 ))
    file=${files[$i]}
    i=$(( $i+1 ))
    todir=${files[$i]}
    if [ -d $file ]; then
      log "Directory mapping $file => ${chrootdir}/$todir"
      create_dir ${chrootdir}/$todir
      for file2 in $(ls -1 $file/*); do
         copy_file $file/\* ${chrootdir}/$todir/
      done
    else
      log "Copy file (@map) $file => ${chrootdir}/$todir"
      dirname=`dirname $file`
      create_dir ${chrootdir}$todir
      copy_file $file ${chrootdir}$todir
    fi
  # only copy file
  else
    log "Copy file (std) $file => $chrootdir/$dirname"
    dirname=`dirname $file`
    create_dir ${chrootdir}$dirname
    copy_file $file ${chrootdir}$dirname
  fi
  i=$(( $i+1 ))
done
rc=$?
log "copy files: $(rc2str $rc)"

