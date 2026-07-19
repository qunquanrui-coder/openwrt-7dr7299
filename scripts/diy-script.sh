#!/bin/bash
set -e -o pipefail

echo "=== diy-script: 开始自定义编译配置 ==="

# 固定第三方组件提交，避免上游更新后出现无法复现的编译问题
PASSWALL_PACKAGES_COMMIT="9d391e568d61c43be683b747b9ede811a61fc315"
SMALL_PACKAGE_COMMIT="33b50ac98ad0ffc20144a8a09c9c5a364eb1ef6c"

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

# 代理核心统一由 openwrt-passwall-packages 提供
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,v2ray-plugin,xray-plugin,geoview,shadow-tls,haproxy}

# 移除 PassWall 界面、Daed 和旧 SSR Plus 目录
rm -rf \
  feeds/luci/applications/luci-app-passwall \
  package/feeds/luci/luci-app-passwall \
  feeds/luci/applications/luci-app-ssr-plus \
  package/feeds/luci/luci-app-ssr-plus \
  package/passwall-packages \
  package/passwall-luci \
  package/helloworld \
  package/small-package \
  package/dae

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

clone_exact_commit() {
  local repo="$1"
  local commit="$2"
  local dest="$3"

  echo "[diy] 克隆并锁定: $repo @ $commit -> $dest"
  rm -rf "$dest"
  git init "$dest"
  git -C "$dest" remote add origin "$repo"
  git -C "$dest" fetch --depth=1 origin "$commit"
  git -C "$dest" checkout --detach FETCH_HEAD
}

clone_sparse_exact_commit() {
  local repo="$1"
  local commit="$2"
  local dest="$3"
  shift 3

  echo "[diy] 稀疏克隆并锁定: $repo @ $commit -> $dest"
  rm -rf "$dest"
  git init "$dest"
  git -C "$dest" remote add origin "$repo"
  git -C "$dest" sparse-checkout init --cone
  git -C "$dest" sparse-checkout set "$@"
  git -C "$dest" fetch --depth=1 origin "$commit"
  git -C "$dest" checkout --detach FETCH_HEAD
}

# 普通第三方应用
clone_if_missing https://github.com/sbwml/luci-app-mosdns          "" package/luci-app-mosdns
clone_if_missing https://github.com/ximiTech/luci-app-msd_lite     "" package/luci-app-msd_lite
clone_if_missing https://github.com/ximiTech/msd_lite              "" package/msd_lite
clone_if_missing https://github.com/pymumu/luci-app-smartdns       "" package/luci-app-smartdns
clone_if_missing https://github.com/pymumu/openwrt-smartdns        "" package/smartdns
clone_if_missing https://github.com/EasyTier/luci-app-easytier.git "" package/luci-app-easytier

# Xray、SSR Libev、ipt2socks、microsocks 等核心
clone_exact_commit \
  https://github.com/Openwrt-Passwall/openwrt-passwall-packages \
  "$PASSWALL_PACKAGES_COMMIT" \
  package/passwall-packages

# SSR Plus 只取 LuCI 界面，不重复获取 shadowsocksr-libev
clone_sparse_exact_commit \
  https://github.com/kenzok8/small-package.git \
  "$SMALL_PACKAGE_COMMIT" \
  package/small-package \
  luci-app-ssr-plus

# 修改版本为编译日期
DATE_VERSION="$(date +%Y.%m.%d)"
VERSION_FILE="include/version.mk"
echo "[diy] 修改版本为编译日期: $DATE_VERSION"
sed -i "s/^VERSION_NUMBER:=.*/VERSION_NUMBER:=-$DATE_VERSION by WoChen5770 + SSR Plus Xray/" "$VERSION_FILE"

echo "=== diy-script: 完成 ==="
