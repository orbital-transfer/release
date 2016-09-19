#!/bin/bash

if [ -n "$APPVEYOR_BUILD_FOLDER" ]; then
	cd $APPVEYOR_BUILD_FOLDER
fi

PREFIX="$1"
PREFIX=$( cd $PREFIX && pwd )

export PATH="/c/Program Files (x86)/WiX Toolset v3.10/bin:$PATH"

# <http://devcenter.wintellect.com/jrobbins/zen-of-paraffin>
# "http://devcenter.wintellect.com/media/Default/Blogs/Files/paraffin/Paraffin-3.6.zip"
PARAFFIN_TOP="$APPVEYOR_BUILD_FOLDER/dev/ci/Paraffin-3.6"
7z x -o$PARAFFIN_TOP $APPVEYOR_BUILD_FOLDER/dev/ci/Paraffin-3.6.zip
PARAFFIN="$PARAFFIN_TOP/Debug/Paraffin"

cd $PREFIX

MAIN_WXS="curie.wxs"
MAIN_WIXOBJ="curie.wixobj"
cpanm -n Template Data::UUID YAML # requried for wix-gen.pl
perl $APPVEYOR_BUILD_FOLDER/dev/ci/wix-gen.pl > $MAIN_WXS


WXS_FILES=""
WIXOBJ_FILES=""
for dir in lib mingw64 perl5; do
	DIR_GROUP_NAME="curie_$dir"
	DIR_WXS="$DIR_GROUP_NAME.wxs"
	DIR_WIXOBJ="$DIR_GROUP_NAME.wixobj"

	$PARAFFIN -d $dir -gn $DIR_GROUP_NAME $DIR_WXS
	WXS_FILES="$WXS_FILES $DIR_WXS"
	WIXOBJ_FILES="$WIXOBJ_FILES $DIR_WIXOBJ"
done

candle $WXS_FILES $MAIN_WXS

light -v $WIXOBJ_FILES $MAIN_WIXOBJ -o $APPVEYOR_BUILD_FOLDER/build/project-renard-$SUFFIX.msi
