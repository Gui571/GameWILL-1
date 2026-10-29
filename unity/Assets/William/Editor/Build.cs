using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;
using System.IO;
public static class WilliamBuild {
    [MenuItem("William/Build Windows introduction")]
    public static void Windows() {
        Directory.CreateDirectory("Build/Windows");
        PlayerSettings.companyName="Gui571";PlayerSettings.productName="William — Limiar de Aurora";
        PlayerSettings.defaultScreenWidth=1280;PlayerSettings.defaultScreenHeight=720;
        var report=BuildPipeline.BuildPlayer(new BuildPlayerOptions {
            scenes=new[]{"Assets/William/Scenes/Introduction.unity"},
            locationPathName="Build/Windows/William.exe",target=BuildTarget.StandaloneWindows64,
            options=BuildOptions.None
        });
        if(report.summary.result!=BuildResult.Succeeded)throw new System.Exception("William build failed: "+report.summary.result);
        Debug.Log("William Windows build completed");
    }
}
