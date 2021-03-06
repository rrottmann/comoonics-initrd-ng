#!/bin/bash
#
# $Id: linuxrc.bash,v 1.4 2007-12-07 16:39:59 reiner Exp $
#
# @(#)$File$
#
# Copyright (c) 2001 ATIX GmbH, 2007 ATIX AG.
# Einsteinstrasse 10, 85716 Unterschleissheim, Germany
# All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#


. etc/sysconfig/comoonics

# initstuff is done in here
source /etc/boot-lib.sh

initBootProcess

ipConfig=`getBootParm ip dhcp`
poolsource=`getBootParm poolsource scsi`
pool_name=`getBootParm pool`
pool_cca_name=`getBootParm poolcca`
pool_cidev_name=`getBootParm poolcidev`
gfs_lock_method=`getBootParm lockmethod`
gnbd_server=`getBootParm gnbdserver`
mount_opts=`getBootParm mountopt defaults`

if [ ! -z "$pool_name" ]; then
   GFS_POOL="$pool_name"
fi
if [ -z "$pool_cca_name" ]; then
   if [ -z "${GFS_POOL_CCA}" ]; then
      GFS_POOL_CCA="${GFS_POOL}_cca"
   else
      GFS_POOL_CCA=${GFS_POOL_CCA}
   fi
else
   GFS_POOL_CCA="$pool_cca_name"
fi
if [ -z "$pool_cidev_name" ]; then
   if [ -z "${GFS_POOL_CIDEV}" ]; then
      GFS_POOL_CIDEV="${GFS_POOL}_cidev"
   else
      GFS_POOL_CIDEV="${GFS_POOL_CIDEV}"
   fi
else
   GFS_POOL_CIDEV="$pool_cidev_name"
fi
if [ -z "$gfs_lock_method" ]; then
   gfs_lock_method="${GFS_LOCK_METHOD}"
fi

# getting gfs version
modinfo gfs | grep "description: .*v5.2.*" 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
  gfsversion="5_2"
else
  gfsversion="5_1"
fi

eval tmpmods=\$GFS_MODULES_${gfsversion}
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

echo_local_debug "Debug: $debug"
echo_local_debug "Stepmode: $stepmode"
echo_local_debug "poolsource: $poolsource"
echo_local_debug "pool_name: $pool_name"

if [ $gfsversion = "5_2" ]; then
  echo_local_debug "pool_cca_name: $pool_cca_name"
else
  echo_local_debug "pool_cidev_name: $pool_cidev_name"
fi
echo_local_debug "gfs_lock_method: $gfs_lock_method"
echo_local_debug "gnbd_server: $gnbd_server"
echo_local_debug "mount_opts: $mount_opts"
echo_local_debug "gfsversion: $gfsversion"
echo_local_debug "ip: $ipConfig"
echo_local_debug "*****************************"
x=`cat /proc/version`; 
KERNEL_VERSION=`expr "$x" : 'Linux version \([^ ]*\)'`
echo_local "0.2 Kernel-verion: ${KERNEL_VERSION}"
echo_local_debug "*****************************"
step 

detectHardware

exec /bin/bash

# $Log: linuxrc.bash,v $
# Revision 1.4  2007-12-07 16:39:59  reiner
# Added GPL license and changed ATIX GmbH to AG.
#
# Revision 1.3  2006/05/07 11:33:40  marc
# initial revision
#
# Revision 1.1  2004/07/31 11:24:43  marc
# initial revision
#