#!/bin/bash
set -eu

cd "$(dirname $0)/../platforms/ios"

cat <<EOF > Podfile
pod 'Fabric'
pod 'Crashlytics'
EOF

mkdir -vp fastlane

(mkdir -vp certs && cd certs
echo $IOS_DISTRIBUTION_CERTIFICATE_BASE64 | base64 -D > Distribution.cer
echo $IOS_DISTRIBUTION_KEY_BASE64 | base64 -D > Distribution.p12
)

cat <<EOF > fastlane/Appfile
app_identifier ENV["IOS_BUNDLE_ID"]
EOF

cat <<EOF > fastlane/Fastfile
fastlane_version "1.29.2"

default_platform :ios

platform :ios do
  before_all do
    cocoapods

    increment_build_number(
      build_number: "$BUILD_NUM"
    )
    create_keychain(
      name: "Distribution",
      default_keychain: true,
      unlock: true,
      timeout: 3600,
      lock_when_sleeps: true
    )
    import_certificate certificate_path: "certs/Distribution.cer"
    import_certificate certificate_path: "certs/Distribution.p12" certificate_password: ENV['IOS_DISTRIBUTION_KEY_PASSWORD']

    cert
    sigh
    gym(
      clean: true,
      scheme: "$IOS_APPNAME",
      configuration: "Release",
      include_bitcode: false
    )

    # xctool # run the tests of your app
    # snapshot
  end

  desc "Runs all the tests"
  lane :debug do
    crashlytics(
      crashlytics_path: "./Pods/Crashlytics/Crashlytics.framework",
      api_token: "$FABRIC_API_KEY",
      build_secret: "$FABRIC_BUILD_SECRET",
      ipa_path: "./app.ipa"
    )
  end

  desc "Submit a new Beta Build to Apple TestFlight"
  desc "This will also make sure the profile is up to date"
  lane :beta do
    # sh "your_script.sh"
  end

  desc "Deploy a new version to the App Store"
  lane :release do
    # deliver(skip_deploy: true, force: true)
    # frameit
  end
end
EOF

