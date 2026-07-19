#!/bin/bash
set -e -o pipefail

echo "=== diy-script: 开始自定义编译配置 ==="

# 修改默认 IP
echo "[diy] 修改默认 IP 为 192.168.123.1"
sed -i 's/192.168.6.1/192.168.123.1/g' package/base-files/files/bin/config_generate
sed -i -E 's|^root:[^:]*:|root::|' package/base-files/files/etc/shadow

# 移除将由第三方源码替换的应用，避免重复定义
echo "[diy] 移除 feeds 中的旧版/冲突应用"
rm -rf \
  feeds/packages/net/mosdns \
  feeds/packages/net/msd_lite \
  feeds/packages/net/smartdns \
  feeds/packages/net/dae \
  feeds/packages/net/daed \
  package/feeds/luci/luci-app-dae \
  package/feeds/luci/luci-app-daed

# 移除 PassWall 及旧 SSR Plus 源
rm -rf \
  feeds/luci/applications/luci-app-passwall \
  package/feeds/luci/luci-app-passwall \
  feeds/luci/applications/luci-app-ssr-plus \
  package/feeds/luci/luci-app-ssr-plus \
  package/passwall-packages \
  package/passwall-luci \
  package/helloworld \
  package/small-package

# 克隆普通第三方插件源
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
clone_if_missing https://github.com/EasyTier/luci-app-easytier.git "" package/luci-app-easytier

# 获取带“组件升级”页面的 ShadowSocksR Plus+ 196
# 只稀疏检出 luci-app-ssr-plus，依赖包使用当前 ImmortalWrt feeds
echo "[diy] 克隆 kenzok8/small-package 的 ShadowSocksR Plus+"
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
