#!/bin/bash
set -e -o pipefail

echo "=== diy-script: 开始自定义编译配置 ==="

# 修改默认 IP 和 root 默认密码
echo "[diy] 修改默认 IP 为 192.168.123.1"
sed -i 's/192.168.6.1/192.168.123.1/g' package/base-files/files/bin/config_generate
sed -i -E 's|^root:[^:]*:|root::|' package/base-files/files/etc/shadow

# 移除将由第三方源码替换的普通应用
echo "[diy] 移除 feeds 中的旧版/冲突应用"
rm -rf \
  feeds/packages/net/mosdns \
  feeds/packages/net/msd_lite \
  feeds/packages/net/smartdns \
  feeds/packages/net/dae \
  feeds/packages/net/daed \
  package/feeds/luci/luci-app-dae \
  package/feeds/luci/luci-app-daed

# 保持原作者已验证的 PassWall Packages 依赖体系：
# 先移除 feeds 内同名代理核心，再统一使用 openwrt-passwall-packages。
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,v2ray-plugin,xray-plugin,geoview,shadow-tls,haproxy}

# 不编译 PassWall 界面；移除旧 SSR Plus 和以前检出的第三方目录
rm -rf \
  feeds/luci/applications/luci-app-passwall \
  package/feeds/luci/luci-app-passwall \
  feeds/luci/applications/luci-app-ssr-plus \
  package/feeds/luci/luci-app-ssr-plus \
  package/passwall-packages \
  package/passwall-luci \
  package/helloworld \
  package/small-package

clone_if_missing() {
  local repo="$1"
  local branch="$2"
  local dest="$3"

  if [ -d "$dest" ]; then
    echo "[diy] 跳过已存在的仓库: $dest"
  else
    echo "[diy] 克隆: $repo -> $dest"
    if [ -n "$branch" ]; then
      git clone --depth=1 -b "$branch" "$repo" "$dest"
    else
      git clone --depth=1 "$repo" "$dest"
    fi
  fi
}

# 普通第三方应用
clone_if_missing https://github.com/sbwml/luci-app-mosdns          "" package/luci-app-mosdns
clone_if_missing https://github.com/ximiTech/luci-app-msd_lite     "" package/luci-app-msd_lite
clone_if_missing https://github.com/ximiTech/msd_lite              "" package/msd_lite
clone_if_missing https://github.com/pymumu/luci-app-smartdns       "" package/luci-app-smartdns
clone_if_missing https://github.com/pymumu/openwrt-smartdns        "" package/smartdns
clone_if_missing https://github.com/QiuSimons/luci-app-daed        "" package/dae
clone_if_missing https://github.com/EasyTier/luci-app-easytier.git "" package/luci-app-easytier

# Xray、SSR Libev、ipt2socks、microsocks 等代理核心统一来自同一个仓库。
# 这里只使用 packages，不克隆和不编译 PassWall LuCI 界面。
clone_if_missing \
  https://github.com/Openwrt-Passwall/openwrt-passwall-packages \
  "" \
  package/passwall-packages

# SSR Plus 只取 LuCI 界面，不再从 small-package 重复获取 shadowsocksr-libev。
echo "[diy] 克隆带组件升级页面的 ShadowSocksR Plus+"
git clone --depth=1 --filter=blob:none --sparse \
  https://github.com/kenzok8/small-package.git package/small-package
git -C package/small-package sparse-checkout set luci-app-ssr-plus

# Daed Web UI 修正
if [ -f package/dae/daed/Makefile ]; then
  sed -i '/^GO_PKG:=github.com\/daeuniverse\/dae-wing$/a GO_PKG_INSTALL_EXTRA:=webrender/web' \
    package/dae/daed/Makefile
fi

# 修改版本为编译日期
DATE_VERSION="$(date +%Y.%m.%d)"
VERSION_FILE="include/version.mk"
echo "[diy] 修改版本为编译日期: $DATE_VERSION"
sed -i "s/^VERSION_NUMBER:=.*/VERSION_NUMBER:=-$DATE_VERSION by WoChen5770 + SSR Plus Xray/" "$VERSION_FILE"

echo "=== diy-script: 完成 ==="
