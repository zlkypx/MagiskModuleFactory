package com.mmf.zlkypx.util;

import java.io.*;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Magisk模块工具类 - 核心封装Shell脚本功能
 * github.com/zlkypx/MagiskModuleFactory
 */
public class MagiskModuleUtils {

    /**
     * 生成时间戳，格式如 20260606_143052
     */
    public static String getTimestamp() {
        return new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
    }

    /**
     * 创建通用模块结构
     */
    public static void createCommonModule(File workDir, String moduleId, String moduleName, String description) throws IOException {
        // META-INF 目录
        File metaInfDir = new File(workDir, "META-INF/com/google/android");
        if (!metaInfDir.mkdirs()) {
            throw new IOException("无法创建 META-INF 目录");
        }

        // update-binary
        File updateBinary = new File(metaInfDir, "update-binary");
        try (PrintWriter pw = new PrintWriter(new FileWriter(updateBinary))) {
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
        updateBinary.setExecutable(true);

        // updater-script
        File updaterScript = new File(metaInfDir, "updater-script");
        try (PrintWriter pw = new PrintWriter(new FileWriter(updaterScript))) {
            pw.println("#MAGISK");
        }

        // module.prop
        File moduleProp = new File(workDir, "module.prop");
        try (PrintWriter pw = new PrintWriter(new FileWriter(moduleProp))) {
            pw.println("id=" + moduleId);
            pw.println("name=" + moduleName);
            pw.println("version=1.0");
            pw.println("versionCode=1");
            pw.println("author=MagiskModuleFactory / github.com/zlkypx");
            pw.println("description=" + description);
        }
    }

    /**
     * 压缩目录为ZIP文件
     */
    public static boolean zipDirectory(File sourceDir, File outputZip) {
        try {
            java.util.zip.ZipOutputStream zos = new java.util.zip.ZipOutputStream(new FileOutputStream(outputZip));
            zipDirRecursive(sourceDir, "", zos);
            zos.close();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    private static void zipDirRecursive(File dir, String baseName, java.util.zip.ZipOutputStream zos) throws IOException {
        File[] files = dir.listFiles();
        if (files == null) return;
        byte[] buffer = new byte[8192];
        for (File file : files) {
            if (file.isDirectory()) {
                zipDirRecursive(file, baseName.isEmpty() ? file.getName() : baseName + "/" + file.getName(), zos);
            } else {
                java.util.zip.ZipEntry ze = new java.util.zip.ZipEntry(baseName.isEmpty() ? file.getName() : baseName + "/" + file.getName());
                zos.putNextEntry(ze);
                try (FileInputStream fis = new FileInputStream(file)) {
                    int len;
                    while ((len = fis.read(buffer)) > 0) {
                        zos.write(buffer, 0, len);
                    }
                }
                zos.closeEntry();
            }
        }
    }

    /**
     * 创建system.prop文件
     */
    public static void createSystemProp(File workDir, String propContent) throws IOException {
        File propFile = new File(workDir, "system.prop");
        try (PrintWriter pw = new PrintWriter(new FileWriter(propFile))) {
            pw.print(propContent);
        }
    }

    /**
     * 创建service.sh或post-fs-data.sh脚本
     */
    public static void createShellScript(File workDir, String scriptName, String scriptContent) throws IOException {
        File scriptFile = new File(workDir, scriptName);
        try (PrintWriter pw = new PrintWriter(new FileWriter(scriptFile))) {
            pw.println("#!/system/bin/sh");
            pw.print(scriptContent);
        }
        scriptFile.setExecutable(true);
    }
}