#!/bin/bash

here=`pwd`

export BDISTRPMBASEDIR=$here/rpmbuild
rm -Rf $BDISTRPMBASEDIR
mkdir -p $BDISTRPMBASEDIR/{BUILD,RPMS,SRPMS,SOURCES}

./buildrpmfromspec.sh

cd $here
rm -Rf dist
mkdir -p dist

find $BDISTRPMBASEDIR -regex '.*/RPMS/.*rpm' |grep -v debuginfo |xargs -I '{}' cp '{}' dist

#rm -Rf $BDISTRPMBASEDIR

