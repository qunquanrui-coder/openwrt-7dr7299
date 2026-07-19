#!/bin/bash
set -e -o pipefail

echo "=== diy-script: 开始自定义编译配置 ==="

# 修改默认 IP
echo "[diy] 修改默认 IP 为 192.168.123.1"
sed -i 's/192.168.6.1/192.168.123.1/g' package/base-files/files/bin/config_generate
sed -i -E 's|^root:[^:]*:|root::|' package/base-files/files/etc/shadow

# 移除将由第三方源码替换的包，避免重复定义
echo "[diy] 移除 feeds 中的旧版/冲突包"
rm -rf \
  feeds/packages/net/mosdns \
  feeds/packages/net/msd_lite \
  feeds/packages/net/smartdns \
  feeds/packages/net/dae \
  feeds/packages/net/daed \
  package/feeds/luci/luci-app-dae \
  package/feeds/luci/luci-app-daed

rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,v2ray-plugin,xray-plugin,geoview,shadow-tls,haproxy}

# 不使用 PassWall；同时移除可能存在的旧 SSR Plus 定义
rm -rf \
  feeds/luci/applications/luci-app-passwall \
  package/feeds/luci/luci-app-passwall \
  feeds/luci/applications/luci-app-ssr-plus \
  package/feeds/luci/luci-app-ssr-plus \
  package/passwall-packages \
  package/passwall-luci \
  package/helloworld

# 克隆第三方插件源（目录存在则跳过）
clone_if_missing() {
  local repo="$1" branch="$2" dest="$3"
  if [ -d "$dest" ]; then
    echo "[diy] 跳过已存在的仓库: $dest"
  else
    echo "[diy] 克隆: $repo -> $dest"
    git clone --depth=1 ${branch:+-b "$branch"} "$repo" "$dest"
  fi
}

clone_if_missing https://github.com/sbwml/luci-app-mosdns          "" package/luci-app-mosdns
clone_if_missing https://github.com/ximiTech/luci-app-msd_lite     "" package/luci-app-msd_lite
clone_if_missing https://github.com/ximiTech/msd_lite              "" package/msd_lite
clone_if_missing https://github.com/pymumu/luci-app-smartdns       "" package/luci-app-smartdns
clone_if_missing https://github.com/pymumu/openwrt-smartdns        "" package/smartdns
clone_if_missing https://github.com/QiuSimons/luci-app-daed        "" package/dae

# ShadowSocksR Plus+ 源：仅在 CUSTOMIZE.txt 中选择基础 SSR 客户端
clone_if_missing https://github.com/fw876/helloworld.git           "" package/helloworld

clone_if_missing https://github.com/EasyTier/luci-app-easytier.git "" package/luci-app-easytier

# Daed Web UI 修正
if [ -f package/dae/daed/Makefile ]; then
  sed -i '/^GO_PKG:=github.com\/daeuniverse\/dae-wing$/a GO_PKG_INSTALL_EXTRA:=webrender/web' \
    package/dae/daed/Makefile
fi

# 修改版本为编译日期
DATE_VERSION="$(date +%Y.%m.%d)"
VERSION_FILE="include/version.mk"
echo "[diy] 修改版本为编译日期: $DATE_VERSION"
sed -i "s/^VERSION_NUMBER:=.*/VERSION_NUMBER:=-$DATE_VERSION by WoChen5770 + SSR Plus/" "$VERSION_FILE"

echo "=== diy-script: 完成 ==="
