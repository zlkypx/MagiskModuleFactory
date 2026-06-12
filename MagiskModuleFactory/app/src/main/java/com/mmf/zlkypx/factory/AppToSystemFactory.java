package com.mmf.zlkypx.factory;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import com.mmf.zlkypx.util.MagiskModuleUtils;

import java.io.*;
import java.util.ArrayList;
import java.util.List;

/**
 * 功能1：普通应用转系统应用模块工厂
 */
public class AppToSystemFactory {

    public static class AppInfo {
        public String packageName;
        public String appName;
        public String apkPath;

        public AppInfo(String packageName, String appName, String apkPath) {
            this.packageName = packageName;
            this.appName = appName;
            this.apkPath = apkPath;
        }

        @Override
        public String toString() {
            return appName + " (" + packageName + ")";
        }
    }

    /**
     * 获取第三方已安装应用列表
     */
    public static List<AppInfo> getInstalledApps(Context context) {
        List<AppInfo> apps = new ArrayList<>();
        PackageManager pm = context.getPackageManager();
        List<PackageInfo> packages = pm.getInstalledPackages(0);
        for (PackageInfo pi : packages) {
            if ((pi.applicationInfo.flags & ApplicationInfo.FLAG_SYSTEM) == 0) {
                String appName = pi.applicationInfo.loadLabel(pm).toString();
                String apkPath = pi.applicationInfo.sourceDir;
                apps.add(new AppInfo(pi.packageName, appName, apkPath));
            }
        }
        return apps;
    }

    /**
     * 创建应用转系统模块
     */
    public static File createModule(Context context, AppInfo appInfo, File outputDir) throws Exception {
        String timestamp = MagiskModuleUtils.getTimestamp();
        String moduleId = appInfo.packageName + "_" + timestamp;
        String zipName = "MagiskModuleFactory_" + appInfo.packageName + "_" + timestamp + ".zip";
        File workDir = new File(context.getCacheDir(), appInfo.packageName + "_module_" + timestamp);

        MagiskModuleUtils.createCommonModule(workDir, moduleId, appInfo.packageName, "固化系统应用 - MagiskModuleFactory");

        // 创建system/app目录
        File targetDir = new File(workDir, "system/app/" + appInfo.packageName);
        targetDir.mkdirs();

        // 复制APK
        File apkFile = new File(appInfo.apkPath);
        if (apkFile.exists()) {
            copyFile(apkFile, new File(targetDir, "base.apk"));

            // 提取lib文件
            File libDir = new File(targetDir, "lib");
            extractLibFromApk(apkFile, libDir);
        }

        return createZipAndCleanup(workDir, outputDir, zipName);
    }

    private static void extractLibFromApk(File apkFile, File targetLibDir) throws Exception {
        java.util.zip.ZipFile zip = new java.util.zip.ZipFile(apkFile);
        java.util.Enumeration<? extends java.util.zip.ZipEntry> entries = zip.entries();
        boolean hasLib = false;

        while (entries.hasMoreElements()) {
            java.util.zip.ZipEntry entry = entries.nextElement();
            if (entry.getName().startsWith("lib/") && !entry.isDirectory()) {
                hasLib = true;
                File outFile = new File(targetLibDir, entry.getName().substring(4)); // 去掉 "lib/" 前缀
                outFile.getParentFile().mkdirs();
                try (InputStream is = zip.getInputStream(entry);
                     FileOutputStream fos = new FileOutputStream(outFile)) {
                    byte[] buf = new byte[8192];
                    int len;
                    while ((len = is.read(buf)) > 0) {
                        fos.write(buf, 0, len);
                    }
                }
            }
        }
        zip.close();

        if (!hasLib) {
            targetLibDir.delete();
        }
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

    private static File createZipAndCleanup(File workDir, File outputDir, String zipName) {
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
