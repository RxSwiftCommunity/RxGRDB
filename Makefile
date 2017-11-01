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

# The Xcode Version, containing only the "MAJOR.MINOR" (ex. "8.3" for Xcode 8.3, 8.3.1, etc.)
XCODEVERSION := $(XCODEVERSION_MAJOR).$(XCODEVERSION_MINOR)

# Used to determine if xcpretty is available
XCPRETTY_PATH := $(shell command -v xcpretty 2> /dev/null)


# Tests
# =====

# xcodebuild actions to run test targets
TEST_ACTIONS = clean build build-for-testing test-without-building

# xcodebuild destination to run tests on iOS 8.1 (requires a pre-installed simulator)
MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 4s,OS=8.1"

ifeq ($(XCODEVERSION),9.2)
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 8,OS=11.2"
else ifeq ($(XCODEVERSION),9.1)
 MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 8,OS=11.1"
else ifeq ($(XCODEVERSION),9.0)
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 8,OS=11.0"
else
  # Xcode < 9.0 is not supported
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

# We test framework test suites, and if RxGRBD can be installed in an application:
test: test_framework test_install

test_framework: test_framework_RxGRDB
test_framework_RxGRDB: test_framework_RxGRDBmacOS test_framework_RxGRDBiOS
test_framework_RxGRDBiOS: test_framework_RxGRDBiOS_minTarget test_framework_RxGRDBiOS_maxTarget
test_install: test_CocoaPodsLint

test_framework_RxGRDBmacOS: GRDB.swift RxSwift
	$(XCODEBUILD) \
	  -project RxGRDB.xcodeproj \
	  -scheme RxGRDBmacOS \
	  $(TEST_ACTIONS)


test_framework_RxGRDBiOS_minTarget: GRDB.swift RxSwift
	$(XCODEBUILD) \
	  -project RxGRDB.xcodeproj \
	  -scheme RxGRDBiOS \
	  -destination $(MIN_IOS_DESTINATION) \
	  $(TEST_ACTIONS)

test_framework_RxGRDBiOS_maxTarget: GRDB.swift RxSwift
	$(XCODEBUILD) \
	  -project RxGRDB.xcodeproj \
	  -scheme RxGRDBiOS \
	  -destination $(MAX_IOS_DESTINATION) \
	  $(TEST_ACTIONS)

test_CocoaPodsLint:
ifdef POD
	$(POD) lib lint --allow-warnings
else
	@echo CocoaPods must be installed for test_CocoaPodsLint
	@exit 1
endif

# Target that setups GRDB.swift
GRDB.swift: Vendor/GRDB.swift/Tests

# Makes sure the Vendor/GRDB.swift submodule has been downloaded
Vendor/GRDB.swift/Tests:
	git submodule update --init Vendor/GRDB.swift

# Target that setups RxSwift
RxSwift: Vendor/RxSwift/Tests

# Makes sure the Vendor/RxSwift submodule has been downloaded
Vendor/RxSwift/Tests:
	git submodule update --init Vendor/RxSwift


# Cleanup
# =======

distclean:
	$(GIT) reset --hard
	$(GIT) clean -dffx .
	rm -rf Vendor/GRDB.swift && $(GIT) checkout -- Vendor/GRDB.swift
	rm -rf Vendor/RxSwift && $(GIT) checkout -- Vendor/RxSwift
	rm -rf Documentation/RxGRDBDemo/Vendor/Differ && $(GIT) checkout -- Documentation/RxGRDBDemo/Vendor/Differ

.PHONY: distclean test GRDB.swift RxSwift
