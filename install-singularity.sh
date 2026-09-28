#!/usr/bin/env bash
# Singularity Desktop 一键安装脚本（NixOS 最小化安装用）
# 用法：sudo bash install-singularity.sh
set -euo pipefail

NIXOS_DIR=/etc/nixos
FLAKE="$NIXOS_DIR/flake.nix"
CONFIG="$NIXOS_DIR/configuration.nix"

echo "=== Singularity Desktop 一键安装 ==="

# 必须是 root
if [ "$EUID" -ne 0 ]; then
  echo "请用 sudo 运行：sudo bash $0"
  exit 1
fi

# 检查环境
[ -f "$CONFIG" ] || { echo "错误：找不到 $CONFIG，这是 NixOS 吗？"; exit 1; }
[ -f "$NIXOS_DIR/hardware-configuration.nix" ] || { echo "错误：找不到 hardware-configuration.nix"; exit 1; }
ping -c1 -W3 cache.nixos.org >/dev/null 2>&1 || echo "警告：连不上 cache.nixos.org，先检查网络"

# 第 1 步：开启 flakes
if grep -q 'experimental-features' "$CONFIG"; then
  echo "[1/4] flakes 已开启，跳过"
else
  echo "[1/4] 在 configuration.nix 中启用 flakes"
  cp "$CONFIG" "$CONFIG.bak.$(date +%s)"
  # 插到第一个 { 后面
  sed -i '0,/{/s//{\n  nix.settings.experimental-features = [ "nix-command" "flakes" ];/' "$CONFIG"
fi

# 第 2 步：写 flake.nix
if [ -f "$FLAKE" ]; then
  echo "[2/4] flake.nix 已存在，备份为 flake.nix.bak"
  cp "$FLAKE" "$FLAKE.bak.$(date +%s)"
fi

HOSTNAME=$(hostname)
echo "[2/4] 生成 $FLAKE（主机名：$HOSTNAME）"
cat > "$FLAKE" <<EOF
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    singularity-desktop.url = "github:mateoalfaro/singularity-flake";
  };

  outputs = { self, nixpkgs, singularity-desktop, ... }: {
    nixosConfigurations.$HOSTNAME = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ./hardware-configuration.nix
        singularity-desktop.nixosModules.default
        {
          programs.singularity-desktop = {
            enable = true;
            greeter.enable = true;
          };
        }
      ];
    };
  };
}
EOF

# 第 3 步：重建
echo "[3/4] 重建系统（会下载一堆包，可能要几分钟到十几分钟）"
nixos-rebuild boot --flake "$NIXOS_DIR#$HOSTNAME"

echo "[4/4] 完成！"
echo ""
echo "现在重启就会进入 Singularity 登录界面："
echo "  reboot"
