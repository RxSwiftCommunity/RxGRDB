# Requirements
# ============
#
# CocoaPods ~> 1.2.0 - https://cocoapods.org

POD := $(shell command -v pod)


# Targets
# =======
#
# make: run all tests
# make test: run all tests

default: test


# Tests
# =====

# xcodebuild actions to run test targets
TEST_ACTIONS = clean build build-for-testing test-without-building

# xcodebuild destination to run tests on latest iOS (Xcode 8.3)
IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 7,OS=10.3"

# We test framework test suites, and if RxGRBD can be installed in an application:
test: test_framework test_install

test_framework: test_framework_RxGRDB
test_framework_RxGRDB: test_framework_RxGRDBmacOS test_framework_RxGRDBiOS
test_install: test_CocoaPodsLint

test_framework_RxGRDBmacOS: GRDB.swift RxSwift
	xcodebuild \
	  -project RxGRDB.xcodeproj \
	  -scheme RxGRDBmacOS \
	  $(TEST_ACTIONS)

test_framework_RxGRDBiOS: GRDB.swift RxSwift
	xcodebuild \
	  -project RxGRDB.xcodeproj \
	  -scheme RxGRDBiOS \
	  -destination $(IOS_DESTINATION) \
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

.PHONY: test GRDB.swift RxSwift
