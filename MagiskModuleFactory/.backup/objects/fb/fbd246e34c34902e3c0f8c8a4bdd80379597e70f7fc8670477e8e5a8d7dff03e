package com.mmf.zlkypx.factory;

import android.content.Context;
import com.mmf.zlkypx.util.MagiskModuleUtils;

import java.io.*;

/**
 * 功能2/3：修改/system或/vendor文件模块工厂
 */
public class FileReplaceFactory {

    /**
     * 创建修改分区文件的模块
     * @param partition 分区名，如 "system"（对应 "/system"）或 "vendor"（对应 "/vendor"）
     */
    public static File createModule(Context context,
                                    String partition,
                                    String targetFilePath,
                                    File modifiedFile,
                                    File outputDir) throws Exception {
        String timestamp = MagiskModuleUtils.getTimestamp();
        String fileName = new File(targetFilePath).getName();

        // 确定 moduleDir（去掉分区前缀）
        String prefix = "/" + partition + "/";
        if (!targetFilePath.startsWith(prefix)) {
            throw new IllegalArgumentException("路径必须以 " + prefix + " 开头");
        }
        String moduleDir = targetFilePath.substring(prefix.length());
        moduleDir = new File(moduleDir).getParent(); // 取父目录
        if (moduleDir == null) moduleDir = "";

        String moduleId = partition + "_file_" + fileName + "_" + timestamp;
        String zipName = "MagiskModuleFactory_" + partition + "_" + fileName + "_" + timestamp + ".zip";
        String workDirName = partition + "_file_module_" + fileName + "_" + timestamp;
        File workDir = new File(context.getCacheDir(), workDirName);

        MagiskModuleUtils.createCommonModule(workDir, moduleId,
                "修改" + targetFilePath,
                "修改" + partition + "文件 - MagiskModuleFactory");

        // 创建目标目录并复制文件
        File targetDir = new File(workDir, "system/" + moduleDir);
        targetDir.mkdirs();
        copyFile(modifiedFile, new File(targetDir, fileName));

        return createZip(workDir, outputDir, zipName);
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
