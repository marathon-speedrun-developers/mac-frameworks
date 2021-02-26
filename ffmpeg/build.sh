#!/bin/bash

PROJ="ffmpeg"
VERSION="4.1.1"
URL="http://ffmpeg.org/releases/ffmpeg-4.1.1.tar.bz2"
CONFIGOPTS="--disable-static --enable-shared --enable-gpl --enable-libvorbis --enable-libvpx --disable-doc --disable-ffmpeg --disable-ffplay --disable-ffprobe --disable-avdevice --disable-swresample --disable-postproc --disable-avfilter --disable-everything --disable-neon"
CONFIGOPTS+=" --enable-muxer=webm --enable-encoder=libvorbis --enable-encoder=libvpx_vp8"
CONFIGOPTS+=" --enable-demuxer=aiff --enable-demuxer=mp3 --enable-demuxer=mpegps --enable-demuxer=mpegts --enable-demuxer=mpegtsraw --enable-demuxer=mpegvideo --enable-demuxer=ogg --enable-demuxer=wav"
CONFIGOPTS+=" --enable-parser=mpegaudio --enable-parser=mpegvideo"
CONFIGOPTS+=" --enable-decoder=adpcm_ima_wav --enable-decoder=adpcm_ms --enable-decoder=gsm --enable-decoder=gsm_ms --enable-decoder=mp1 --enable-decoder=mp1float --enable-decoder=mp2 --enable-decoder=mp2float --enable-decoder=mp3 --enable-decoder=mp3float --enable-decoder=mpeg1video --enable-decoder=pcm_alaw --enable-decoder=pcm_f32be --enable-decoder=pcm_f32le --enable-decoder=pcm_f64be --enable-decoder=pcm_f64le --enable-decoder=pcm_mulaw --enable-decoder=pcm_s8 --enable-decoder=pcm_s8_planar --enable-decoder=pcm_s16be --enable-decoder=pcm_s16le --enable-decoder=pcm_s16le_planar --enable-decoder=pcm_s24be --enable-decoder=pcm_s24le --enable-decoder=pcm_s32be --enable-decoder=pcm_s32le --enable-decoder=pcm_u8 --enable-decoder=theora --enable-decoder=vorbis --enable-decoder=vp8"
CONFIGOPTS+=" --enable-protocol=file --disable-asm"
CONFIGOPTS+=" --pkg-config-flags=--static"
PATH_OVERRIDE="/usr/local/bin:/opt/homebrew/bin" # install pkg-config, glib here
FWKS="libavcodec libavformat libavutil libswscale"
DYLIBNAME_libavcodec="libavcodec.58.dylib"
DYLIBNAME_libavformat="libavformat.58.dylib"
DYLIBNAME_libavutil="libavutil.56.dylib"
DYLIBNAME_swscale="libswscale.5.dylib"
LICENSE="LICENSE.md"

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

  export OGGBASE=$(cd "../ogg/installs/$arch" && pwd)
  export VORBISBASE=$(cd "../vorbis/installs/$arch" && pwd)
  export VPXBASE=$(cd "../vpx/installs/$arch" && pwd)
  export PKGCONFIG_OVERRIDE="$OGGBASE/lib/pkgconfig:$VORBISBASE/lib/pkgconfig:$VPXBASE/lib/pkgconfig"
  PATH="$PATH_OVERRIDE:$STOCKPATH:$PATH_EXTRA"
  export PKG_CONFIG_PATH="$PKGCONFIG_OVERRIDE:$STOCKPKGCONFIG"

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

  ENVP="MACOSX_DEPLOYMENT_TARGET=10.11"
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

  echo "Updating Libraries"

  LIBDIR="$INSTALLDIR/$arch/lib"
  for lib in "${FWKS[@]}"; do
    lname=${lib#lib}
    dylibvar="DYLIBNAME_$lib"
    dylibname="${!dylibvar}"
    if [ "$dylibname" == "" ]; then dylibname="$lib.dylib"; fi 
    install_name_tool -id "@executable_path/../Frameworks/$lname.framework/Versions/A/$lname" "$LIBDIR/$dylibname"
    
    echo "Fixing Links"

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
	echo "Setting Frameworks" 
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

rm -r avcodec.framework/Versions/A/Headers/libavformat
rm -r avcodec.framework/Versions/A/Headers/libavutil
rm -r avcodec.framework/Versions/A/Headers/libswscale

rm -r avformat.framework/Versions/A/Headers/libavcodec
rm -r avformat.framework/Versions/A/Headers/libavutil
rm -r avformat.framework/Versions/A/Headers/libswscale

rm -r avutil.framework/Versions/A/Headers/libavcodec
rm -r avutil.framework/Versions/A/Headers/libavformat
rm -r avutil.framework/Versions/A/Headers/libswscale

rm -r swscale.framework/Versions/A/Headers/libavcodec
rm -r swscale.framework/Versions/A/Headers/libavformat
rm -r swscale.framework/Versions/A/Headers/libavutil
