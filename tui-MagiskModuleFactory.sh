#!/system/bin/sh

# 生成时间戳，格式如 20260606_143052，用于保证每次生成的模块 ID 和 ZIP 文件名唯一
get_timestamp() {
    date +"%Y%m%d_%H%M%S" 2>/dev/null || echo "unknown"
}

# 主菜单界面
show_menu() {
    echo "MagiskModuleFactory - github.com/zlkypx"
    echo ""
    echo "1. 普通应用转系统应用模块"
    echo "2. 生成修改/system模块"
    echo "3. 生成修改/vendor模块"
    echo "4. 生成修改系统属性模块"
    echo "5. 开机动画模块(MP4/zip)"
    echo "6. 生成修改机型模块"
    echo "7. 自定义hosts文件模块"
    echo "8. 开机自启脚本模块"
    echo "9. 隐藏Magisk模块"
    echo "10. 退出"
    echo ""
    echo -n "请选择 [1-10]: "
}

# 获取第三方应用包名列表，pm list packages -3 列出用户安装的应用，cut -d: -f2 去掉前缀
get_apps() {
    local count=1
    pm list packages -3 | cut -d: -f2 | while read pkg; do
        echo "[$count] $pkg"
        count=$((count + 1))
    done
}

# 通用模块安装函数，按优先级检测 KernelSU(ksud) -> APatch(apd) -> Magisk
install_magisk_module() {
    local zip_file=$1

    if [ ! -f "$zip_file" ]; then
        echo "错误: 模块文件不存在: $zip_file"
        return 1
    fi

    echo "模块文件路径: $zip_file"

    if [ -f "/data/adb/ksud" ]; then
        echo "使用ksud命令安装模块..."
        /data/adb/ksud module install "$zip_file"
    elif [ -f "/data/adb/apd" ]; then
        echo "使用apd命令安装模块..."
        /data/adb/apd module install "$zip_file"
    elif command -v magisk >/dev/null 2>&1; then
        echo "使用magisk命令安装模块..."
        magisk --install-module "$zip_file"
    else
        echo "错误: 未找到可用的模块安装方法"
        return 1
    fi

    local result=$?
    [ $result -eq 0 ] && echo "模块安装成功!" || echo "模块安装失败，错误码: $result"
    return $result
}

# 创建 Magisk 模块的标准目录结构和必需文件
# work_dir: 临时工作目录
# module_id: 模块唯一标识（最终会写入 module.prop 的 id= 字段）
# module_name: 模块显示名称
# description: 模块描述
create_common_module() {
    local work_dir="$1"
    local module_id="$2"
    local module_name="$3"
    local description="$4"

    mkdir -p "$work_dir"
    cd "$work_dir"

    mkdir -p META-INF/com/google/android

    # update-binary 是 Magisk 模块必需的安装脚本，用于处理模块安装逻辑
    cat > META-INF/com/google/android/update-binary << 'EOF'
#!/sbin/sh
umask 022
ui_print() { echo "$1"; }
require_new_magisk() {
  ui_print "*******************************"
  ui_print " Please install Magisk v20.4+! "
  ui_print "*******************************"
  exit 1
}
OUTFD=$2
ZIPFILE=$3
mount /data 2>/dev/null
[ -f /data/adb/magisk/util_functions.sh ] || require_new_magisk
. /data/adb/magisk/util_functions.sh
[ $MAGISK_VER_CODE -lt 20400 ] && require_new_magisk
install_module
exit 0
EOF

    # updater-script 在 Magisk 模块中只需包含 #MAGISK 标记
    echo "#MAGISK" > META-INF/com/google/android/updater-script

    # module.prop 是模块的配置文件，Magisk 通过读取此文件识别模块
    cat > module.prop << EOF
id=$module_id
name=$module_name
version=1.0
versionCode=1
author=MagiskModuleFactory / github.com/zlkypx
description=$description
EOF
}

# 功能1：将普通应用转换为系统应用
# 原理：将 APK 和 lib 文件放入 system/app/包名/ 目录，Magisk 会在开机时 overlay 到 /system
create_module_structure() {
    local package_name=$1
    local current_dir=$(pwd)
    local timestamp=$(get_timestamp)
    local module_id="${package_name}_${timestamp}"
    local zip_name="MagiskModuleFactory_${package_name}_${timestamp}.zip"

    work_dir="${package_name}_module_${timestamp}"
    create_common_module "$work_dir" "$module_id" "$package_name" "固化系统应用 - MagiskModuleFactory"

    mkdir -p "system/app/$package_name"

    # pm path 获取 APK 安装路径，输出格式 package:/path/to/base.apk
    apk_path=$(pm path "$package_name" | cut -d: -f2)

    if [ -n "$apk_path" ] && [ -f "$apk_path" ]; then
        cp "$apk_path" "system/app/$package_name/base.apk"
        if [ $? -ne 0 ]; then
            echo "错误: 复制APK失败，可能需要root权限"
            cd "$current_dir"
            rm -rf "$work_dir"
            return 1
        fi
        echo "已复制APK文件"

        echo "正在提取lib文件..."
        temp_dir=$(mktemp -d)
        unzip -q "$apk_path" -d "$temp_dir"

        # 如果 APK 包含 native 库，将其复制到模块目录
        if [ -d "$temp_dir/lib" ]; then
            mv "$temp_dir/lib" "system/app/$package_name/"
            echo "已提取lib文件"
        else
            echo "该应用没有lib文件"
        fi

        rm -rf "$temp_dir"
    else
        echo "无法找到应用的APK文件"
        return 1
    fi

    echo "已创建模块目录: $work_dir"

    echo "正在压缩为ZIP文件..."
    zip_file="${current_dir}/${zip_name}"
    # -r 递归压缩，重定向输出静默执行
    zip -r "$zip_file" ./* > /dev/null 2>&1
    cd "$current_dir"

    if [ -f "$zip_file" ]; then
        echo "模块文件位置: $zip_file"
        rm -rf "$work_dir"
        echo "已清理工作目录: $work_dir"

        echo -n "是否立即刷入模块? [y/N]: "
        read install_choice
        case $install_choice in
            [Yy]*)
                install_magisk_module "$zip_file"
                ;;
            *)
                echo "模块文件已保存为: $zip_file"
                echo "请手动刷入模块"
                ;;
        esac
    else
        echo "压缩失败"
        cd "$current_dir"
    fi
}

# 功能2：修改 /system 分区下的文件
# 原理：通过 Magisk 模块的 system/ 目录进行文件替换
create_system_file_module() {
    local current_dir=$(pwd)
    local timestamp=$(get_timestamp)

    echo "请输入要修改的/system文件路径（例如：/system/etc/hosts）:"
    read system_file_path

    # 校验路径格式：必须以 /system/ 开头，且不是目录
    if ! echo "$system_file_path" | grep -q "^/system/" || echo "$system_file_path" | grep -q "/$"; then
        echo "错误: 路径必须以/system/开头且不能是文件夹"
        return 1
    fi

    system_dir=$(dirname "$system_file_path")
    file_name=$(basename "$system_file_path")

    if [ -z "$file_name" ]; then
        echo "错误: 要修改的只能是文件，不能是文件夹"
        return 1
    fi

    # 去掉 /system/ 前缀，得到模块内的相对路径
    module_dir=$(echo "$system_dir" | sed 's|^/system/||')

    echo "请输入已修改好的文件路径:"
    read modified_file_path

    if [ ! -f "$modified_file_path" ]; then
        echo "错误: 文件不存在: $modified_file_path"
        return 1
    fi

    module_id="system_file_${file_name}_${timestamp}"
    zip_name="MagiskModuleFactory_system_${file_name}_${timestamp}.zip"
    work_dir="system_file_module_${file_name}_${timestamp}"

    create_common_module "$work_dir" "$module_id" "修改${system_file_path}" "修改系统文件 - MagiskModuleFactory"

    mkdir -p "system/$module_dir"
    cp "$modified_file_path" "system/$module_dir/$file_name"
    echo "已复制文件到模块目录: system/$module_dir/$file_name"

    echo "正在压缩为ZIP文件..."
    cd "$work_dir"
    zip_file="${current_dir}/${zip_name}"
    zip -r "$zip_file" ./* > /dev/null 2>&1
    cd "$current_dir"

    if [ -f "$zip_file" ]; then
        echo "模块文件位置: $zip_file"
        rm -rf "$work_dir"
        echo -n "是否立即刷入模块? [y/N]: "
        read install_choice
        case $install_choice in
            [Yy]*)
                install_magisk_module "$zip_file"
                ;;
            *)
                echo "模块文件已保存为: $zip_file"
                echo "请手动刷入模块"
                ;;
        esac
    else
        echo "压缩失败"
        cd "$current_dir"
    fi
}

# 功能3：修改 /vendor 分区下的文件
# 注意：Magisk 模块中的 vendor 文件需要放在 system/vendor/ 目录下
create_vendor_file_module() {
    local current_dir=$(pwd)
    local timestamp=$(get_timestamp)

    echo "请输入要修改的/vendor文件路径（例如：/vendor/etc/audio_effects.conf）:"
    read vendor_file_path

    if ! echo "$vendor_file_path" | grep -q "^/vendor/" || echo "$vendor_file_path" | grep -q "/$"; then
        echo "错误: 路径必须以/vendor/开头且不能是文件夹"
        return 1
    fi

    vendor_dir=$(dirname "$vendor_file_path")
    file_name=$(basename "$vendor_file_path")

    if [ -z "$file_name" ]; then
        echo "错误: 要修改的只能是文件，不能是文件夹"
        return 1
    fi

    # 将 /vendor/xxx 转换为 vendor/xxx，因为 Magisk 模块的 vendor 覆盖路径是 system/vendor/
    module_dir=$(echo "$vendor_dir" | sed 's|^/vendor/|vendor/|')

    echo "请输入已修改好的文件路径:"
    read modified_file_path

    if [ ! -f "$modified_file_path" ]; then
        echo "错误: 文件不存在: $modified_file_path"
        return 1
    fi

    module_id="vendor_file_${file_name}_${timestamp}"
    zip_name="MagiskModuleFactory_vendor_${file_name}_${timestamp}.zip"
    work_dir="vendor_file_module_${file_name}_${timestamp}"

    create_common_module "$work_dir" "$module_id" "修改${vendor_file_path}" "修改vendor文件 - MagiskModuleFactory"

    mkdir -p "system/$module_dir"
    cp "$modified_file_path" "system/$module_dir/$file_name"
    echo "已复制文件到模块目录: system/$module_dir/$file_name"

    echo "正在压缩为ZIP文件..."
    cd "$work_dir"
    zip_file="${current_dir}/${zip_name}"
    zip -r "$zip_file" ./* > /dev/null 2>&1
    cd "$current_dir"

    if [ -f "$zip_file" ]; then
        echo "模块文件位置: $zip_file"
        rm -rf "$work_dir"
        echo -n "是否立即刷入模块? [y/N]: "
        read install_choice
        case $install_choice in
            [Yy]*)
                install_magisk_module "$zip_file"
                ;;
            *)
                echo "模块文件已保存为: $zip_file"
                echo "请手动刷入模块"
                ;;
        esac
    else
        echo "压缩失败"
        cd "$current_dir"
    fi
}

# 功能4：修改系统属性（支持多行输入，格式：属性=数值）
# 原理：在模块根目录创建 system.prop 文件，Magisk 会自动加载其中的属性覆盖
create_system_prop_module() {
    local current_dir=$(pwd)
    local timestamp=$(get_timestamp)

    echo "修改系统属性模块"
    echo "请输入要修改的系统属性，格式：属性名=数值"
    echo "每行一个属性，输入空行结束"
    echo "示例:"
    echo "  ro.debuggable=1"
    echo "  persist.sys.usb.config=mtp,adb"
    echo "开始输入:"

    local prop_lines=""
    local line
    while true; do
        read -r line
        if [ -z "$line" ]; then
            break
        fi
        # 验证格式：必须包含等号，且等号前后不能为空
        if echo "$line" | grep -q "=" && [ -n "$(echo "$line" | cut -d= -f1)" ] && [ -n "$(echo "$line" | cut -d= -f2-)" ]; then
            prop_lines="${prop_lines}${line}\n"
        else
            echo "警告: 跳过无效行 '$line'，格式应为 属性=数值"
        fi
    done

    if [ -z "$prop_lines" ]; then
        echo "错误: 未输入任何有效的属性"
        return 1
    fi

    # 生成模块ID，使用时间戳保证唯一性
    module_id="system_prop_${timestamp}"
    zip_name="MagiskModuleFactory_prop_${timestamp}.zip"
    work_dir="system_prop_module_${timestamp}"

    create_common_module "$work_dir" "$module_id" "修改系统属性 (${timestamp})" "批量修改系统属性 - MagiskModuleFactory"

    # 写入 system.prop，Magisk 会自动加载
    printf "%b" "$prop_lines" > system.prop
    echo "已创建 system.prop 文件，包含以下属性:"
    echo "----------------------------------------"
    printf "%b" "$prop_lines"
    echo "----------------------------------------"

    echo "正在压缩模块为ZIP文件..."
    cd "$work_dir"
    zip_file="${current_dir}/${zip_name}"
    zip -r "$zip_file" ./* > /dev/null 2>&1
    cd "$current_dir"

    if [ -f "$zip_file" ]; then
        echo "模块文件位置: $zip_file"
        rm -rf "$work_dir"
        echo -n "是否立即刷入模块? [y/N]: "
        read install_choice
        case $install_choice in
            [Yy]*)
                install_magisk_module "$zip_file"
                ;;
            *)
                echo "模块文件已保存为: $zip_file"
                echo "请手动刷入模块"
                ;;
        esac
    else
        echo "压缩失败"
        cd "$current_dir"
    fi
}

# 功能5：开机动画模块
# 支持两种输入：MP4 视频（通过 ffmpeg 提取帧转换为 bootanimation.zip）或直接使用现成的 zip
create_advanced_bootanimation_module() {
    local current_dir=$(pwd)
    local timestamp=$(get_timestamp)
    local work_dir="advanced_bootanimation_module_${timestamp}"

    echo "开机动画模块生成"
    echo "支持: 1) MP4视频自动转动画  2) 已有bootanimation.zip"
    echo ""
    echo "请选择动画来源:"
    echo "1) 使用MP4视频文件 (需ffmpeg)"
    echo "2) 使用现成的bootanimation.zip"
    echo -n "请选择 [1-2]: "
    read anim_source

    case $anim_source in
        1)
            if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
                echo "错误: 需要安装 ffmpeg 和 ffprobe 来转换MP4"
                return 1
            fi
            ;;
        2)
            ;;
        *)
            echo "无效选择"
            return 1
            ;;
    esac

    local temp_anim_dir=$(mktemp -d)
    local final_bootanim_zip="${temp_anim_dir}/bootanimation.zip"

    case $anim_source in
        1)
            echo -n "请输入MP4文件路径: "
            read mp4_file
            if [ ! -f "$mp4_file" ]; then
                echo "错误: 文件不存在"
                rm -rf "$temp_anim_dir"
                return 1
            fi

            # 使用 ffprobe 获取视频原始分辨率
            local width height
            width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$mp4_file")
            height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$mp4_file")
            if [ -z "$width" ] || [ -z "$height" ]; then
                echo "错误: 无法获取视频分辨率"
                rm -rf "$temp_anim_dir"
                return 1
            fi
            echo "视频分辨率: ${width}x${height}"

            echo -n "请输入目标帧率 (默认24, 建议15-30): "
            read fps_target
            fps_target=${fps_target:-24}

            echo "正在提取视频帧，可能需要一段时间..."
            local frame_dir="${temp_anim_dir}/part0"
            mkdir -p "$frame_dir"
            # ffmpeg 按指定帧率提取 PNG 帧，-start_number 0 使文件名从 0000.png 开始
            ffmpeg -i "$mp4_file" -vf "fps=$fps_target" -start_number 0 \
                "$frame_dir/%04d.png" -hide_banner -loglevel error

            local frame_count=$(ls -1 "$frame_dir"/*.png 2>/dev/null | wc -l)
            if [ $frame_count -eq 0 ]; then
                echo "错误: 未提取到任何帧"
                rm -rf "$temp_anim_dir"
                return 1
            fi
            echo "成功提取 $frame_count 帧"

            # desc.txt 是 bootanimation 的描述文件，格式：宽 高 帧率
            cat > "${temp_anim_dir}/desc.txt" << EOF
${width} ${height} ${fps_target}
p 0 0 part0
EOF
            cd "$temp_anim_dir"
            # -0qr 表示存储级压缩（无压缩），这是 bootanimation.zip 的要求
            zip -0qr "$final_bootanim_zip" desc.txt part0
            cd "$current_dir"
            echo "动画包已生成"
            ;;
        2)
            echo -n "请输入已有的 bootanimation.zip 文件路径: "
            read zip_file
            if [ ! -f "$zip_file" ]; then
                echo "错误: 文件不存在"
                rm -rf "$temp_anim_dir"
                return 1
            fi
            cp "$zip_file" "$final_bootanim_zip"
            echo "已复制动画包"
            ;;
    esac

    # 验证生成的 zip 文件完整性
    if ! unzip -tq "$final_bootanim_zip" >/dev/null 2>&1; then
        echo "错误: 动画包无效或损坏"
        rm -rf "$temp_anim_dir"
        return 1
    fi

    module_id="advanced_bootanimation_${timestamp}"
    zip_name="MagiskModuleFactory_bootanimation_${timestamp}.zip"

    create_common_module "$work_dir" "$module_id" "自定义开机动画" "自定义开机动画 - MagiskModuleFactory"

    # Android 10+ 开机动画路径为 /system/product/media/bootanimation.zip
    mkdir -p "system/product/media"
    cp "$final_bootanim_zip" "system/product/media/bootanimation.zip"
    echo "已添加开机动画到模块: system/product/media/bootanimation.zip"

    rm -rf "$temp_anim_dir"

    echo "正在压缩模块为ZIP文件..."
    cd "$work_dir"
    zip_file="${current_dir}/${zip_name}"
    zip -r "$zip_file" ./* > /dev/null 2>&1
    cd "$current_dir"

    if [ -f "$zip_file" ]; then
        echo "模块文件位置: $zip_file"
        rm -rf "$work_dir"
        echo -n "是否立即刷入模块? [y/N]: "
        read install_choice
        case $install_choice in
            [Yy]*)
                install_magisk_module "$zip_file"
                ;;
            *)
                echo "模块文件已保存为: $zip_file"
                echo "请手动刷入模块"
                ;;
        esac
    else
        echo "压缩失败"
        cd "$current_dir"
        return 1
    fi
}

# 功能6：修改机型信息
# 通过 system.prop 覆盖 ro.product.brand、ro.product.manufacturer、ro.product.model
create_device_model_module() {
    local current_dir=$(pwd)
    local timestamp=$(get_timestamp)

    echo "修改机型模块"
    echo "注意: 修改机型可能会影响部分应用和系统功能"
    echo ""

    echo "请输入品牌 (ro.product.brand):"
    read product_brand

    echo "请输入制造商 (ro.product.manufacturer):"
    read product_manufacturer

    echo "请输入型号 (ro.product.model):"
    read product_model

    if [ -z "$product_brand" ] || [ -z "$product_manufacturer" ] || [ -z "$product_model" ]; then
        echo "错误: 所有字段都不能为空"
        return 1
    fi

    echo ""
    echo "请确认输入的机型信息:"
    echo "品牌: $product_brand"
    echo "制造商: $product_manufacturer"
    echo "型号: $product_model"
    echo -n "是否继续? [y/N]: "
    read confirm

    case $confirm in
        [Yy]*)
            ;;
        *)
            echo "已取消"
            return 0
            ;;
    esac

    module_id="device_model_${timestamp}"
    zip_name="MagiskModuleFactory_devicemodel_${timestamp}.zip"
    work_dir="device_model_module_${timestamp}"

    create_common_module "$work_dir" "$module_id" "机型修改: $product_model" "修改设备机型 - MagiskModuleFactory"
    cat > system.prop << EOF
ro.product.brand=$product_brand
ro.product.manufacturer=$product_manufacturer
ro.product.model=$product_model
EOF

    echo "已创建system.prop文件，内容:"
    cat system.prop
    echo ""

    echo "正在压缩为ZIP文件..."
    cd "$work_dir"
    zip_file="${current_dir}/${zip_name}"
    zip -r "$zip_file" ./* > /dev/null 2>&1
    cd "$current_dir"

    if [ -f "$zip_file" ]; then
        echo "模块文件位置: $zip_file"
        rm -rf "$work_dir"
        echo -n "是否立即刷入模块? [y/N]: "
        read install_choice
        case $install_choice in
            [Yy]*)
                install_magisk_module "$zip_file"
                ;;
            *)
                echo "模块文件已保存为: $zip_file"
                echo "请手动刷入模块"
                ;;
        esac
    else
        echo "压缩失败"
        cd "$current_dir"
    fi
}

# 功能7：自定义 hosts 文件模块
# 合并系统原有有效规则（跳过注释）和用户提供的规则，去除非注释行
create_hosts_module() {
    local current_dir=$(pwd)
    local timestamp=$(get_timestamp)

    echo "自定义hosts文件模块"
    echo "hosts文件将放置在 /system/etc/hosts，用于广告屏蔽或域名自定义"
    echo "注意：将保留系统原hosts中的有效规则（跳过注释行），不足两行时自动补充标准回环条目"
    echo ""
    echo "请选择hosts来源:"
    echo "1) 使用本地的hosts文件"
    echo "2) 从网络URL下载hosts (需curl或wget)"
    echo "3) 手动输入hosts内容 (逐行输入，空行结束)"
    echo -n "请选择 [1-3]: "
    read hosts_source

    local temp_hosts=$(mktemp)
    local custom_content=$(mktemp)

    local original_hosts="/system/etc/hosts"
    local valid_lines=0
    if [ -f "$original_hosts" ]; then
        # 读取系统 hosts，跳过空行和以 # 开头的注释行，只取前两条有效规则
        while IFS= read -r line && [ $valid_lines -lt 2 ]; do
            case "$line" in
                ""|"#"*)
                    continue
                    ;;
                *)
                    echo "$line" >> "$temp_hosts"
                    valid_lines=$((valid_lines + 1))
                    ;;
            esac
        done < "$original_hosts"
        echo "已读取系统hosts中的有效规则（跳过注释）"
    fi

    # 确保至少保留 IPv4 和 IPv6 回环条目
    if [ $valid_lines -lt 1 ]; then
        echo "127.0.0.1 localhost" >> "$temp_hosts"
        valid_lines=1
    fi
    if [ $valid_lines -lt 2 ]; then
        echo "::1 ip6-localhost" >> "$temp_hosts"
    fi

    # 根据用户选择获取自定义 hosts 内容
    case $hosts_source in
        1)
            echo -n "请输入本地hosts文件路径: "
            read local_hosts
            if [ ! -f "$local_hosts" ]; then
                echo "错误: 文件不存在"
                rm -f "$temp_hosts" "$custom_content"
                return 1
            fi
            cp "$local_hosts" "$custom_content"
            echo "已复制本地hosts文件"
            ;;
        2)
            echo -n "请输入hosts文件的完整下载URL: "
            read url
            if command -v curl >/dev/null 2>&1; then
                curl -L -o "$custom_content" "$url"
            elif command -v wget >/dev/null 2>&1; then
                wget -O "$custom_content" "$url"
            else
                echo "错误: 未找到curl或wget，无法下载"
                rm -f "$temp_hosts" "$custom_content"
                return 1
            fi
            if [ $? -ne 0 ] || [ ! -s "$custom_content" ]; then
                echo "错误: 下载失败或文件为空"
                rm -f "$temp_hosts" "$custom_content"
                return 1
            fi
            echo "下载成功"
            ;;
        3)
            echo "请输入hosts内容，每行一条规则，输入空行结束:"
            echo "示例: 127.0.0.1 localhost"
            echo "开始输入:"
            local line
            while true; do
                read -r line
                if [ -z "$line" ]; then
                    break
                fi
                echo "$line" >> "$custom_content"
            done
            if [ ! -s "$custom_content" ]; then
                echo "错误: 未输入任何内容"
                rm -f "$temp_hosts" "$custom_content"
                return 1
            fi
            echo "已接收 $(wc -l < "$custom_content") 行规则"
            ;;
        *)
            echo "无效选择"
            rm -f "$temp_hosts" "$custom_content"
            return 1
            ;;
    esac

    # 合并系统有效规则和用户自定义内容
    cat "$custom_content" >> "$temp_hosts"
    rm -f "$custom_content"

    module_id="custom_hosts_${timestamp}"
    zip_name="MagiskModuleFactory_hosts_${timestamp}.zip"
    work_dir="custom_hosts_module_${timestamp}"

    create_common_module "$work_dir" "$module_id" "自定义hosts文件" "自定义系统hosts（无注释）- MagiskModuleFactory"

    mkdir -p "system/etc"
    cp "$temp_hosts" "system/etc/hosts"
    rm -f "$temp_hosts"
    echo "已合并hosts文件到模块: system/etc/hosts（已去除注释）"

    echo "正在压缩模块为ZIP文件..."
    cd "$work_dir"
    zip_file="${current_dir}/${zip_name}"
    zip -r "$zip_file" ./* > /dev/null 2>&1
    cd "$current_dir"

    if [ -f "$zip_file" ]; then
        echo "模块文件位置: $zip_file"
        rm -rf "$work_dir"
        echo -n "是否立即刷入模块? [y/N]: "
        read install_choice
        case $install_choice in
            [Yy]*)
                install_magisk_module "$zip_file"
                ;;
            *)
                echo "模块文件已保存为: $zip_file"
                echo "请手动刷入模块"
                ;;
        esac
    else
        echo "压缩失败"
        cd "$current_dir"
        return 1
    fi
}

# 功能8：开机自启脚本模块
# 生成 post-fs-data.sh（早期执行）或 service.sh（后台执行），在开机时以 root 权限执行用户命令
create_startup_script_module() {
    local current_dir=$(pwd)
    local timestamp=$(get_timestamp)

    echo "开机自启脚本模块"
    echo "生成 Magisk 模块，在开机时自动以 root 权限执行自定义命令"
    echo ""
    echo "请选择脚本执行时机:"
    echo "1) post-fs-data.sh (开机早期，文件系统挂载后)"
    echo "2) service.sh (后台服务模式，较晚执行)"
    echo -n "请选择 [1-2]: "
    read script_type

    case $script_type in
        1) script_name="post-fs-data.sh" ;;
        2) script_name="service.sh" ;;
        *) echo "无效选择"; return 1 ;;
    esac

    echo "请输入要执行的命令（每行一条命令，输入空行结束）:"
    echo "示例: echo 'hello' > /data/local/tmp/test.log"
    echo "开始输入:"

    local cmd_lines=""
    local line
    while true; do
        read -r line
        if [ -z "$line" ]; then
            break
        fi
        cmd_lines="${cmd_lines}${line}\n"
    done

    if [ -z "$cmd_lines" ]; then
        echo "错误: 未输入任何命令"
        return 1
    fi

    module_id="startup_script_${timestamp}"
    zip_name="MagiskModuleFactory_startup_${timestamp}.zip"
    work_dir="startup_script_module_${timestamp}"

    create_common_module "$work_dir" "$module_id" "开机自启脚本" "自定义开机执行命令 - MagiskModuleFactory"

    # 写入脚本，需要 shebang 以正确执行
    cat > "$script_name" << EOF
#!/system/bin/sh
$cmd_lines
EOF

    chmod 0755 "$script_name"
    echo "已创建脚本文件: $script_name"

    echo "正在压缩模块为ZIP文件..."
    cd "$work_dir"
    zip_file="${current_dir}/${zip_name}"
    zip -r "$zip_file" ./* > /dev/null 2>&1
    cd "$current_dir"

    if [ -f "$zip_file" ]; then
        echo "模块文件位置: $zip_file"
        rm -rf "$work_dir"
        echo -n "是否立即刷入模块? [y/N]: "
        read install_choice
        case $install_choice in
            [Yy]*)
                install_magisk_module "$zip_file"
                ;;
            *)
                echo "模块文件已保存为: $zip_file"
                echo "请手动刷入模块"
                ;;
        esac
    else
        echo "压缩失败"
        cd "$current_dir"
        return 1
    fi
}

# 功能9：隐藏 Magisk 模块
# 用户提供目标模块的 ZIP 文件，从中提取模块 ID，生成 helper 模块
# helper 模块的 service.sh 仅包含一行 rm -f /data/adb/modules/<id>/module.prop
# 开机执行后目标模块的 module.prop 被删除，Magisk 将忽略该模块（实现隐藏）
create_hide_module() {
    local current_dir=$(pwd)
    local timestamp=$(get_timestamp)

    echo "隐藏 Magisk 模块"
    echo "请输入已安装的 Magisk 模块的 ZIP 文件路径（即当初刷入的模块包）"
    echo "脚本将从 ZIP 中读取模块 ID，并生成一个助手模块，其 service.sh 仅包含一行删除命令："
    echo "rm -f /data/adb/modules/<模块ID>/module.prop"
    echo ""
    echo -n "请输入模块 ZIP 文件路径: "
    read zip_input

    if [ ! -f "$zip_input" ]; then
        echo "错误: 文件不存在: $zip_input"
        return 1
    fi

    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # 从用户提供的 ZIP 中提取 module.prop
    if ! unzip -q "$zip_input" module.prop 2>/dev/null; then
        echo "错误: 无法从 ZIP 中提取 module.prop，请确认这是一个有效的 Magisk 模块包"
        cd "$current_dir"
        rm -rf "$temp_dir"
        return 1
    fi

    if [ ! -f "module.prop" ]; then
        echo "错误: ZIP 中未找到 module.prop 文件"
        cd "$current_dir"
        rm -rf "$temp_dir"
        return 1
    fi

    # 解析 module.prop 中的 id= 字段，去除可能的空格
    local target_module_id=$(grep "^id=" module.prop | head -1 | cut -d= -f2- | tr -d ' ')
    if [ -z "$target_module_id" ]; then
        echo "错误: 无法从 module.prop 中读取 id="
        cd "$current_dir"
        rm -rf "$temp_dir"
        return 1
    fi

    local target_module_name=$(grep "^name=" module.prop | head -1 | cut -d= -f2-)
    if [ -z "$target_module_name" ]; then
        target_module_name="$target_module_id"
    fi

    cd "$current_dir"
    rm -rf "$temp_dir"

    local target_path="/data/adb/modules/$target_module_id"

    echo ""
    echo "目标模块 ID: $target_module_id"
    echo "目标模块名称: $target_module_name"
    echo "目标路径: $target_path"
    echo ""
    echo -n "确认继续? [y/N]: "
    read confirm
    case $confirm in
        [Yy]*)
            ;;
        *)
            echo "已取消"
            return 0
            ;;
    esac

    helper_id="hide_helper_${timestamp}"
    zip_name="MagiskModuleFactory_hidehelper_${timestamp}.zip"
    work_dir="hide_module_helper_${timestamp}"

    create_common_module "$work_dir" "$helper_id" "隐藏模块助手 ($target_module_name)" "开机时删除目标模块的 module.prop"
    cat > service.sh << EOF
rm -f $target_path/module.prop
EOF
    chmod 0755 service.sh

    echo "已创建 service.sh"

    echo "正在压缩模块为ZIP文件..."
    cd "$work_dir"
    zip_file="${current_dir}/${zip_name}"
    zip -r "$zip_file" ./* > /dev/null 2>&1
    cd "$current_dir"

    if [ -f "$zip_file" ]; then
        echo "模块文件位置: $zip_file"
        rm -rf "$work_dir"
        echo -n "是否立即刷入模块? [y/N]: "
        read install_choice
        case $install_choice in
            [Yy]*)
                install_magisk_module "$zip_file"
                ;;
            *)
                echo "模块文件已保存为: $zip_file"
                echo "请手动刷入模块，重启后目标模块将被隐藏"
                ;;
        esac
    else
        echo "压缩失败"
        cd "$current_dir"
        return 1
    fi
}

# 主菜单循环
while true; do
    show_menu
    read choice

    case $choice in
        1)
            get_apps
            echo -n "选择应用 (输入序号): "
            read app_choice

            selected_package=$(pm list packages -3 | cut -d: -f2 | sed -n "${app_choice}p")

            if [ -n "$selected_package" ]; then
                create_module_structure "$selected_package"
            else
                echo "无效选择"
            fi
            ;;
        2)
            create_system_file_module
            ;;
        3)
            create_vendor_file_module
            ;;
        4)
            create_system_prop_module
            ;;
        5)
            create_advanced_bootanimation_module
            ;;
        6)
            create_device_model_module
            ;;
        7)
            create_hosts_module
            ;;
        8)
            create_startup_script_module
            ;;
        9)
            create_hide_module
            ;;
        10)
            exit 0
            ;;
        *)
            echo "无效选择"
            ;;
    esac
done