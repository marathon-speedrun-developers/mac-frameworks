#!/bin/bash

#Original build.sh variables
PROJ="vorbis"
VERSION="1.3.7"
URL="http://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz"
DIRNAME="lib$PROJ-$VERSION"
NOPACKAGING="1"

# Shoving the entirety of build-std.sh in this because vorbis is a naughty, naughty framework
DEV="/Applications/Xcode.app/Contents/Developer"
SDKROOT="$DEV/Platforms/MacOSX.platform/Developer/SDKs"
STOCKPATH="$DEV/usr/bin:/usr/bin:/bin"
STOCKPKGCONFIG="/usr/lib/pkgconfig"
SRCDIR="$PWD/src"
COMPILEDIR="$PWD/objs"
INSTALLDIR="$PWD/installs"
FWKDIR="$PWD"
PLIST_TEMPLATE="$PWD/../Info-template.plist"

if [ "$DLNAME" == "" ]; then DLNAME="${URL##*/}"; fi 
if [ "$DIRNAME" == "" ]; then DIRNAME="$PROJ-$VERSION"; fi 
if [ "$FWKS" == "" ]; then FWKS="lib$PROJ"; fi 
if [ "$HEADERROOT" == "" ]; then HEADERROOT="include"; fi 

FWKS=( $FWKS )

# grab source
if [ ! -f "$DLNAME" ]; then
  curl -L -o "$DLNAME" "$URL"
fi 

# unpack source
 

if [ -d "$COMPILEDIR" ]; then rm -r "$COMPILEDIR"; fi 
if [ -d "$INSTALLDIR" ]; then rm -r "$INSTALLDIR"; fi 

for arch in 'arm64' 'x86_64'; do

  cd $FWKDIR

  if [ "$arch" == 'arm64' ]; then
    OGGBASE=$(cd "../ogg/installs/arm64" && pwd)
    CONFIGOPTS="--enable-shared --disable-oggtest --with-ogg-libraries=$OGGBASE/lib --with-ogg-includes=$OGGBASE/include"
  elif [ "$arch" == 'x86_64' ]; then
    OGGBASE=$(cd "../ogg/installs/x86_64" && pwd)
    CONFIGOPTS="--enable-shared --disable-oggtest --with-ogg-libraries=$OGGBASE/lib --with-ogg-includes=$OGGBASE/include"
  fi  

  rm -rf ./src

  if [ -d "$SRCDIR" ]; then rm -r "$SRCDIR"; fi 
    case "$DLNAME" in
       *.tar.bz2 ) tar xjf "$DLNAME" ;;
       *.tar.gz  ) tar xzf "$DLNAME" ;;
       *         ) echo "Cannot unpack $DLNAME" ; exit ;;
    esac
    mv "$DIRNAME" "$SRCDIR"

    if [ "$LICENSE" != "" ]; then
    if [ -f "$SRCDIR/$LICENSE" ]; then
      cp "$SRCDIR/$LICENSE" "License.txt"
    fi 
  fi

  IDIR="$INSTALLDIR/$arch"
  mkdir -p "$IDIR"
  CDIR="$COMPILEDIR/$arch"
  mkdir -p "$CDIR"
  cd $CDIR

  export PATH="$PATH_OVERRIDE:$STOCKPATH:$PATH_EXTRA"
  export PKG_CONFIG_PATH="$PKGCONFIG_OVERRIDE:$STOCKPKGCONFIG"
  export ENVP="MACOSX_DEPLOYMENT_TARGET=10.11"
  FLAGS="-arch $arch -mmacosx-version-min=10.11"
	
  env -i \
    CC="$DEV/usr/bin/gcc" \
    CPP="$DEV/usr/bin/gcc -E" \
    LD="$DEV/usr/bin/g++" \
    CFLAGS="$FLAGS" \
    LDFLAGS="$FLAGS" \
    PATH="$PATH" \
    PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
    "$SRCDIR/configure" --prefix="$IDIR" $CONFIGOPTS
  env -i \
    CC="$DEV/usr/bin/gcc" \
    CPP="$DEV/usr/bin/gcc -E" \
    LD="$DEV/usr/bin/g++" \
    CFLAGS="$FLAGS" \
    LDFLAGS="$FLAGS" \
    PATH="$PATH" \
    PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
    make
  env -i \
    CC="$DEV/usr/bin/gcc" \
    CPP="$DEV/usr/bin/gcc -E" \
    LD="$DEV/usr/bin/g++" \
    CFLAGS="$FLAGS" \
    LDFLAGS="$FLAGS" \
    PATH="$PATH" \
    PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
    make install

  # Update shared-library paths

  LIBDIR="$INSTALLDIR/$arch/lib"
  for lib in "${FWKS[@]}"; do
    lname=${lib#lib}
    dylibvar="DYLIBNAME_$lib"
    dylibname="${!dylibvar}"
    if [ "$dylibname" == "" ]; then dylibname="$lib.dylib"; fi 
    install_name_tool -id "@executable_path/../Frameworks/$lname.framework/Versions/A/$lname" "$LIBDIR/$dylibname"

    # fix links to sibling libraries
    for elib in "${FWKS[@]}"; do
      ename=${elib#lib}
      edylibvar="DYLIBNAME_$elib"
      edylibname="${!edylibvar}"
      if [ "$edylibname" == "" ]; then edylibname="$elib.dylib"; fi 
      install_name_tool -change "$LIBDIR/$edylibname" "@executable_path/../Frameworks/$ename.framework/Versions/A/$ename" "$LIBDIR/$dylibname"
    done
  done
done

# Set up frameworks
for lib in "${FWKS[@]}"; do
# set up directory structure
  lname=${lib#lib}
  FDIR="$FWKDIR/$lname.framework"
  if [ -d "$FDIR" ]; then rm -r "$FDIR"; fi 
  mkdir -p "$FDIR/Versions/A/Headers"
  mkdir -p "$FDIR/Versions/A/Resources"
  
  cd "$FDIR/Versions"
  ln -s A Current
  
  cd "$FDIR"
  ln -s Versions/Current/Headers
  ln -s Versions/Current/Resources
  ln -s Versions/Current/$lname
  
  #Create UB2 dylib.
  lipo \
  "$INSTALLDIR/arm64/lib/$lib.dylib" \
  "$INSTALLDIR/x86_64/lib/$lib.dylib" \
  -create -o "$FDIR/VERSIONS/A/$lname"
  
  # create Info.plist
  cp "$PLIST_TEMPLATE" "$FDIR/Resources/Info.plist"
  sed -i '' -e s/\$FRAMEWORK_NAME/$lname/g "$FDIR/Resources/Info.plist"
  sed -i '' -e s/\$FRAMEWORK_VERSION/$VERSION/g "$FDIR/Resources/Info.plist"
  
  # copy headers
  HNAME="$FDIR/Headers"
  mkdir -p "$HNAME"
  cd "$INSTALLDIR/$arch/include"
  for hfile in `find . -type f`; do
    mkdir -p "$HNAME"/`dirname $hfile`
    cp $hfile "$HNAME/$hfile"
  done
done


if [ "$NOPACKAGING" == "1" ]; then exit; fi 

# done with installdir
# if [ "$DEBUG" == "" ]; then rm -r "$INSTALLDIR"; fi