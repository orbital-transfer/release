#!/usr/bin/env bash

install_dir="/Applications/Project-Renard.app"
build_devel=n
build_bottle=n
use_bottle=n
bottle_dir=""
build_dmg=y
make_fail=n
dmg_dir="$HOME"
verbose=n
with_test=y

steps_build=n
steps_postinstall=n
steps_dmg=n
steps_build_non_deps=n
steps_build_deps=n

function usage() {
	echo " $(basename $0)"
	echo " $(basename $0) [OPTION] ..."
	echo " $(basename $0) [OPTION ARG] ..."
	echo ""
	echo " Build an Project Renard application bundle for Mac OS X."
	echo ""
	echo " Several options are supported;"
	echo ""
	echo "  -a, --dmg-dir DIR"
	echo "    Location to create dmg [$dmg_dir]."
	echo "  -b, --build-dmg"
	echo "    Build a dmg."
	echo "  -d, --build-devel"
	echo "    Build the latest development snapshot."
	echo "  --build-bottle"
	echo "    Build the dependencies as bottles."
	echo "  --use-bottle"
	echo "    Use bottles to install dependencies."
	echo "  --bottle-dir DIR"
	echo "    Bottles are in directory DIR."
	echo "  --steps [all|build|build-only-deps|build-only-non-deps|postinstall|dmg]"
	echo "    Steps to run"
	echo "  -e, --error"
	echo "    Exit on error."
	echo "  -f, --make-fail"
	echo "    make homebrew fail to get a shell with proper environment."
	echo "  -h, -?, --help"
	echo "    Display this help text."
	echo "  -i, --install-dir DIR"
	echo "    Specify the directory where Project Renard will be installed [$install_dir]."
	echo "  -t, --without-test"
	echo "    Do not run 'make check'."
	echo "  -v, --verbose"
	echo "    Tell user the state of all options."
	echo ""
}

function parse_args() {
	while [[ $1 != "" ]]; do
	  case "$1" in
	    -a|--dmg-dir) if [ $# -gt 1 ]; then
		  dmg_dir=$2; shift 2
		else
		  echo "$1 requires an argument" >&2
		  exit 1
		fi ;;
	    -b|--build-dmg) build_dmg=y; shift 1;;
	    -d|--build-devel) build_devel=y; shift 1;;
	    --steps)
		if [ $# -gt 1 ]; then
			if [ "$2" == "build" ]; then
				steps_build="y"
				steps_build_deps="y"
				steps_build_non_deps="y"
				shift 2
			elif [ "$2" == "build-only-deps" ]; then
				steps_build="y"
				steps_build_deps="y"
				steps_build_non_deps="n"
				shift 2
			elif [ "$2" == "build-only-non-deps" ]; then
				steps_build="y"
				steps_build_deps="n"
				steps_build_non_deps="y"
				shift 2
			elif [ "$2" == "postinstall" ]; then
				steps_postinstall="y"
				shift 2
			elif [ "$2" == "dmg" ]; then
				steps_dmg="y"
				shift 2
			elif [ "$2" == "all" ]; then
				steps_build="y"
				steps_build_only_deps="n"
				steps_postinstall="y"
				steps_dmg="y"
				shift 2
			else
				echo "Unknown step $2"
				exit 1
			fi
		else
			echo "$1 requires an argument"
			exit 1
		fi ;;
	    --build-bottle) build_bottle=y; shift 1;;
	    --use-bottle) use_bottle=y; shift 1;;
	    --bottle-dir) if [ $# -gt 1 ]; then
		  bottle_dir=$2; shift 2
		else
		  echo "$1 requires an argument" >&2
		  exit 1
		fi ;;
	    -e|--error) set -e; shift 1;;
	    -f|--make-fail) make_fail=y; shift 1;;
	    -h|--help|-\?) usage; exit 0;;
	    -i|--install-dir) if [ $# -gt 1 ]; then
		  install_dir=$2; shift 2
		else
		  echo "$1 requires an argument" >&2
		  exit 1
		fi ;;
	    -t|--without-test) with_test=n; shift 1;;
	    -v|--verbose) verbose=y; shift 1;;
	    --) shift; break;;
	    *) echo "invalid option: $1" >&2; usage; exit 1;;
	  esac
	done
}

function setup() {
	if [ "$verbose" == "y" ]; then
		echo install_dir = \"$install_dir\"
		echo build_devel = \"$build_devel\"
		echo build_bottle = \"$build_bottle\"
		echo dmg_dir = \"$dmg_dir\"
		echo make_fail = \"$make_fail\"
		echo with_test = \"$with_test\"
		set -v
	fi

	# set some environment variables
	# export HOMEBREW_BUILD_FROM_SOURCE=1
	export HOMEBREW_OPTFLAGS="-march=core2"
	PATH="$install_dir/Contents/Resources/usr/bin/:$PATH"
}

function brew_pre_install() {
	# check if we do full or update
	if [ -e "$install_dir/Contents/Resources/usr/bin/brew" ]; then
		echo "Update."
		install_type='update'
	else
		install_type='full'
	fi

	if [ "$install_type" == "update" ]; then
		# uninstall curie
		echo "Update homebrew installation in $install_dir."
		cd "$install_dir/Contents/Resources/usr/bin"
		if [ -d "$install_dir/Contents/Resources/usr/Cellar/curie" ]; then
			./brew uninstall curie
		fi
	else
		# install homebrew
		echo "Create new homebrew installation in $install_dir."
		osacompile -o "$install_dir" -e " "
		mkdir -p "$install_dir/Contents/Resources/usr"
		curl -L https://github.com/Homebrew/homebrew/tarball/master | tar xz --strip 1 -C "$install_dir/Contents/Resources/usr"
		cd "$install_dir/Contents/Resources/usr/bin"
	fi

	./brew update # get new formulas
	#./brew upgrade # compile new formulas
	./brew cleanup # remove old versions

	# be conservative regarding architectures
	# use Mac's (BSD) sed
	/usr/bin/sed -i '' 's/march=native/march=core2/g' "$install_dir/Contents/Resources/usr/Library/Homebrew/extend/ENV/super.rb"
	/usr/bin/sed -i '' 's/march=native/march=core2/g' "$install_dir/Contents/Resources/usr/Library/Homebrew/extend/ENV/std.rb"

	# go to the bin directory
	cd "$install_dir/Contents/Resources/usr/bin"

	# install trash command line utility
	./brew install trash --universal

	# get project-renard homebrew
	./brew tap project-renard/project-renard

	# icoutils
	./brew install icoutils --universal
}

function brew_deps_install() {
	# required X11 dep
	./brew cask install xquartz

	echo "|$use_bottle|"
	echo "|$bottle_dir|"
	if [ "$use_bottle" == "y" ]; then
		echo "Installing bottles"
		#BOTTLE_DEPS=$(ls -f $( brew deps -n curie | sed -e "s,^,$bottle_dir/," -e 's/$/*.tar.gz/' ))
		#brew install -f $BOTTLE_DEPS
		echo "=========="
		for bottle_tarball in `ls $bottle_dir/*.tar.gz`; do
			PKG_NAME=`tar tzf $bottle_tarball | head -1 | grep -o '^[^/]\+'`
			echo $PKG_NAME
			CELLAR_DIR="$install_dir/Contents/Resources/usr/Cellar"
			tar xzf $bottle_tarball -C $CELLAR_DIR;
			brew unlink $PKG_NAME && brew link --force $PKG_NAME
		done
		echo "=========="
	fi

	# finally build octave
	BREW_OPT_BUILD_BOTTLE=""
	if [ "$build_bottle" == "y" ]; then
		BREW_OPT_BUILD_BOTTLE="--build-bottle"
	fi

	echo "Running brew install"
	./brew install gdk-pixbuf $BUILD_BOTTLE
	./brew link gdk-pixbuf
	while : ; do
		./brew install $(./brew deps -n curie) 2>&1 | grep -v -e 'already installed' -e 'is a keg-only and another version is linked to opt' -e 'if you want to install this version'
		[ $? -eq 0 ] || break
		echo "Rerunning brew install"
	done
	if [ "$build_bottle" == "y" ]; then
		BREW_PATH=$(pwd)
		if [ -d "$bottle_dir" ]; then
			cd "$bottle_dir"
			#BOTTLE_DEPS=$(ls -f $( brew deps -n curie | sed -e 's/$/*.tar.gz/' ))
			#mv -v $BOTTLE_DEPS $bottle_dir/
		fi
		$BREW_PATH/brew bottle $($BREW_PATH/brew deps -n curie)
		cd $BREW_PATH
	fi
}

function brew_curie_install() {
	# build curie
	curie_settings="--universal --build-from-source --debug"
	if [ "$verbose" == "y" ]; then
		curie_settings="$curie_settings --verbose"
	fi
	if [ "$build_devel" == "y" ]; then
		curie_settings="$curie_settings --HEAD"
	fi
	if [ "$with_test" == "n" ]; then
		curie_settings="$curie_settings --without-test"
	fi
	if [ "$make_fail" == "y" ]; then
		echo
		# enforce failure
		#/usr/bin/sed -i '' 's/\".\/bootstrap" if build.head?/\"false\"/g' "$install_dir/Contents/Resources/usr/Library/Taps/homebrew/homebrew-science/octave.rb"
	fi
	./brew install curie $curie_settings
}

function brew_install() {
	brew_pre_install;
	if [ "$steps_build_deps" == "y" ]; then
		brew_deps_install;
	fi
	if [ "$steps_build_non_deps" == "y" ]; then
		brew_curie_install;
	fi
}

function postinstall() {
	$install_dir/Contents/Resources/usr/bin/glib-compile-schemas $install_dir/Contents/Resources/usr/share/glib-2.0/schemas
}

function create_dmg() {
	cd "$install_dir/Contents/Resources/usr/bin"

	# get versions
	curie_ver="$(./curie --version | /usr/bin/sed -n 1p | /usr/bin/grep -o '\d\..*$' )"
	curie_ver_string="$(./curie --version | /usr/bin/sed -n 1p)"
	curie_ver_string="Project Renarard Curie $curie_ver_string" # TODO
	curie_copy="$(./curie --version | /usr/bin/sed -n 2p | /usr/bin/cut -c 15- )"
	curie_copy="Perl_5 license"

	## use local font cache instead of global one
	#/usr/bin/sed -i '' 's/\/Applications.*fontconfig/~\/.cache\/fontconfig/g' "$install_dir/Contents/Resources/usr/etc/fonts/fonts.conf"

	## tidy up: make a symlink to system "/var
	#rm -R "$install_dir/Contents/Resources/usr/var"
	#ln -s "/var" "$install_dir/Contents/Resources/usr/var"

	# create applescript to execute curie
	tmp_script=$(mktemp /tmp/curie-XXXX);
	cat <<EOF > $tmp_script
on export_path()
  return "export PATH=\"'$install_dir'/Contents/Resources/usr/bin/:\$PATH\";"
end export_path

on export_dyld()
  return "export DYLD_FALLBACK_LIBRARY_PATH=\"'$install_dir'/Contents/Resources/usr/lib:/lib:/usr/lib\";"
end export_dyld

on cache_fontconfig()
  set fileTarget to (path to home folder as text) & ".cache:fontconfig"
  try
    fileTarget as alias
  on error
    display dialog "Font cache not found, so first plotting will be slow. Create font cache now?" with icon caution buttons {"Yes", "No"}
    if button returned of result = "Yes" then
      do shell script "'$install_dir'/Contents/Resources/usr/bin/fc-cache -frv;"
    end if
  end try
end cache_fontconfig

on run_curie_gui()
  return "cd ~;clear;'$install_dir'/Contents/Resources/usr/bin/curie | logger 2>&1;"
end run_curie_gui

on run_curie_cli()
  return "cd ~;clear;'$install_dir'/Contents/Resources/usr/bin/curie;exit;"
end run_curie_cli

on run_curie_open(filename)
  return "cd ~;clear;'$install_dir'/Contents/Resources/usr/bin/curie " & quoted form of (filename) & " | logger 2>&1;"
end run_curie_open

on path_check()
  if not (POSIX path of (path to me) contains "'$install_dir'") then
    display dialog "Please run Curie from the '$install_dir' folder" with icon stop with title "Error" buttons {"OK"}
    error number -128
  end if
end path_check

on open argv
  --path_check()
  --cache_fontconfig()
  set cmd to ""
  if (count of argv) > 0 then
    set filename to POSIX path of (item 1 of argv)
    set cmd to export_path() & export_dyld() & run_curie_open(filename)
  else
    set cmd to export_path() & export_dyld() & run_curie_gui()
  end if
  do shell script cmd
end open

on run
  --path_check()
  --cache_fontconfig()
  set cmd to ""
  set cmd to export_path() & export_dyld() & run_curie_gui()
  do shell script cmd
end run
EOF
	#cat $tmp_script
	osacompile -o "$install_dir/Contents/Resources/Scripts/main.scpt" $tmp_script

	## create a nice iconset (using the icons shipped with octave)
	## the following might fail for the development version
	#hicolor="$install_dir/Contents/Resources/usr/opt/octave/share/icons/hicolor"
	#svg_icon="$hicolor/scalable/apps/octave.svg"
	#tmp_iconset="$(mktemp -d /tmp/iconset-XXXX)/droplet.iconset"
	#mkdir -p "$tmp_iconset"
	#cp "$hicolor/16x16/apps/octave.png" "$tmp_iconset/icon_16x16.png"
	#cp "$hicolor/32x32/apps/octave.png" "$tmp_iconset/icon_16x16@2x.png"
	#cp "$hicolor/32x32/apps/octave.png" "$tmp_iconset/icon_32x32.png"
	#cp "$hicolor/64x64/apps/octave.png" "$tmp_iconset/icon_32x32@2x.png"
	#cp "$hicolor/128x128/apps/octave.png" "$tmp_iconset/icon_128x128.png"
	#cp "$hicolor/256x256/apps/octave.png" "$tmp_iconset/icon_128x128@2x.png"
	#cp "$hicolor/256x256/apps/octave.png" "$tmp_iconset/icon_256x256.png"
	#cp "$hicolor/512x512/apps/octave.png" "$tmp_iconset/icon_256x256@2x.png"
	#cp "$hicolor/512x512/apps/octave.png" "$tmp_iconset/icon_512x512.png"
	#iconutil -c icns -o "$install_dir/Contents/Resources/applet.icns" "$tmp_iconset"

	# create or update entries in the application's plist
	defaults write "$install_dir/Contents/Info" NSUIElement 1
	defaults write "$install_dir/Contents/Info" CFBundleIdentifier io.github.projectrenard.Curie
	defaults write "$install_dir/Contents/Info" CFBundleShortVersionString "$curie_ver"
	defaults write "$install_dir/Contents/Info" CFBundleVersion "$curie_ver_string"
	defaults write "$install_dir/Contents/Info" NSHumanReadableCopyright "$curie_copy"
	defaults write "$install_dir/Contents/Info" CFBundleDocumentTypes -array '{"CFBundleTypeExtensions" = ("pdf"); "CFBundleTypeMIMETypes" = ("application/pdf"); "CFBundleTypeRole" = "Viewer";}'
	plutil -convert xml1 "$install_dir/Contents/Info.plist"
	chmod a=r "$install_dir/Contents/Info.plist"

	## add icon to octave-gui
	#if [ "$build_gui" == "y" ]; then
		#export python_script=$(mktemp /tmp/octave-XXXX);
		#echo '#!/usr/bin/env python' > $python_script
		#echo 'import Cocoa' >> $python_script
		#echo 'import sys' >> $python_script
		#echo 'Cocoa.NSWorkspace.sharedWorkspace().setIcon_forFile_options_(Cocoa.NSImage.alloc().initWithContentsOfFile_(sys.argv[1].decode("utf-8")), sys.argv[2].decode("utf-8"), 0) or sys.exit("Unable to set file icon")' >> $python_script
		#/usr/bin/python "$python_script" "$install_dir/Contents/Resources/applet.icns" $install_dir/Contents/Resources/usr/Cellar/octave/*/libexec/octave/*/exec/*/octave-gui
	#fi

	# collect dependencies from the homebrew database
	# clean up the strings using sed
	echo "" > "$install_dir/Contents/Resources/DEPENDENCIES"

	# force all formulas to be linked and list them in
	# the file DEPENDENCIES
	./brew list -1 | while read line
	do
		./brew unlink $line
		./brew link --force $line
		./brew info $line | /usr/bin/sed -e 's$homebrew/science/$$g'| /usr/bin/sed -e 's$: .*$$g' | /usr/bin/sed -e 's$/Applications.*$$g' | /usr/bin/head -n3 >> "$install_dir/Contents/Resources/DEPENDENCIES"
		echo "" >> "$install_dir/Contents/Resources/DEPENDENCIES"
	done

	# create a nice dmg disc image with create-dmg (MIT License)
	if [ "$build_dmg" == "y" ]; then
		# get make-dmg from github
		tmp_dir=$(mktemp -d /tmp/curie-XXXX)
		git clone https://github.com/schoeps/create-dmg.git $tmp_dir/create-dmg

		# get background image
		#curl https://raw.githubusercontent.com/schoeps/octave_installer/master/background.tiff -o "$tmp_dir/background.tiff"

		# Put existing dmg into Trash
		if [ -f "$dmg_dir/ProjectRenard-Installer.dmg" ]; then
		  echo "Moving $dmg_dir/ProjectRenard-Installer.dmg into the trash"
		  ./trash "$dmg_dir/ProjectRenard-Installer.dmg"
		fi

		du -hs /Applications/Project-Renard.app

		# running create-dmg; this may issue warnings if run headless. However, the dmg
		# will still be created, only some beautifcation cannot be applied
		cd "$tmp_dir/create-dmg"
		./create-dmg \
		--volname "ProjectRenard-Installer" \
		--window-size 550 442 \
		--icon ProjectRenard.app 125 180 \
		--hide-extension ProjectRenard.app \
		--app-drop-link 415 180 \
		--add-file DEPENDENCIES "$install_dir/Contents/Resources/DEPENDENCIES" 415 300 \
		--disk-image-size 12000 \
		"$dmg_dir/ProjectRenard-Installer.dmg" \
		"$install_dir"

		#./create-dmg \
		#--volname "ProjectRenard-Installer" \
		#--volicon "$install_dir/Contents/Resources/applet.icns" \
		#--window-size 550 442 \
		#--icon-size 48 \
		#--icon ProjectRenard.app 125 180 \
		#--hide-extension ProjectRenard.app \
		#--app-drop-link 415 180 \
		#--eula "$install_dir/Contents/Resources/usr/opt/octave/README" \
		#--add-file COPYING "$install_dir/Contents/Resources/usr/opt/octave/COPYING" 126 300 \
		#--add-file DEPENDENCIES "$install_dir/Contents/Resources/DEPENDENCIES" 415 300 \
		#--disk-image-size 10000 \
		#--background "$tmp_dir/background.tiff" \
		#"$dmg_dir/ProjectRenard-Installer.dmg" \
		#"$install_dir"

		echo DMG ready: $dmg_dir/ProjectRenard-Installer.dmg
	fi
}

function main() {
	parse_args "$@";
	setup;
	if [ "$steps_build" == "y" ]; then
		brew_install;
	fi
	if [ "$steps_postinstall" == "y" ]; then
		postinstall;
	fi
	if [ "$steps_dmg" == "y" ]; then
		create_dmg;
	fi
}

main "$@";
