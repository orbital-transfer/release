#!/bin/bash

if [ -n "$APPVEYOR_BUILD_FOLDER" ]; then
	cd $APPVEYOR_BUILD_FOLDER
fi

PREFIX="$1"
echo "Installing into prefix: $PREFIX"

mkdir -p $PREFIX || exit $?
PREFIX=$( cd $PREFIX && pwd )


. project-renard/devops/script/mswin/EUMMnosearch.sh

# Hack to skip the deletion of intermediate cchars.h file
cpanm -nq Term::ReadKey --build-args="RM=echo"

# Install earlier to apply EUMMnosearch (indirect dep of PAR::Packer)
cpanm -nq XML::Parser

cpanm -nq Perl::PrereqScanner || exit $?
( export PERL5OPT=""; cpanm -nq PAR::Packer ) || exit $?

perl $(which scan-perl-prereqs) project-renard/devops/script/mswin/msys2-dep-files.pl | cpanm -nq || exit $?

./project-renard/devops/script/mswin/msys2-dep-files.pl files project-renard/curie/msys2-mingw64-packages > msys2-mingw64-packages.yml || exit $?

./project-renard/devops/script/mswin/msys2-dep-files.pl copy $PREFIX < msys2-mingw64-packages.yml || exit $?

perl $(which pp) -vvv -n -B --gui -o $PREFIX/curie-gui.exe     project-renard/curie/bin/curie.pl || exit $?
perl $(which pp) -vvv -n -B       -o $PREFIX/curie-console.exe project-renard/curie/bin/curie.pl || exit $?
cp -puvR project-renard/curie/lib $PREFIX || exit $?

( cd project-renard/curie && cpanm -L $PREFIX/perl5 -nq --installdeps . ) || exit $?
cpanm -L $PREFIX/perl5 -nq Win32::HideConsole || exit $?

find $PREFIX -type f -name "*.exe" ! \( -name "curie*.exe" -o -name "mutool.exe" \) -delete || exit $?
