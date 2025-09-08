module("luci.controller.kid-control", package.seeall)

function index()
    entry({"admin", "services", "kid-control"}, firstchild(), _("儿童上网控制"), 60).dependent = false
    
    entry({"admin", "services", "kid-control", "overview"}, template("kid-control/overview"), _("概览"), 10)
    entry({"admin", "services", "kid-control", "time-rules"}, cbi("kid-control/time-rules"), _("时间规则"), 20)
    entry({"admin", "services", "kid-control", "block-list"}, cbi("kid-control/block-list"), _("封禁设备"), 30)
    
    entry({"admin", "services", "kid-control", "get_devices"}, call("get_network_devices"))
    entry({"admin", "services", "kid-control", "get_status"}, call("get_service_status"))
    entry({"admin", "services", "kid-control", "apply"}, call("apply_configuration"))
    entry({"admin", "services", "kid-control", "block_now"}, call("block_device_now"))
    entry({"admin", "services", "kid-control", "unblock_now"}, call("unblock_device_now"))
    entry({"admin", "services", "kid-control", "toggle_service"}, call("toggle_service"))
    entry({"admin", "services", "kid-control", "get_device_options"}, call("get_device_options"))
end

function get_service_status()
    local status = {
        running = false,
        time_rules = 0,
        blocked_devices = 0,
        unique_blocked_devices = 0,
        service_installed = false
    }
    
    -- 检查服务是否安装（通过检查初始化脚本）
    local fs = require "nixio.fs"
    status.service_installed = fs.access("/etc/init.d/kid-control")
    
    -- 检查服务是否运行（通过检查nft表是否存在）
    local nft_check = io.popen("nft list table inet kidblock 2>/dev/null")
    if nft_check then
        local output = nft_check:read("*all")
        nft_check:close()
        status.running = (output and output ~= "" and not output:find("No such file or directory"))
    end
    
    -- 检查时间规则数量
    if fs.access("/etc/kid_time_rules.nft") then
        local content = fs.readfile("/etc/kid_time_rules.nft") or ""
        for _ in content:gmatch("drop") do
            status.time_rules = status.time_rules + 1
        end
    end
    
    -- 检查封禁设备
    local nft_now = io.popen("nft list table inet kidnow 2>/dev/null")
    if nft_now then
        local content = nft_now:read("*all")
        nft_now:close()
        
        if content and content ~= "" then
            -- 提取所有封禁的IP和MAC
            local ips = {}
            local macs = {}
            
            for line in content:gmatch("[^\n]+") do
                if line:find("ip saddr") and line:find("drop") then
                    local ip = line:match("ip saddr ([^%s]+)")
                    if ip then
                        if not ips[ip] then
                            ips[ip] = true
                            status.unique_blocked_devices = status.unique_blocked_devices + 1
                        end
                        status.blocked_devices = status.blocked_devices + 1
                    end
                elseif line:find("ether saddr") and line:find("drop") then
                    local mac = line:match("ether saddr ([^%s]+)")
                    if mac then
                        if not macs[mac] then
                            macs[mac] = true
                            status.unique_blocked_devices = status.unique_blocked_devices + 1
                        end
                        status.blocked_devices = status.blocked_devices + 1
                    end
                end
            end
        end
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json(status)
end

function get_network_devices()
    local devices = {}
    
    -- 方法1: 使用arp命令获取设备
    local arp = io.popen("arp -n 2>/dev/null | awk 'NR>1 {print $1\" \"$3}'")
    if arp then
        for line in arp:lines() do
            local ip, mac = line:match("^(%d+%.%d+%.%d+%.%d+)%s+([%x:]+)")
            if ip and mac then
                table.insert(devices, {
                    ip = ip,
                    mac = mac:upper(),
                    hostname = ""
                })
            end
        end
        arp:close()
    end
    
    -- 方法2: 从DHCP租约获取设备
    local lease_files = {"/tmp/dhcp.leases", "/var/dhcp.leases"}
    for _, file in ipairs(lease_files) do
        local leases = io.open(file)
        if leases then
            for line in leases:lines() do
                local timestamp, mac, ip, hostname = line:match("^(%d+)%s+([%x:]+)%s+(%d+%.%d+%.%d+%.%d+)%s+(%S*)")
                if mac and ip then
                    table.insert(devices, {
                        ip = ip,
                        mac = mac:upper(),
                        hostname = hostname ~= "*" and hostname or ""
                    })
                end
            end
            leases:close()
        end
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json(devices)
end

function get_device_options()
    local devices = {}
    
    -- 获取网络设备
    local arp = io.popen("arp -n 2>/dev/null | awk 'NR>1 {print $1\" \"$3}'")
    if arp then
        for line in arp:lines() do
            local ip, mac = line:match("^(%d+%.%d+%.%d+%.%d+)%s+([%x:]+)")
            if ip and mac then
                mac = mac:upper()
                table.insert(devices, {
                    value = ip,
                    text = ip .. " (MAC: " .. mac .. ")",
                    type = "ip"
                })
                table.insert(devices, {
                    value = mac,
                    text = "MAC: " .. mac,
                    type = "mac"
                })
            end
        end
        arp:close()
    end
    
    -- 从DHCP租约获取设备
    local lease_files = {"/tmp/dhcp.leases", "/var/dhcp.leases"}
    for _, file in ipairs(lease_files) do
        local leases = io.open(file)
        if leases then
            for line in leases:lines() do
                local timestamp, mac, ip, hostname = line:match("^(%d+)%s+([%x:]+)%s+(%d+%.%d+%.%d+%.%d+)%s+(%S*)")
                if mac and ip then
                    mac = mac:upper()
                    local display = ip
                    if hostname and hostname ~= "*" then
                        display = display .. " (" .. hostname .. ")"
                    end
                    display = display .. " [MAC: " .. mac .. "]"
                    
                    table.insert(devices, {
                        value = ip,
                        text = display,
                        type = "ip"
                    })
                    table.insert(devices, {
                        value = mac,
                        text = "MAC: " .. mac,
                        type = "mac"
                    })
                end
            end
            leases:close()
        end
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json(devices)
end

function block_device_now()
    local device = luci.http.formvalue("device")
    local target = luci.http.formvalue("target") or "ip"
    
    if not device or device == "" then
        luci.http.prepare_content("application/json")
        luci.http.write_json({success = false, error = "设备不能为空"})
        return
    end
    
    if target == "ip" then
        os.execute(string.format("/etc/kid_control.sh block ip %s >/dev/null 2>&1", device))
    else
        os.execute(string.format("/etc/kid_control.sh block mac %s >/dev/null 2>&1", device))
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({success = true})
end

function unblock_device_now()
    os.execute("/etc/kid_control.sh unblock >/dev/null 2>&1")
    luci.http.prepare_content("application/json")
    luci.http.write_json({success = true})
end

function toggle_service()
    local action = luci.http.formvalue("action")
    if action == "start" then
        os.execute("/etc/init.d/kid-control start >/dev/null 2>&1")
    else
        os.execute("/etc/init.d/kid-control stop >/dev/null 2>&1")
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({success = true})
end

function apply_configuration()
    local fs = require "nixio.fs"
    local uci = require "luci.model.uci".cursor()
    
    -- 生成nftables规则文件
    local nft_rules = [[
# 儿童上网控制时间规则
# 自动生成，请勿手动修改

table inet kidblock {
    chain filter {
        type filter hook forward priority 0; policy accept;
    }
}

flush chain inet kidblock filter

]]
    
    -- 添加时间规则
    uci:foreach("kid-control", "time_rules", function(s)
        if s.enabled == "1" then
            local days = {}
            if s.mon == "1" then table.insert(days, "mon") end
            if s.tue == "1" then table.insert(days, "tue") end
            if s.wed == "1" then table.insert(days, "wed") end
            if s.thu == "1" then table.insert(days, "thu") end
            if s.fri == "1" then table.insert(days, "fri") end
            if s.sat == "1" then table.insert(days, "sat") end
            if s.sun == "1" then table.insert(days, "sun") end
            
            if #days > 0 then
                local days_str = table.concat(days, ",")
                
                if s.target == "ip" then
                    nft_rules = nft_rules .. string.format(
                        'add rule inet kidblock filter ip saddr %s time hour >= "%s" time hour < "%s" day %s drop\n',
                        s.device, s.start_time:sub(1, 2), s.end_time:sub(1, 2), days_str
                    )
                else
                    nft_rules = nft_rules .. string.format(
                        'add rule inet kidblock filter ether saddr %s time hour >= "%s" time hour < "%s" day %s drop\n',
                        s.device:upper(), s.start_time:sub(1, 2), s.end_time:sub(1, 2), days_str
                    )
                end
            end
        end
    end)
    
    -- 写入规则文件
    fs.writefile("/etc/kid_time_rules.nft", nft_rules)
    
    -- 重启服务
    os.execute("/etc/init.d/kid-control restart >/dev/null 2>&1")
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({success = true})
end
