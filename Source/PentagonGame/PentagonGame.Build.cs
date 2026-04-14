// Fill out your copyright notice in the Description page of Project Settings.

#region
using UnrealBuildTool;
#endregion

public class PentagonGame : ModuleRules
{
	public PentagonGame(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

		PublicDependencyModuleNames.AddRange(new[] { "Core", "CoreUObject", "Engine", "InputCore", "AngelscriptGAS" });

		PublicDependencyModuleNames.AddRange(new string[] { "GameplayAbilities", "GameplayTags", "GameplayTasks" });

		//PrivateDependencyModuleNames.AddRange(new string[] { });

		if (Target.bBuildEditor)
		{
			PrivateDependencyModuleNames.AddRange(new[] { "UnrealEd", "Kismet" });

			// Uncomment if you are using Slate UI
			PrivateDependencyModuleNames.AddRange(new[] { "Slate", "SlateCore" });
		}
		
		// Uncomment if you are using online features
		PrivateDependencyModuleNames.Add("OnlineSubsystem");

		// To include OnlineSubsystemSteam, add it to the plugins section in your uproject file with the Enabled attribute set to true
	}
}
