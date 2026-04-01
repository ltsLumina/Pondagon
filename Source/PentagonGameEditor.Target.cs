// Fill out your copyright notice in the Description page of Project Settings.

#region
using UnrealBuildTool;
#endregion

public class PentagonGameEditorTarget : TargetRules
{
	public PentagonGameEditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		DefaultBuildSettings = BuildSettingsVersion.V6;

		ExtraModuleNames.AddRange(new[] { "PentagonGame" });
	}
}
