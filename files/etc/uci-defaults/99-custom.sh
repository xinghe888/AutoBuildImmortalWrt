#!/bin/sh
# 99-custom.sh 就是immortalwrt固件首次启动时运行的脚本 位于固件内的/etc/uci-defaults/99-custom.sh
# Log file for debugging
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE
# 设置默认防火墙规则，方便虚拟机首次访问 WebUI
uci set firewall.@zone[1].input='ACCEPT'

# 设置主机名映射，解决安卓原生 TV 无法联网的问题
uci add dhcp domain
uci set "dhcp.@domain[-1].name=time.android.com"
uci set "dhcp.@domain[-1].ip=203.107.6.88"

# 检查配置文件pppoe-settings是否存在 该文件由build.sh动态生成
SETTINGS_FILE="/etc/config/pppoe-settings"
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "PPPoE settings file not found. Skipping." >> $LOGFILE
else
   # 读取pppoe信息($enable_pppoe、$pppoe_account、$pppoe_password)
   . "$SETTINGS_FILE"
fi

# 计算网卡数量
count=0
ifnames=""
for iface in /sys/class/net/*; do
  iface_name=$(basename "$iface")
  # 检查是否为物理网卡（排除回环设备和无线设备）
  if [ -e "$iface/device" ] && echo "$iface_name" | grep -Eq '^eth|^en'; then
    count=$((count + 1))
    ifnames="$ifnames $iface_name"
  fi
done
# 删除多余空格
ifnames=$(echo "$ifnames" | awk '{$1=$1};1')

# 网络设置
if [ "$count" -eq 1 ]; then
   # 单网口设备 类似于NAS模式 动态获取ip模式 具体ip地址取决于上一级路由器给它分配的ip 也方便后续你使用web页面设置旁路由
   # 单网口设备 不支持修改ip 不要在此处修改ip 
   uci set network.lan.proto='dhcp'
elif [ "$count" -gt 1 ]; then
   # 双网口设备：禁用WAN接口，只配置LAN接口
   echo "WAN interface disabled. Skipping WAN configuration." >> $LOGFILE
   # 设置LAN接口为静态IP
   uci set network.lan.proto='static'
   uci set network.lan.ipaddr='192.168.1.101'  # 修改为你想要的 IP 地址
   uci set network.lan.netmask='255.255.255.0'
   echo "LAN interface set to static IP 192.168.1.101 at $(date)" >> $LOGFILE
   # 不再配置WAN接口的PPPoE设置
   uci delete network.wan
   uci delete network.wan6
   echo "WAN interface removed from configuration." >> $LOGFILE
fi

# 设置所有网口可访问网页终端
uci delete ttyd.@ttyd[0].interface

# 设置所有网口可连接 SSH
uci set dropbear.@dropbear[0].Interface=''
uci commit

# 设置编译作者信息
FILE_PATH="/etc/openwrt_release"
NEW_DESCRIPTION="Compiled by xinghe888"
sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" "$FILE_PATH"

exit 0
