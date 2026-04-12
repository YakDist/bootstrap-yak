#!/bin/sh

sysroot="$(realpath "$1")"
out="$(realpath "$2")"

fakeroot << EOF
# chown to proper uids, keeping setuid bits
find $sysroot/ ! -type l -perm -04000 -exec chown -h 0:0 {} + \
                                      -exec chmod u+s {} +

find $sysroot/ ! -type l ! -perm -04000 -exec chown 0:0 -h {} +

cd $sysroot
tar -cf $out *
EOF

