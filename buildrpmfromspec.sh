#!/bin/bash

if [[ -z "$1" || -d "$1" ]];then
    echo "You didn't specify anything to build";
    if [ -d "$1" ]
    then
        cd $1
    fi
    spec=`ls *spec | head -1`
    if [ -z "$spec" ]
    then
        echo "No spec file found. Exiting."
        exit 1;
    else
        reg='Name: '
        name=`grep "$reg" $spec |sed "s/$reg//" | sed "s/ //g"`
        reg='Version: '
        vers=`grep "$reg" $spec |sed "s/$reg//" | sed "s/ //g"`
        echo "Found spec $spec: name $name version $vers"
    fi
else
    spec=$1.spec
    name="$1"
fi

if [ -z "$2" ]; then
    if [ -z "$vers" ]
    then
        echo "You didn't specify a version to build";
        exit 1;
    fi
else
    vers="$2"
    echo "Using spec $spec: name $name version $vers"
fi

grep -E 'Fedora|release [6-9]' /etc/redhat-release >& /dev/null
if [ $? -eq 0 ]
then
  myrpmbasedir=$HOME/rpmbuild
else
  myrpmbasedir=/usr/src/redhat
fi

rpmbasedir=${BDISTRPMBASEDIR:-$myrpmbasedir}

echo "----> Building rpm for $name"
src_dir_main=$rpmbasedir/SOURCES/
src_dir=$rpmbasedir/SOURCES/${name}-${vers}
echo "----> Using $src_dir"
mkdir -pv $src_dir

# delete older versions of the rpm since there's no point having old
# versions in there when we still have the src.rpms in the SRPMS dir
echo "----> Cleaning up older packages"
find $rpmbasedir/RPMS -name ${name}-[0-9]\* -exec rm -vf {} \;

# Should use rpmspectool here
lmod_src="Lmod-${vers}.tar.gz"
rm $lmod_src
wget -O $lmod_src "https://github.com/TACC/Lmod/archive/${vers}.tar.gz"
mv $lmod_src $src_dir

cp -a Lmod-ml-unset-ld.patch SitePackage.lua macros.Lmod $src_dir

echo "----> Building the package"

## -ba: source and binary
## no debuginfo
rpmbuild --define "_sourcedir $src_dir" --define "_topdir $rpmbasedir" -ba --without debuginfo $spec
ec=$?

exit $ec
