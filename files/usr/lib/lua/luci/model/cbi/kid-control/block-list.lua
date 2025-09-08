m = Map("kid-control", translate("儿童上网控制 - 封禁设备"), 
    translate("在此立即封禁或解禁设备。"))

s = m:section(TypedSection, "block_list", translate("封禁设备列表"))
s.template = "cbi/tblsection"
s.anonymous = true
s.addremove = true

device = s:option(Value, "device", translate("设备"))
device.rmempty = false
device.template = "kid-control/device-select"

target = s:option(ListValue, "target", translate("控制方式"))
target:value("ip", "IP地址")
target:value("mac", "MAC地址")
target.default = "ip"

-- 直接在Lua中处理封禁按钮
block_btn = s:option(Button, "_block", translate("封禁"))
block_btn.inputtitle = translate("封禁")
block_btn.inputstyle = "apply"
block_btn.write = function(self, section, value)
    local device = m:get(section, "device")
    local target = m:get(section, "target") or "ip"
    
    if not device or device == "" then
        self.error_msg = "请先输入设备IP或MAC地址"
        return
    end
    
    if target == "ip" then
        os.execute(string.format("/etc/kid_control.sh block ip %s >/dev/null 2>&1", device))
    else
        os.execute(string.format("/etc/kid_control.sh block mac %s >/dev/null 2>&1", device))
    end
    
    luci.http.redirect(luci.dispatcher.build_url("admin/services/kid-control/block-list"))
end

-- 直接在Lua中处理解禁按钮
unblock_btn = s:option(Button, "_unblock", translate("解禁"))
unblock_btn.inputtitle = translate("解禁")
unblock_btn.inputstyle = "reset"
unblock_btn.write = function(self, section, value)
    local device = m:get(section, "device")
    local target = m:get(section, "target") or "ip"
    
    if device and device ~= "" then
        -- 解禁特定设备（需要修改kid_control.sh支持）
        os.execute("/etc/kid_control.sh unblock >/dev/null 2>&1")
    else
        -- 解禁所有设备
        os.execute("/etc/kid_control.sh unblock >/dev/null 2>&1")
    end
    
    luci.http.redirect(luci.dispatcher.build_url("admin/services/kid-control/block-list"))
end

return m
