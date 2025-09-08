#!/bin/sh
#
# kid_control.sh - 儿童上网控制脚本
# 支持 IP 或 MAC 封禁，兼容 OpenClash
#

# 默认配置
TABLE_TIME="kidblock"
CHAIN_TIME="filter"
TABLE_NOW="kidnow"
CHAIN_NOW="prerouting"

# 显示用法
show_usage() {
    echo "用法: $0 {on|off|block|unblock} [ip|mac] [地址]"
    echo "示例:"
    echo "  $0 on                   # 启用时间规则"
    echo "  $0 off                  # 禁用时间规则"
    echo "  $0 block ip 192.168.1.100 # 立即封禁IP"
    echo "  $0 block mac AA:BB:CC:DD:EE:FF # 立即封禁MAC"
    echo "  $0 unblock              # 立即解禁所有"
}

# 检查设备是否已被封禁
is_device_blocked() {
    local target_type=$1
    local device=$2
    
    if [ "$target_type" = "ip" ]; then
        nft list table inet $TABLE_NOW 2>/dev/null | grep -q "ip saddr $device drop"
    else
        nft list table inet $TABLE_NOW 2>/dev/null | grep -q "ether saddr $device drop"
    fi
    return $?
}

# 启用时间规则控制
enable_time_control() {
    # 检查是否有规则文件
    if [ ! -f "/etc/kid_time_rules.nft" ]; then
        echo "? 没有找到时间规则文件 /etc/kid_time_rules.nft"
        return 1
    fi
    
    # 创建nft表
    nft add table inet $TABLE_TIME 2>/dev/null
    nft "add chain inet $TABLE_TIME $CHAIN_TIME { type filter hook forward priority 0; policy accept; }" 2>/dev/null
    nft flush chain inet $TABLE_TIME $CHAIN_TIME
    
    # 加载规则
    nft -f /etc/kid_time_rules.nft
    
    echo "? 已启用时间规则控制"
}

# 禁用时间规则控制
disable_time_control() {
    nft delete table inet $TABLE_TIME 2>/dev/null
    echo "? 已禁用时间规则控制"
}

# 立即封禁设备
block_now() {
    local target_type=$1
    local device=$2
    
    # 检查设备是否已被封禁
    if is_device_blocked "$target_type" "$device"; then
        echo "! 设备 $device 已被封禁，无需重复操作"
        return 0
    fi
    
    # 创建nft表
    nft add table inet $TABLE_NOW 2>/dev/null
    nft "add chain inet $TABLE_NOW $CHAIN_NOW { type filter hook prerouting priority -100; policy accept; }" 2>/dev/null
    
    if [ "$target_type" = "ip" ]; then
        nft add rule inet $TABLE_NOW $CHAIN_NOW ip saddr $device drop
        echo "?? IP地址 $device 已被封禁"
    elif [ "$target_type" = "mac" ]; then
        nft add rule inet $TABLE_NOW $CHAIN_NOW ether saddr $device drop
        echo "?? MAC地址 $device 已被封禁"
    else
        echo "! 错误的目标类型: $target_type"
        return 1
    fi
}

# 立即解禁设备
unblock_now() {
    nft delete table inet $TABLE_NOW 2>/dev/null
    echo "? 已解除所有立即封禁"
}

# 主入口
case "$1" in
    on)
        enable_time_control
        ;;
    off)
        disable_time_control
        ;;
    block)
        if [ $# -lt 3 ]; then
            echo "! 错误: 需要指定目标类型和地址"
            show_usage
            exit 1
        fi
        block_now "$2" "$3"
        ;;
    unblock)
        unblock_now
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
