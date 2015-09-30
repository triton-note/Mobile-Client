#!/bin/bash
set -eu

########
#### Install dependencies

brew install sbt android
export ANDROID_HOME=$(brew --prefix android) && echo $ANDROID_HOME

########
#### Preparing

(cd $(dirname $0)
./android-prepare-update.sh
./android-prepare-keystore.sh
./android-prepare-supportjar.sh
./android-prepare-fabric.sh
./android-prepare-build_num.sh
)

########
#### Build

build_opts() {
	case "$BUILD_MODE" in
	"release") echo "--release";;
	"beta") echo "--release";;
	"debug") echo "";;
	esac
}
cordova build android $(build_opts) --buildConfig=platforms/android/build.json

########
#### Deploy

$(dirname $0)/android-deploy.sh
