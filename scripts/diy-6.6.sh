#!/bin/bash
set -e -o pipefail

WORKSPACE_ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
GOLANG126_SRC_DIR="$WORKSPACE_ROOT/scripts/6.6/golang1.26"
GOLANG126_FEED_DIR="feeds/packages/lang/golang1.26"

rm -rf "$GOLANG126_FEED_DIR"
mkdir -p "$GOLANG126_FEED_DIR"
cp -rf "$GOLANG126_SRC_DIR/." "$GOLANG126_FEED_DIR/"

./scripts/feeds update -f packages
./scripts/feeds install golang1.26

# 保持原作者的构建方式：
# Daed 和 PassWall Packages 内的 Go 程序统一使用 golang1.26/host。
for package_dir in package/dae package/passwall-packages; do
  if [ -d "$package_dir" ]; then
    find "$package_dir" -name "Makefile" -type f -exec sed -i \
      -e 's|\<golang/golang-package.mk\>|golang1.26/golang-package.mk|g' \
      -e 's|\<golang/host\>|golang1.26/host|g' {} +
  fi
done

# 同步仓库内维护的 6.6 patches 到 OpenWrt 源码树
if [ -d "$WORKSPACE_ROOT/patches/6.6" ]; then
  echo "[diy] 同步自定义 patches/6.6 目录到源码树"
  cp -rf "$WORKSPACE_ROOT/patches/6.6/." ./
else
  echo "[diy] patches/6.6 目录不存在，跳过"
fi
