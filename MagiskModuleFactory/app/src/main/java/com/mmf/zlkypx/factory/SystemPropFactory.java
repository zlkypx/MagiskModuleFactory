package com.mmf.zlkypx.factory;

import android.content.Context;
import com.mmf.zlkypx.util.MagiskModuleUtils;

import java.io.*;

/**
 * 功能4：生成修改系统属性模块工厂
 */
public class SystemPropFactory {

    /**
     * 创建系统属性修改模块
     * @param propLines 属性行数组，格式如 "ro.debuggable=1"
     */
    public static File createModule(Context context, String[] propLines, File outputDir) throws Exception {
        String timestamp = MagiskModuleUtils.getTimestamp();
        String moduleId = "system_prop_" + timestamp;
        String zipName = "MagiskModuleFactory_prop_" + timestamp + ".zip";
        File workDir = new File(context.getCacheDir(), "system_prop_module_" + timestamp);

        MagiskModuleUtils.createCommonModule(workDir, moduleId,
                "修改系统属性 (" + timestamp + ")",
                "批量修改系统属性 - MagiskModuleFactory");

        // 创建 system.prop 文件
        StringBuilder sb = new StringBuilder();
        for (String line : propLines) {
            if (line != null && line.contains("=")) {
                sb.append(line.trim()).append("\n");
            }
        }
        MagiskModuleUtils.createSystemProp(workDir, sb.toString());

        return createZip(workDir, outputDir, zipName);
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
