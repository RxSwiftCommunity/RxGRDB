# Rules
# =====
#
# make test - Run all tests but performance tests
# make distclean - Restore repository to a pristine state

default: test


# Configuration
# =============

GIT := $(shell command -v git)
POD := $(shell command -v pod)
XCRUN := $(shell command -v xcrun)
XCODEBUILD := set -o pipefail && $(shell command -v xcodebuild)

# Xcode Version Information
XCODEVERSION_FULL := $(word 2, $(shell xcodebuild -version))
XCODEVERSION_MAJOR := $(shell xcodebuild -version 2>&1 | grep Xcode | cut -d' ' -f2 | cut -d'.' -f1)
XCODEVERSION_MINOR := $(shell xcodebuild -version 2>&1 | grep Xcode | cut -d' ' -f2 | cut -d'.' -f2)
XCODEVERSION_PATCH := $(shell xcodebuild -version 2>&1 | grep Xcode | cut -d' ' -f2 | cut -d'.' -f3)

# The Xcode Version, containing only the "MAJOR.MINOR" (ex. "8.3" for Xcode 8.3, 8.3.1, etc.)
XCODEVERSION := $(XCODEVERSION_MAJOR).$(XCODEVERSION_MINOR)

# Used to determine if xcpretty is available
XCPRETTY_PATH := $(shell command -v xcpretty 2> /dev/null)


# Tests
# =====

# xcodebuild actions to run test targets
TEST_ACTIONS = clean build build-for-testing test-without-building

# When adding support for an Xcode version, look for available devices with `instruments -s devices`
ifeq ($(XCODEVERSION),10.0)
  MIN_SWIFT_VERSION = 4.0
  MAX_SWIFT_VERSION = 4.2
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 8,OS=12.0"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 4s,OS=9.0"
else ifeq ($(XCODEVERSION),9.4)
  # MIN_SWIFT_VERSION undefined: only check MAX_SWIFT_VERSION
  MAX_SWIFT_VERSION = 4.0
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 8,OS=11.4"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 4s,OS=9.0"
else ifeq ($(XCODEVERSION),9.3)
  # MIN_SWIFT_VERSION undefined: only check MAX_SWIFT_VERSION
  MAX_SWIFT_VERSION = 4.0
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 8,OS=11.3"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 4s,OS=9.0"
else
  # Swift 4.1 required: Xcode < 9.3 is not supported
endif

# If xcpretty is available, use it for xcodebuild output
XCPRETTY = 
ifdef XCPRETTY_PATH
  XCPRETTY = | xcpretty -c
  
  # On Travis-CI, use xcpretty-travis-formatter
  ifeq ($(TRAVIS),true)
    XCPRETTY += -f `xcpretty-travis-formatter`
  endif
endif

# Avoid the "No output has been received in the last 10m0s" error on Travis:
COCOAPODS_EXTRA_TIME =
ifeq ($(TRAVIS),true)
  COCOAPODS_EXTRA_TIME = --verbose
endif

# We test framework test suites, and if RxGRBD can be installed in an application:
test: test_framework test_install

test_framework: test_framework_RxGRDB
test_framework_RxGRDB: test_framework_RxGRDBmacOS test_framework_RxGRDBiOS
test_framework_RxGRDBiOS: test_framework_RxGRDBiOS_minTarget test_framework_RxGRDBiOS_maxTarget
test_install: test_CocoaPodsLint

test_framework_RxGRDBmacOS: test_framework_RxGRDBmacOS_maxSwift test_framework_RxGRDBmacOS_minSwift

test_framework_RxGRDBmacOS_maxSwift: Pods
	$(XCODEBUILD) \
	  -workspace RxGRDB.xcworkspace \
	  -scheme RxGRDBmacOS \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_RxGRDBmacOS_minSwift: Pods
ifdef MIN_SWIFT_VERSION
	$(XCODEBUILD) \
	  -workspace RxGRDB.xcworkspace \
	  -scheme RxGRDBmacOS \
	  SWIFT_VERSION=$(MIN_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)
endif

test_framework_RxGRDBiOS_minTarget: Pods
	$(XCODEBUILD) \
	  -workspace RxGRDB.xcworkspace \
	  -scheme RxGRDBiOS \
	  -destination $(MIN_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_RxGRDBiOS_maxTarget: test_framework_RxGRDBiOS_maxTarget_maxSwift test_framework_RxGRDBiOS_maxTarget_minSwift

test_framework_RxGRDBiOS_maxTarget_maxSwift: Pods
	$(XCODEBUILD) \
	  -workspace RxGRDB.xcworkspace \
	  -scheme RxGRDBiOS \
	  -destination $(MAX_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_RxGRDBiOS_maxTarget_minSwift: Pods
ifdef MIN_SWIFT_VERSION
	$(XCODEBUILD) \
	  -workspace RxGRDB.xcworkspace \
	  -scheme RxGRDBiOS \
	  -destination $(MAX_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MIN_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)
endif

test_CocoaPodsLint:
ifdef POD
	$(POD) repo update
	$(POD) lib lint --allow-warnings $(COCOAPODS_EXTRA_TIME)
else
	@echo CocoaPods must be installed for test_CocoaPodsLint
	@exit 1
endif

Pods:
ifdef POD
	$(POD) repo update
	$(POD) install
else
	@echo CocoaPods must be installed
	@exit 1
endif

# Cleanup
# =======

distclean:
	$(GIT) reset --hard
	$(GIT) clean -dffx .

.PHONY: distclean test
