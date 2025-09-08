include $(TOPDIR)/rules.mk

PKG_NAME:=kid-control
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Your Name <your.email@example.com>
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/kid-control
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Kid Internet Control
  DEPENDS:=+nftables +lua +luci +luci-base
  PKGARCH:=all
endef

define Package/kid-control/description
  A comprehensive internet time control system for children's devices on OpenWrt.
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/kid-control/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/kid-control $(1)/etc/config/
	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/kid-control $(1)/etc/init.d/
	
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_CONF) ./files/etc/kid_time_rules.nft $(1)/etc/
	$(INSTALL_BIN) ./files/etc/kid_control.sh $(1)/etc/
	
	$(INSTALL_DIR) $(1)/usr/bin
	ln -sf /etc/kid_control.sh $(1)/usr/bin/kid_control.sh
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/controller/kid-control.lua $(1)/usr/lib/lua/luci/controller/
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/kid-control
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/model/cbi/kid-control/overview.lua $(1)/usr/lib/lua/luci/model/cbi/kid-control/
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/model/cbi/kid-control/time-rules.lua $(1)/usr/lib/lua/luci/model/cbi/kid-control/
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/model/cbi/kid-control/block-list.lua $(1)/usr/lib/lua/luci/model/cbi/kid-control/
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/kid-control
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/kid-control/overview.htm $(1)/usr/lib/lua/luci/view/kid-control/
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/kid-control/time-rules.htm $(1)/usr/lib/lua/luci/view/kid-control/
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/kid-control/block-list.htm $(1)/usr/lib/lua/luci/view/kid-control/
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/kid-control/block-btn.htm $(1)/usr/lib/lua/luci/view/kid-control/
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/kid-control/unblock-btn.htm $(1)/usr/lib/lua/luci/view/kid-control/
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/kid-control/simple-buttons.htm $(1)/usr/lib/lua/luci/view/kid-control/
endef

define Package/kid-control/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
    /etc/init.d/kid-control enable
    echo "Kid Control installed successfully!"
fi
exit 0
endef

define Package/kid-control/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
    /etc/init.d/kid-control stop
    /etc/init.d/kid-control disable
fi
exit 0
endef

$(eval $(call BuildPackage,kid-control))
