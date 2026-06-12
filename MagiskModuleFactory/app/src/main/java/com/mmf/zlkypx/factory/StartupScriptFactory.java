package com.mmf.zlkypx.factory;

import android.content.Context;
import com.mmf.zlkypx.util.MagiskModuleUtils;

import java.io.*;

/**
 * 功能8：开机自启脚本模块工厂
 */
public class StartupScriptFactory {

    public static final int SCRIPT_POST_FS_DATA = 1;
    public static final int SCRIPT_SERVICE = 2;

    public static File createModule(Context context, int scriptType, String scriptContent, File outputDir) throws Exception {
        String timestamp = MagiskModuleUtils.getTimestamp();
        String scriptName;

        switch (scriptType) {
            case SCRIPT_POST_FS_DATA:
                scriptName = "post-fs-data.sh";
                break;
            case SCRIPT_SERVICE:
                scriptName = "service.sh";
                break;
            default:
                throw new IllegalArgumentException("无效的脚本类型");
        }

        String moduleId = "startup_script_" + timestamp;
        String zipName = "MagiskModuleFactory_startup_" + timestamp + ".zip";
        File workDir = new File(context.getCacheDir(), "startup_script_module_" + timestamp);

        MagiskModuleUtils.createCommonModule(workDir, moduleId,
                "开机自启脚本",
                "自定义开机执行命令 - MagiskModuleFactory");

        MagiskModuleUtils.createShellScript(workDir, scriptName, scriptContent);

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
