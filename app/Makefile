TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = CamToggle
CamToggle_FILES = main.m AppDelegate.m ViewController.m
CamToggle_FRAMEWORKS = UIKit Foundation
CamToggle_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk