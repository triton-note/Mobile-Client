#!/bin/sh

echo "################################"
echo "# Start building"
echo "BUILD_NUM=$BUILD_NUM"
echo "PROJECT_REPO_SLUG=$PROJECT_REPO_SLUG"

into_python() {
    echo "################################"
    echo "# Using Python3"
    
    [ -z "$(type python3 2> /dev/null)" ] && brew install python3
    pip3 --version
    [ -z "$(type virtualenv 2> /dev/null)" ] && sudo pip3 install virtualenv
    
    [ -f .v3/bin/activate ] || virtualenv --python=$(type -p python3) .v3
    [ -z "${VIRTUAL_ENV:-}" ] && source .v3/bin/activate
}

install() {
    echo "################################"
    echo "# Install tools"
    
    pip install boto3
    build-scripts/cache.py load build-scripts/persistent
    build-scripts/cache.py load
    
    echo 'gem: --no-document' > $HOME/.gemrc
    
    pip install pyyaml lxml requests
    brew tap dart-lang/dart && brew install dart
    sudo gem install compass
    npm install
    export PATH="$PATH:$(pwd)/node_modules/.bin"
    
    build-scripts/cache.py save
}

build() {
    echo "################################"
    echo "# Building all"
    
    build-scripts/main.py
}

brew update || brew update
time into_python
time install
time build
