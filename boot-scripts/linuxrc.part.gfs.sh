#
# $Id: linuxrc.part.gfs.sh,v 1.1 2004-07-31 11:24:43 marc Exp $
#
# @(#)$File$
#
# Copyright (c) 2001 ATIX GmbH.
# Einsteinstrasse 10, 85716 Unterschleissheim, Germany
# All rights reserved.
#
# This software is the confidential and proprietary information of ATIX
# GmbH. ("Confidential Information").  You shall not
# disclose such Confidential Information and shall use it only in
# accordance with the terms of the license agreement you entered into
# with ATIX.
#
# Kernelparameter for changing the bootprocess for the comoonics generic hardware detection alpha1
#    gfs-poolsource=... The poolsource possibilities (scsi*, gnbd)
#    gfs-pool=...       The gfs-pool to boot from
#    gfs-poolcca=... The gfs-cidev-pool to be given (defaults to ${gfspool}_cca, applies to 5.2)
#    gfs-poolcidev=... The gfs-cidev-pool to be given (defaults to ${gfspool}_cidev, applies to 5.1.1)
#    gfs-lockmethod=... The gfs-locking method (lock_gulm*, lock_dmep, nolock)
#    gfs-gnbdserver=.. The server serving the gnbd based scsi discs over ip
#    gfs-mountopt=...  The mount options given to the mount command (i.e. noatime,nodiratime)
#    com-stepmode=...      If set it asks for <return> after every step
#    com-debug=...         If set debug info is output

#
# Includes
# %%include /etc/gfs-lib.sh

source /etc/gfs-lib.sh

getGFSParameters

# getting gfs version
gfs_majorversion=$(getGFSMajorVersion)
gfs_minorversion=$(getGFSMinorVersion)

if [ $? -ne 0 ] || [ -z "$gfs_majorversion" ] || [ -z "$gfs_minorversion" ]; then
    echo_local "Unsupported or no gfs modules for this kernel"
    exit 1
fi

eval tmpmods=\$GFS_MODULES_${gfs_majorversion}_${gfs_minor_version}
[ -z $tmpmods ] && eval tmpmods=\$GFS_MODULES_${gfs_majorversion}
if [ ! -z "$tmpmods" ]; then
    GFS_MODULES=$tmpmods
fi

if [ "$poolsource" = "gnbd" ]; then
    GFS_MODULES="${GFS_MODULES} gnbd"
fi

case $gfs_lock_method in
    lock_gulm)
	GFS_MODULES="${GFS_MODULES} lock_gulm"
	;;
    lock_dmep)
	GFS_MODULES="${GFS_MODULES} lock_dmep"
	;;
    nolock)
	GFS_MODULES="${GFS_MODULES} lock_nolock"
	;;
    *)
	GFS_MODULES="${GFS_MODULES} lock_gulm"
	;;
esac

echo_local_debug "gfs_lock_method: $gfs_lock_method"
[ -n "$gnbd_server" ] && echo_local_debug "gnbd_server: $gnbd_server"
echo_local_debug "gfsversion: $gfs_majorversion $gfs_minorversion"

if [ "$poolsource" = "scsi" ]; then
    loadSCSI
fi
    
echo_local_debug "*****************************"
echo_local "4. Powering up gfs (modules=${GFS_MODULES} tmpmods=${tmpmods})"
for module in ${GFS_MODULES}; do
    exec_local /sbin/modprobe ${module}
done
echo_local_debug  "4.1 Loaded modules:"
exec_local_debug /sbin/lsmod
step

[ -n "$gnbd_server" ] && [ "$poolsource" = "gnbd" ] && \
    echo_local  "4.2 Importing SCSI-Devices (for gnbd poolsource=$poolsource gnbd_server=${gnbd_server})"
if [ "$poolsource" = "gnbd" -a -n "$gnbd_server" ]; then
    exec_local /sbin/gnbd_import -i $gnbd_server
fi

echo_local "4.3 Assembling pool"
exec_local ${GFS_POOL_ASSEMBLE}

if [ ! -z "$pool_name" ]; then
    GFS_POOL="$pool_name"
fi

if [ -z "$gfs_lock_method" ]; then
    gfs_lock_method="${GFS_LOCK_METHOD}"
fi

echo_local_debug "4.3.1 poolsource: $poolsource"

if [ $gfs_majorversion -eq 5 ] && [ $gfs_minorversion -lt 2 ]; then
    if [ -z "$pool_cidev_name" ]; then
	if [ -z "${GFS_POOL_CIDEV}" ]; then
	    GFS_POOL_CIDEV="${GFS_POOL}_cidev"
	else
	    GFS_POOL_CIDEV="${GFS_POOL_CIDEV}"
	fi
    else
	GFS_POOL_CIDEV="$pool_cidev_name"
    fi
    cdsl_local_dir="/boot.local"
    echo_local_debug "4.3.1 pool_cidev_name: $pool_cidev_name"
    mount_opts="hostdata=`/bin/hostname`:/dev/pool/$GFS_POOL_CIDEV"
else
    [ -z "$pool_cca_name" ] && pool_cca_name=$(gfs_autodetect_cca)
    [ -n "$pool_cca_name" ] && GFS_POOL_CCA=$pool_cca_name
    if [ -z "${GFS_POOL_CCA}" ]; then
	GFS_POOL_CCA="${GFS_POOL}_cca"
    fi
    cdsl_local_idr="/cdsl.local"
    echo_local -n "4.4 Starting ccsd ($GFS_POOL_CCA)"
    exec_local /sbin/ccsd -d $GFS_POOL_CCA
    return_code
    echo_local_debug "4.4.1 Pool-cca $GFS_POOL_CCA"
    echo_local_debug "4.4.1 pool_name: $pool_name"
    [ -z "$pool_name" ] && pool_name=$(cca_get_node_sharedroot)
    echo_local_debug "4.4.1 poolname: $pool_name"
    echo_local_debug "4.4.1 pool_cca_name: $pool_cca_name"
    GFS_POOL=$pool_name
    step
    echo_local -n "4.5 Starting lock_gulmd"
    sts=1
    if lock_gulmd &> $bootlog; then
	for i in $(seq 1 10)
	  do
	  sleep 1
	  if gulm_tool getstats localhost:ltpx &> /dev/null; then
	      sts=0
	      break
	  fi
	done
    fi
    if [ $sts -eq 0 ]; then echo_local "(OK)"; else echo_local "(FAILED)"; fi
    step
fi

echo_local_debug "*****************************"
echo_local "5. Pivot-Root..."
echo_local "5.0.1 Pool: ${GFS_POOL}"
    
echo_local "5.1. Mounting newroot ..."
exec_local /bin/mount -t gfs  /dev/pool/${GFS_POOL} /mnt/newroot -o $mount_opts
critical=0
if [ ! $return_c -eq 0 ]; then
    critical=1
fi
step
if [ $gfs_majorversion -eq 5 ] && [ $gfs_minorversion -lt 2 ]; then
    echo_local -n "5.2 Starting fenced ($GFS_FENCED)"
    exec_local ${GFS_FENCED}
fi

cd /mnt/newroot
if [ ! -e initrd ]; then
    /bin/mkdir initrd
fi
# if the dhclient is used for dhcp
#if [ -f /var/run/dhclient-eth0.pid ]; then
#   pid=`cat /var/run/dhclient-eth0.pid`
# the dhcpcd is used
#else
#   pid=`cat /etc/dhcpcd/dhcpcd-eth0.pid`
#fi
#step
echo_local -n "5.3 Copying relevant files"
#kill $pid
output=$( (
	if [ -f /mnt/newroot/etc/modules.conf ]; then 
	    mv /mnt/newroot/etc/modules.conf /mnt/newroot/etc/modules.conf.com_back
	fi &&
	if [ -f /mnt/newroot/etc/sysconfig/hwconf ]; then 
	    mv /mnt/newroot/etc/sysconfig/hwconf /mnt/newroot/etc/sysconfig/hwconf.com_back
	fi &&
	if [ ! -d /mnt/newroot/${cdsl_local_dir}/etc ]; then mkdir -p /mnt/newroot/${cdsl_local_dir}/etc; fi
	if [ ! -d /mnt/newroot/${cdsl_local_dir}/etc/sysconfig ]; then mkdir -p /mnt/newroot/${cdsl_local_dir}/etc/sysconfig; fi
	cd /mnt/newroot/etc &&
	cp /etc/modules.conf /mnt/newroot/${cdsl_local_dir}/etc/modules.conf &&
	ln -sf ../${cdsl_local_dir}/etc/modules.conf modules.conf &&
	    cd sysconfig &&
	    cp /etc/sysconfig/hwconf /mnt/newroot/${cdsl_local_dir}/etc/sysconfig/
	    ln -fs ../../${cdsl_local_dir}/etc/sysconfig/hwconf hwconf &&
	    cd /mnt/newroot ) 2>&1 )
echo "$output" >> $bootlog
if [ ! -z "$debug" ]; then 
    echo "$output"
fi
ret_code=$?
return_code $ret_code
step

echo_local -n "5.3.1 Copying logfile to ${bootlog}..."
exec_local cp ${bootlog} /mnt/newroot/${bootlog}
echo_local -n "5.4 Pivot-Rooting... (pwd: "$(pwd)")"
# [ ! -d initrd ] && mkdir initrd
# exec_local /sbin/pivot_root . initrd
#echo_local_debug "**********************************************************************"
#echo_local "6.1 Restarting network with new pivot_root..."
#mount -t proc proc /proc
#kill $pid && /sbin/ifup eth0
#echo_local "6.2 Cleaning up initrd ."
#echo_local -n "6.2.1 Umounting procfs"
#exec_local /bin/umount /initrd/proc
#echo_local -n "6.2.2 Umounting /initrd"
#exec_local /bin/umount /initrd
#echo_local -n "6.2.3 Freeing memory"
#exec_local /sbin/blockdev --flushbufs /dev/ram0


pivotRoot

# $Log: linuxrc.part.gfs.sh,v $
# Revision 1.1  2004-07-31 11:24:43  marc
# initial revision
#