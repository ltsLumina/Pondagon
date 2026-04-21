// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

using System.IO;
using UnrealBuildTool;

public class DiversionHttp : ModuleRules
{
	public DiversionHttp(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PrivateDependencyModuleNames.AddRange(
			new string[] {
			"Core",
			"Json",
			"OpenSSL",
			"Projects",
			"zlib",
			"Boost",
			"Slate",
			"Common",
        });

        PublicIncludePaths.Add(Path.Combine(ModuleDirectory, "..", "ThirdParty"));
    }
}