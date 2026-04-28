TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = cam2obs_vcam

cam2obs_vcam_FILES = Tweak.xm MJPEGClient.m
cam2obs_vcam_CFLAGS = -fobjc-arc
cam2obs_vcam_FRAMEWORKS = UIKit AVFoundation CoreMedia CoreVideo ImageIO
cam2obs_vcam_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

before-package::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Applications/CamToggle.app
	$(ECHO_NOTHING)cp -r app/* $(THEOS_STAGING_DIR)/Applications/CamToggle.app/
	$(ECHO_NOTHING)cp control $(THEOS_STAGING_DIR)/DEBIAN/control
	$(ECHO_NOTHING)cp postinst $(THEOS_STAGING_DIR)/DEBIAN/postinst
	$(ECHO_NOTHING)chmod +x $(THEOS_STAGING_DIR)/DEBIAN/postinst