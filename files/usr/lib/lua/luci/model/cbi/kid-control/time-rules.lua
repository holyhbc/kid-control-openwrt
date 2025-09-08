m = Map("kid-control", translate("儿童上网控制 - 时间规则"), 
    translate("在此添加和管理上网时间规则。"))

s = m:section(TypedSection, "time_rules", translate("时间规则列表"))
s.template = "cbi/tblsection"
s.anonymous = true
s.addremove = true

enabled = s:option(Flag, "enabled", translate("启用"))
enabled.default = "1"
enabled.rmempty = false

name = s:option(Value, "name", translate("规则名称"))
name.placeholder = "例如：上学日晚间限制"
name.rmempty = false

-- 使用动态设备选择
device = s:option(Value, "device", translate("设备"))
device.rmempty = false
device.template = "kid-control/device-select"

target = s:option(ListValue, "target", translate("控制方式"))
target:value("ip", "IP地址")
target:value("mac", "MAC地址")
target.default = "ip"

start_time = s:option(Value, "start_time", translate("开始时间"))
start_time.rmempty = false
start_time.validate = function(self, value)
    if value:match("^%d%d:%d%d$") then
        return value
    else
        return nil, "时间格式必须为 HH:MM"
    end
end

end_time = s:option(Value, "end_time", translate("结束时间"))
end_time.rmempty = false
end_time.validate = function(self, value)
    if value:match("^%d%d:%d%d$") then
        return value
    else
        return nil, "时间格式必须为 HH:MM"
    end
end

-- 星期选择
mon = s:option(Flag, "mon", translate("周一"))
tue = s:option(Flag, "tue", translate("周二"))
wed = s:option(Flag, "wed", translate("周三"))
thu = s:option(Flag, "thu", translate("周四"))
fri = s:option(Flag, "fri", translate("周五"))
sat = s:option(Flag, "sat", translate("周六"))
sun = s:option(Flag, "sun", translate("周日"))

return m
