#!/bin/bash

# from a tagged module version, launch the package creation (.deb...)
# exit 0 if succeed, 1 if not.
# print out the module osc path if succeeds (e.g. science:openturns/otsvm).
# 2 instances of this script cannot be launched at a time

if [ $# -lt 1 ]; then
  echo "usage: ./build-module-pkg.sh tag_dir" >&2
  echo "exiting" >&2
  exit 1
fi

# debug
#set -x 

tag=$1
#tag=https://svn.openturns.org/openturns-modules/openturns-distfunc/tags/openturns-distfunc-0.3

cd /tmp
basedir=/tmp/prepare_module
workdir=$basedir/workdir
outdir=$basedir/out
rm -rf $basedir
mkdir -p $workdir
mkdir -p $outdir


# launch a command and exit 1 if it failed
function assert_cmd {
  cmd=$1

  # launch
  echo "= launch: $cmd" >&2
  $cmd

  # check
  if [ "$?" != "0" ]; then
    echo "= $cmd failed!" >&2
    echo "= Exiting." >&2
    exit 1
  fi
}


# tgz
assert_cmd "svn export $tag $workdir/openturns-xxx --trust-server-cert --non-interactive"
#svn export $tag $workdir/openturns-xxx
#if [ "$?" != "0" ]; then
#  echo "= svn export $tag $workdir/openturns-xxx failed!" >&2
#  echo "= Exiting." >&2
#  exit 1
#fi

pkgname=$(grep '^Name:' $workdir/openturns-xxx/distro/rpm/*.spec | awk '{print $2}')
#pkgver=$(grep '^Version:' $workdir/openturns-xxx/distro/rpm/*.spec | awk '{print $2}')
pkgver=$(cat $workdir/openturns-xxx/VERSION)
echo "= Found module: $pkgname, version: $pkgver" >&2

#if [[ $pkgname != openturns-* || "$pkgver" == "" ]]; then
#  echo "= Does not seems to be an OT module" >&2
if [[ "$pkgname" == "" || "$pkgver" == "" ]]; then
  echo "= Module name or version not found." >&2
  echo "= Exiting." >&2
  exit 1
fi

wholename=$pkgname-$pkgver
echo "= Building $wholename" >&2


## deb
mv $workdir/openturns-xxx $workdir/$wholename
cd $workdir
tar cjf ${pkgname}_$pkgver.orig.tar.bz2 $wholename/
cd $workdir/$wholename
cp -r distro/debian .
# create : openturns-distfunc_0.3-1.debian.tar.bz2, openturns-distfunc_0.3-1.dsc
debuild -us -uc -S
cp $workdir/${pkgname}_${pkver}*.debian.tar.gz $outdir
cp $workdir/${pkgname}_${pkver}*.dsc $outdir
cp $workdir/${pkgname}_${pkver}*.orig.tar.bz2 $outdir


## rpm
cp $workdir/${pkgname}_${pkver}*.orig.tar.bz2 $outdir/$wholename.tar.bz2
cp $workdir/$wholename/distro/rpm/$pkgname.spec $outdir

echo "= ls -al $outdir" >&2
ls -al $outdir


## osc
cd $workdir
ot_url="science:openturns"
module_url=$ot_url/$pkgname
#rm -rf $module_url

echo "= osc ls $module_url" >&2
osc ls $module_url 
if [ "$?" != "0" ]; then

  echo "= $module_url seems not existing. Create it." >&2

  assert_cmd "osc checkout $ot_url/openturns-doc"
  assert_cmd "mkdir $module_url"
  assert_cmd "osc add $module_url"
  #assert_cmd "osc commit -m \"Create module dir $module_url.\" $ot_url"
  osc commit -m \"Create module dir $module_url.\" $ot_url

else

  echo "= $module_url already exists. overwrite it." >&2

  assert_cmd "osc checkout $module_url"
  FILES=$(osc ls $module_url/)
  if [ "$FILES" != "" ]; then
    assert_cmd "osc del $module_url/*"
  fi

fi

assert_cmd "cd $workdir/$module_url"

assert_cmd "cp $outdir/* ."
assert_cmd "osc add *"

ls -al

assert_cmd "cd $workdir/$ot_url"

# debug
#pwd
#assert_cmd "osc commit -m \"Test new pkg name of module $wholename\" $ot_url/" 
#osc commit -m \"Test new pkg name of module $wholename\" .
#assert_cmd "osc commit -m \"Autobuilder update tagged module $wholename\""
# for a strange reason, osc commit return exit code != 0 while it succeed
osc commit -m \"Autobuilder update tagged module $wholename\" .


# wait until build succeeds
#osc results $module_url | grep 'xUbuntu_12.04        x86_64     succeeded'
  #xUbuntu_13.04        i586       succeeded
  #xUbuntu_13.04        x86_64     succeeded
  #xUbuntu_12.04        i586       succeeded
  #xUbuntu_12.04        x86_64     succeeded
  #Debian_7.0           i586       succeeded
  #Debian_7.0           x86_64     succeeded
  #Debian_6.0           i586       succeeded
  #Debian_6.0           x86_64     succeeded
# mirror:
# http://download.opensuse.org/repositories/science:/openturns/xUbuntu_12.04/all/python-openturns-distfunc_0.3-1_all.deb
#wget

echo "build launched." >&2
echo $module_url
exit 0
