// Fill out your copyright notice in the Description page of Project Settings.

#region
using UnrealBuildTool;
#endregion

public class PentagonGameTarget : TargetRules
{
	public PentagonGameTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		DefaultBuildSettings = BuildSettingsVersion.V6;

		ExtraModuleNames.AddRange(new[] { "PentagonGame" });
	}
}
