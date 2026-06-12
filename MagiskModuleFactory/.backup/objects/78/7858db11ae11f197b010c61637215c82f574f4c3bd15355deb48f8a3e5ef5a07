package com.mmf.zlkypx.util;

import java.io.*;

/**
 * Magisk 模块安装工具
 * 通过root权限执行安装命令
 */
public class ModuleInstaller {

    /**
     * 安装Magisk模块ZIP文件
     * @return 操作是否成功
     */
    public static boolean installModule(File moduleZip) {
        if (!moduleZip.exists()) {
            return false;
        }

        String[] commands = {
                "if [ -f /data/adb/ksud ]; then",
                "  /data/adb/ksud module install " + moduleZip.getAbsolutePath(),
                "elif [ -f /data/adb/apd ]; then",
                "  /data/adb/apd module install " + moduleZip.getAbsolutePath(),
                "elif command -v magisk >/dev/null 2>&1; then",
                "  magisk --install-module " + moduleZip.getAbsolutePath(),
                "else",
                "  echo 'ERROR: No install method found'",
                "  exit 1",
                "fi"
        };

        StringBuilder sb = new StringBuilder();
        for (String cmd : commands) {
            sb.append(cmd).append("\n");
        }

        return executeAsRoot(sb.toString());
    }

    /**
     * 以root权限执行命令
     */
    private static boolean executeAsRoot(String command) {
        Process process = null;
        BufferedReader reader = null;
        try {
            process = Runtime.getRuntime().exec(new String[]{"su", "-c", command});
            reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line;
            while ((line = reader.readLine()) != null) {
                // 可以记录日志
            }
            int exitCode = process.waitFor();
            return exitCode == 0;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        } finally {
            if (reader != null) try { reader.close(); } catch (IOException ignored) {}
            if (process != null) process.destroy();
        }
    }

    /**
     * 检查是否有root权限
     */
    public static boolean hasRootAccess() {
        return executeAsRoot("exit 0");
    }
}
