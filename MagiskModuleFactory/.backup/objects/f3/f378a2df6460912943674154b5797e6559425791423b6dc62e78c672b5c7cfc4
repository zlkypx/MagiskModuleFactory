package com.mmf.zlkypx.factory;

import android.content.Context;
import com.mmf.zlkypx.util.MagiskModuleUtils;

import java.io.*;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 功能10：基于 lxgw 模板生成字体替换模块工厂
 * 字重映射: 1=Thin, 2=ExtraLight, 3=Light, 4=Regular, 5=Medium,
 *           6=SemiBold, 7=Bold, 8=ExtraBold, 9=Black
 */
public class FontModuleFactory {

    public static final Map<Integer, String> WEIGHT_NAMES = new LinkedHashMap<>();

    static {
        WEIGHT_NAMES.put(1, "Thin");
        WEIGHT_NAMES.put(2, "ExtraLight");
        WEIGHT_NAMES.put(3, "Light");
        WEIGHT_NAMES.put(4, "Regular");
        WEIGHT_NAMES.put(5, "Medium");
        WEIGHT_NAMES.put(6, "SemiBold");
        WEIGHT_NAMES.put(7, "Bold");
        WEIGHT_NAMES.put(8, "ExtraBold");
        WEIGHT_NAMES.put(9, "Black");
    }

    /**
     * 创建字体替换模块
     * @param weightFontMap 键=字重编号(1-9)，值=字体文件路径
     */
    public static File createModule(Context context, Map<Integer, File> weightFontMap, File outputDir) throws Exception {
        String timestamp = MagiskModuleUtils.getTimestamp();
        String moduleId = "my_font_" + timestamp;
        String zipName = "MagiskModuleFactory_font_" + timestamp + ".zip";
        File workDir = new File(context.getCacheDir(), "font_builder_" + timestamp);

        // 构建模板目录结构（不依赖git clone，直接内建）
        createFontTemplate(workDir, moduleId);

        // 复制字体文件
        File fontsDir = new File(workDir, "system/fonts");
        for (Map.Entry<Integer, File> entry : weightFontMap.entrySet()) {
            int weight = entry.getKey();
            File fontFile = entry.getValue();
            String ext = getFileExtension(fontFile.getName());
            String targetName = "fontw" + weight + "." + ext;
            copyFile(fontFile, new File(fontsDir, targetName));
        }

        return createZip(workDir, outputDir, zipName);
    }

    private static void createFontTemplate(File workDir, String moduleId) throws IOException {
        // META-INF
        File metaInfDir = new File(workDir, "META-INF/com/google/android");
        metaInfDir.mkdirs();

        // update-binary
        try (PrintWriter pw = new PrintWriter(new FileWriter(new File(metaInfDir, "update-binary")))) {
            pw.println("#!/sbin/sh");
            pw.println("umask 022");
            pw.println("ui_print() { echo \"$1\"; }");
            pw.println("require_new_magisk() {");
            pw.println("  ui_print \"*******************************\"");
            pw.println("  ui_print \" Please install Magisk v20.4+! \"");
            pw.println("  ui_print \"*******************************\"");
            pw.println("  exit 1");
            pw.println("}");
            pw.println("OUTFD=$2");
            pw.println("ZIPFILE=$3");
            pw.println("mount /data 2>/dev/null");
            pw.println("[ -f /data/adb/magisk/util_functions.sh ] || require_new_magisk");
            pw.println(". /data/adb/magisk/util_functions.sh");
            pw.println("[ $MAGISK_VER_CODE -lt 20400 ] && require_new_magisk");
            pw.println("install_module");
            pw.println("exit 0");
        }
        new File(metaInfDir, "update-binary").setExecutable(true);

        // updater-script
        try (PrintWriter pw = new PrintWriter(new FileWriter(new File(metaInfDir, "updater-script")))) {
            pw.println("#MAGISK");
        }

        // module.prop
        try (PrintWriter pw = new PrintWriter(new FileWriter(new File(workDir, "module.prop")))) {
            pw.println("id=" + moduleId);
            pw.println("name=自定义字体");
            pw.println("version=1.0");
            pw.println("versionCode=1");
            pw.println("author=MagiskModuleFactory / github.com/zlkypx");
            pw.println("description=基于lxgw模板的自定义字体替换模块");
        }

        // system/fonts 目录
        new File(workDir, "system/fonts").mkdirs();
    }

    private static void copyFile(File source, File dest) throws IOException {
        try (FileInputStream fis = new FileInputStream(source);
             FileOutputStream fos = new FileOutputStream(dest)) {
            byte[] buf = new byte[8192];
            int len;
            while ((len = fis.read(buf)) > 0) {
                fos.write(buf, 0, len);
            }
        }
    }

    private static String getFileExtension(String filename) {
        int dot = filename.lastIndexOf('.');
        return (dot == -1) ? "ttf" : filename.substring(dot + 1);
    }

    private static File createZip(File workDir, File outputDir, String zipName) {
        File zipFile = new File(outputDir, zipName);
        MagiskModuleUtils.zipDirectory(workDir, zipFile);
        deleteRecursive(workDir);
        return zipFile.exists() ? zipFile : null;
    }

    private static void deleteRecursive(File file) {
        if (file.isDirectory()) {
            File[] children = file.listFiles();
            if (children != null) {
                for (File child : children) {
                    deleteRecursive(child);
                }
            }
        }
        file.delete();
    }
}
