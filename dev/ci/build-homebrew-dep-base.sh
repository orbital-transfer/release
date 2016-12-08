#!/bin/sh

CURDIR=`dirname "$0"`
#CURDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # works in sourced files, only works for bash

if [ ! -d "/Applications/Project-Renard.app" ]; then
	cd /Users/vagrant/project-renard/release/release/dev/ci
	./build-dmg.sh --steps build-only-deps
fi

rm -Rfv ~/Project-Renard-base.tgz
cd /Applications/Project-Renard.app
tar cvzf ~/Project-Renard-base.tgz .

cd /Users/vagrant/project-renard/travis-homebrew-bottle/travis-homebrew-bottle/
split -b80m ~/Project-Renard-base.tgz Project-Renard-base.tgz.part.
