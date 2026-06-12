package com.mmf.zlkypx.factory;

import android.content.Context;
import com.mmf.zlkypx.util.MagiskModuleUtils;

import java.io.*;

/**
 * 功能7：自定义hosts文件模块工厂
 */
public class HostsFactory {

    /**
     * 创建自定义hosts模块
     * @param customContent 用户自定义的hosts内容
     */
    public static File createModule(Context context, String customContent, File outputDir) throws Exception {
        String timestamp = MagiskModuleUtils.getTimestamp();
        String moduleId = "custom_hosts_" + timestamp;
        String zipName = "MagiskModuleFactory_hosts_" + timestamp + ".zip";
        File workDir = new File(context.getCacheDir(), "custom_hosts_module_" + timestamp);

        MagiskModuleUtils.createCommonModule(workDir, moduleId,
                "自定义hosts文件",
                "自定义系统hosts（无注释）- MagiskModuleFactory");

        // 构建hosts内容：保留基本回环地址 + 用户内容
        StringBuilder hostsBuilder = new StringBuilder();
        hostsBuilder.append("127.0.0.1 localhost\n");
        hostsBuilder.append("::1 ip6-localhost\n");
        if (customContent != null) {
            hostsBuilder.append(customContent);
        }

        // 创建 system/etc/hosts
        File hostDir = new File(workDir, "system/etc");
        hostDir.mkdirs();
        try (PrintWriter pw = new PrintWriter(new FileWriter(new File(hostDir, "hosts")))) {
            pw.print(hostsBuilder.toString());
        }

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
