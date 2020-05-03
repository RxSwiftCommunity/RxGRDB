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
SWIFT = $(shell $(XCRUN) --find swift 2> /dev/null)

# Used to determine if xcpretty is available
XCPRETTY_PATH := $(shell command -v xcpretty 2> /dev/null)


# Tests
# =====

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

test: test_SPM test_install
test_install: test_CocoaPodsLint

test_SPM:
	$(SWIFT) package clean
	$(SWIFT) build
	$(SWIFT) build -c release
	set -o pipefail && $(SWIFT) test $(XCPRETTY)

test_CocoaPodsLint:
ifdef POD
	$(POD) repo update
	$(POD) lib lint --allow-warnings $(COCOAPODS_EXTRA_TIME)
else
	@echo CocoaPods must be installed for test_CocoaPodsLint
	@exit 1
endif

# Cleanup
# =======

distclean:
	$(GIT) reset --hard
	$(GIT) clean -dffx .

.PHONY: distclean test
