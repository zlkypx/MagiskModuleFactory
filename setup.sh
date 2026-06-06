#!/system/bin/sh

# MagiskModuleFactory 一键安装运行脚本
# github.com/zlkypx

echo ">>> 安装依赖..."
if command -v pkg >/dev/null 2>&1; then
    pkg install -y git curl wget zip unzip ffmpeg
else
    echo "非Termux环境，请手动安装: git, curl, wget, zip, unzip, ffmpeg"
fi

echo ">>> 克隆仓库..."
rm -rf MagiskModuleFactory 2>/dev/null
git clone https://github.com/zlkypx/MagiskModuleFactory.git
cd MagiskModuleFactory

echo ">>> 运行主脚本..."
bash MagiskModuleFactory.sh
