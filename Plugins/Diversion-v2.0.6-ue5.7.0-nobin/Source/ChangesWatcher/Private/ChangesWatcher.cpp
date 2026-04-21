// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#include "ChangesWatcher.h"

// Diversion includes
#include "ChangeBatcher.h"
#include "DiversionNotificationManager.h"

// UE includes
#include "IDirectoryWatcher.h"
#include "DirectoryWatcherModule.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "UObject/ObjectSaveContext.h"
#include "FileHelpers.h"
#include "Engine/Blueprint.h"
#include "Subsystems/AssetEditorSubsystem.h"

#define LOCTEXT_NAMESPACE "FChangesWatcherModule"

FChangesWatcher::FChangesWatcher()
{
	ContentDir = FPaths::ConvertRelativePathToFull(FPaths::ProjectContentDir());

	if (FModuleManager::Get().IsModuleLoaded("DirectoryWatcher"))
	{
		FDirectoryWatcherModule& DirectoryWatcherModule = FModuleManager::LoadModuleChecked<FDirectoryWatcherModule>("DirectoryWatcher");
		if (IDirectoryWatcher* DirectoryWatcher = DirectoryWatcherModule.Get()) {
			DirectoryWatcher->RegisterDirectoryChangedCallback_Handle(
				ContentDir,
				IDirectoryWatcher::FDirectoryChanged::CreateRaw(this, &FChangesWatcher::HandleDirectoryChanged),
				WatcherHandle,
				IDirectoryWatcher::WatchOptions::IncludeDirectoryChanges
			);
			UE_LOG(LogChangesWatcher, Log, TEXT("Watching content folder: %s"), *ContentDir);
		}
	}

	// Listen for UE's internal save to track files that were changed internally
	PostSaveHandle = UPackage::PackageSavedWithContextEvent.AddRaw(this, &FChangesWatcher::TrackInternallyChangedPackages);


	Batcher = MakeShared<FChangeBatcher>(
		SilenceSecondsBeforeAcceptBatch,
		FChangeBatcher::FOnBatchReady::CreateRaw(this, &FChangesWatcher::HandleChangesBatch)
	);
	NotificationManager = MakeUnique<FDiversionNotificationManager>();
}

FChangesWatcher::~FChangesWatcher()
{
	if (FModuleManager::Get().IsModuleLoaded("DirectoryWatcher"))
	{
		FDirectoryWatcherModule& DirectoryWatcherModule = FModuleManager::LoadModuleChecked<FDirectoryWatcherModule>("DirectoryWatcher");
		if (IDirectoryWatcher* DirectoryWatcher = DirectoryWatcherModule.Get()) {
			DirectoryWatcher->UnregisterDirectoryChangedCallback_Handle(ContentDir, WatcherHandle);
		}
	}

	UPackage::PackageSavedWithContextEvent.Remove(PostSaveHandle);
	StopSnooze();
}

void FChangesWatcher::HandleDirectoryChanged(const TArray<struct FFileChangeData>& FileChanges)
{
	const double Now = FPlatformTime::Seconds();
	for (const FFileChangeData& Change : FileChanges)
	{
		if (Change.Action != FFileChangeData::FCA_Added &&
			Change.Action != FFileChangeData::FCA_Modified)
		{
			continue;
		}

		const FString& File = Change.Filename;
		// Filter to only UE packages: .uasset or .umap
		const bool bIncludeDot = true;
		if (!FPackageName::IsPackageExtension(*FPaths::GetExtension(File, bIncludeDot)))
		{
			continue;
		}

		if (FSaveStamp* Stamp = EngineWriteMap.Find(File)) {
			const bool  WithinWindow = (Now - Stamp->LastHitTime) < QUIET_WINDOW_SEC;
			const int64 CurrentSize = IFileManager::Get().FileSize(*File);
			const bool  SizeUnchanged = CurrentSize == Stamp->SavedSize;

			if (WithinWindow && SizeUnchanged)
			{
				// Still part of UEs own burst -> ignore
				UE_LOG(LogChangesWatcher, VeryVerbose, TEXT("Ignoring %s - within quiet window (%.3fs ago, same size %lld)"), 
					*File, Now - Stamp->LastHitTime, CurrentSize);
				Stamp->LastHitTime = Now;   // extend window
				continue;
			}
			else if (WithinWindow)
			{
				UE_LOG(LogChangesWatcher, Verbose, TEXT("Processing %s - within window but size changed (%lld -> %lld)"), 
					*File, Stamp->SavedSize, CurrentSize);
			}
		}

		UE_LOG(LogChangesWatcher, Verbose, TEXT("Adding change to batch: %s (Action: %d, Size: %lld)"), 
			*Change.Filename, (int32)Change.Action, IFileManager::Get().FileSize(*Change.Filename));
		Batcher->AddChange(Change.Filename);
	}

	for (auto It = EngineWriteMap.CreateIterator(); It; ++It)
	{
		// Updtae the entries that track internal engine changes
		if (Now - It->Value.LastHitTime >= QUIET_WINDOW_SEC)
			It.RemoveCurrent();
	}
}

void FChangesWatcher::TrackInternallyChangedPackages(const FString& PackageFileName, UPackage*, FObjectPostSaveContext Context)
{
	if (Context.SaveSucceeded()) {
		FString PackageFilePath = FPaths::ConvertRelativePathToFull(PackageFileName);
		const int64 Size = IFileManager::Get().FileSize(*PackageFilePath);
		UE_LOG(LogChangesWatcher, Verbose, TEXT("Tracking internal save: %s (Size: %lld)"), 
			*PackageFilePath, Size);
		EngineWriteMap.FindOrAdd(PackageFilePath) = { FPlatformTime::Seconds(), Size };
	}
}

void FChangesWatcher::HandleChangesBatch(uint32 BatchId, const TSet<FString>& IncomingChanges)
{
	StopSnooze();
	// Filtering out packages that are the same in cache to avoid unnecessary reloads
	TSet<FString> PackagesToReload;

	Algo::CopyIf(IncomingChanges, PackagesToReload, [this](const FString& InChangeFileName) {
		return IsPakcageDifferentOnDisk(InChangeFileName);
	});

	// If no packages to reload after the copy - just resolve the batch and return
	if (PackagesToReload.Num() == 0)
	{
		Batcher->ResolveBatch(BatchId, EBatchDisposition::Accept);
		UE_LOG(LogChangesWatcher, Log, TEXT("No changes to reload in batch %d"), BatchId);
		return;
	}

	UE_LOG(LogChangesWatcher, Log, TEXT("Batch %d: %d incoming changes, %d filtered for reload"), 
		BatchId, IncomingChanges.Num(), PackagesToReload.Num());
	
	for (const FString& Package : PackagesToReload)
	{
		UE_LOG(LogChangesWatcher, Verbose, TEXT("Package marked for reload: %s"), *Package);
	}

	FNotificationButtonInfo ReloadButton(LOCTEXT("DiversionPopup_ReloadChangesButton", "Reload"),
		LOCTEXT("DiversionPopup_ReloadChangesButton_Tooltip", 
			"Reload assets from disk, to get updates from teammates." 
			"This ensures that any future modifications you make are on top of your teammate's changes, to prevent conflicts."),
		FSimpleDelegate::CreateLambda([this, PackagesToReload, IncomingChanges, BatchId]()
			{
				// If there are unsaved changes - pop up an error instead and snooze
				// We show this error to let the user know that there are changes
				// and they should save the current unsaved packages asap
				if (UnsavedChangesExist()) {
					Snooze(BatchId, IncomingChanges);
					FText OpenedChangesMessage = LOCTEXT("ChangesWatcherUnsavedChangesExist",
						"Packages reload failed. Please make sure there are no unsaved packages first");
					FDiversionNotification UnsavedChangesErrorNotification(
						OpenedChangesMessage,
						TArray<FNotificationButtonInfo>(),
						SNotificationItem::CS_Fail
					);
					NotificationManager->ShowNotification(UnsavedChangesErrorNotification);
					return;
				}

				ReloadPackagesFromDisk(PackagesToReload.Array());
				Batcher->ResolveBatch(BatchId, EBatchDisposition::Accept);
				UE_LOG(LogChangesWatcher, Log, TEXT("Reloaded %d External changes from batch: %d"), PackagesToReload.Num(), BatchId);
			}),
		SNotificationItem::CS_Pending);

	FNotificationButtonInfo SnoozeButton(LOCTEXT("DiversionPopup_SnoozeChangesButton", "Snooze"),
		LOCTEXT("DiversionPopup_SnoozeChangesButton_Tooltip", "Remind me again in 30 seconds"),
		FSimpleDelegate::CreateLambda([this, PackagesToReload, BatchId, IncomingChanges]()
			{
				Snooze(BatchId, PackagesToReload);
			}),
		SNotificationItem::CS_Pending);

	FText OpenedChangesMessage = FText::Format(
		LOCTEXT("ChangesWatcherBatchReady",
			"Diversion: Some open assets may have changed on disk. Consider reloading to ensure you're working with the latest version."),
		FText::AsNumber(PackagesToReload.Num()));

	FDiversionNotification PopUpNotification(
		OpenedChangesMessage,
		TArray<FNotificationButtonInfo>({ ReloadButton, SnoozeButton }),
		SNotificationItem::CS_Pending
	);

	NotificationManager->ShowNotification(PopUpNotification);
}

bool FChangesWatcher::IsPakcageDifferentOnDisk(const FString& AbsFilePath) {
	FString LongPackageName;
	if (!FPackageName::TryConvertFilenameToLongPackageName(AbsFilePath, LongPackageName))
	{
		return true; // bad path is treat as "different value on disk"
	}

	const FName PackageFName(*LongPackageName);
	FAssetRegistryModule& ARM = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry");

	TOptional<FAssetPackageData> DiskData = ARM.Get().GetAssetPackageDataCopy(PackageFName);
	if (!DiskData.IsSet()) {
		ARM.Get().ScanModifiedAssetFiles({ AbsFilePath });
		DiskData = ARM.Get().GetAssetPackageDataCopy(PackageFName);
		if (!DiskData.IsSet())
		{
			return true; // Not in the registry, so assume it's different
		}
	}

#if ENGINE_MAJOR_VERSION >= 5 && ENGINE_MINOR_VERSION >= 4
	const FIoHash DiskHash = DiskData->GetPackageSavedHash();
	if (UPackage* CachedPkg = FindPackage(nullptr, *LongPackageName)) {
		const FIoHash MemHash = CachedPkg->GetSavedHash();
		bool bDifferent = DiskHash != MemHash;
		UE_LOG(LogChangesWatcher, Verbose, TEXT("Package comparison - %s: Different=%s"), 
			*LongPackageName, bDifferent ? TEXT("YES") : TEXT("NO"));
		return bDifferent;
	}
#else
	// UE 5.3 and earlier - use GUID comparison instead of hash
	const FGuid DiskGuid = DiskData->PackageGuid;
	if (UPackage* CachedPkg = FindPackage(nullptr, *LongPackageName)) {
		const FGuid MemGuid = CachedPkg->GetGuid();
		bool bDifferent = DiskGuid != MemGuid;
		UE_LOG(LogChangesWatcher, Verbose, TEXT("Package comparison - %s: DiskGuid=%s, MemGuid=%s, Different=%s"), 
			*LongPackageName, *DiskGuid.ToString(), *MemGuid.ToString(), 
			bDifferent ? TEXT("YES") : TEXT("NO"));
		return bDifferent;
	}
#endif

	// Package is not loaded, so we can't compare hashes - assume it's different
	UE_LOG(LogChangesWatcher, Verbose, TEXT("Package %s not loaded in memory - assuming different"), *LongPackageName);
	return true;
}

bool FChangesWatcher::ReloadPackagesFromDisk(const TArray<FString>& AbsoluteFilenames)
{
	using namespace UE::AssetRegistry;

	if (AbsoluteFilenames.Num() == 0)
	{
		return false;
	}

	FAssetRegistryModule& ARM = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry");
	ARM.Get().ScanModifiedAssetFiles(AbsoluteFilenames);

	// Sort packages by dependency order to prevent broken references
	TArray<FString> SortedFilenames = SortPackagesByDependencyOrder(AbsoluteFilenames);

	TArray<UPackage*> Pkgs;
	TArray<UPackage*> BlueprintPackages;
	
	for (const FString& AbsoluteFilename : SortedFilenames)
	{
		FString LongPkgPath;
		if (!FPackageName::TryConvertFilenameToLongPackageName(AbsoluteFilename, LongPkgPath))
			continue;

		// Close editors & collect package pointer if loaded
		if (UPackage* Pkg = FindPackage(nullptr, *LongPkgPath))
		{
			UAssetEditorSubsystem* AssetEditorSubsystem = GEditor->GetEditorSubsystem<UAssetEditorSubsystem>();
			UObject* Asset = Pkg->FindAssetInPackage();
			
			// Check if this is a Blueprint package for special handling
			if (Asset && Asset->IsA<UBlueprint>())
			{
				BlueprintPackages.Add(Pkg);
			}
			
			AssetEditorSubsystem->CloseAllEditorsForAsset(Asset);
			Pkgs.Add(Pkg);
		}
	}

	if (Pkgs.Num() == 0)
	{
		return false;
	}

	// Wait for asset registry to be fully updated
	if (!WaitForAssetRegistryUpdate(SortedFilenames))
	{
		UE_LOG(LogChangesWatcher, Warning, TEXT("Asset registry update timeout, proceeding with reload"));
	}

	bool bAnyReloaded = false;
	FText Error;
	
	// Reload packages in dependency order
	UEditorLoadingAndSavingUtils::ReloadPackages(
		Pkgs,
		/*out*/ bAnyReloaded,
		/*out*/ Error,
		EReloadPackagesInteractionMode::AssumePositive);

	if (!Error.IsEmpty())
	{
		UE_LOG(LogChangesWatcher, Warning, TEXT("Reload error: %s"), *Error.ToString());
		return false;
	}

	if (bAnyReloaded)
	{
		// Give asset registry time to process the reloaded packages
		FPlatformProcess::Sleep(0.1f);
		
		// Validate post-reload state for Blueprint packages
		ValidatePostReloadState(BlueprintPackages);
		
		UE_LOG(LogChangesWatcher, Log, TEXT("Successfully reloaded %d packages (%d Blueprints)"), 
			Pkgs.Num(), BlueprintPackages.Num());
	}

	return bAnyReloaded;
}

bool FChangesWatcher::UnsavedChangesExist()
{
	TArray<UPackage*> DirtyPackages;
	UEditorLoadingAndSavingUtils::GetDirtyContentPackages(DirtyPackages);
	return DirtyPackages.Num() > 0;
}

void FChangesWatcher::Snooze(uint32 BatchId, const TSet<FString>& IncomingChanges)
{
	Batcher->ResolveBatch(BatchId, EBatchDisposition::Snooze);
	// Start snooze
	if (!SnoozeTimerHandle.IsValid())
	{
		// Avoid redundant AsyncTask if already on game thread
		if (IsInGameThread())
		{
			SnoozeTimerHandle = FTSTicker::GetCoreTicker().AddTicker(
				FTickerDelegate::CreateLambda([this, BatchId, IncomingChanges](float DeltaTime) {
					HandleChangesBatch(BatchId, IncomingChanges);
					return false;
					}), 30.0f);
		}
		else
		{
			TWeakPtr<FChangesWatcher> WeakPtr = AsShared();
			AsyncTask(ENamedThreads::GameThread, [WeakPtr, BatchId, IncomingChanges]() mutable {
				if (TSharedPtr<FChangesWatcher> Pinned = WeakPtr.Pin())
				{
					if (!Pinned->SnoozeTimerHandle.IsValid())
					{
						Pinned->SnoozeTimerHandle = FTSTicker::GetCoreTicker().AddTicker(
							FTickerDelegate::CreateLambda([Pinned, BatchId, IncomingChanges](float DeltaTime) {
								Pinned->HandleChangesBatch(BatchId, IncomingChanges);
								return false;
								}),
							30.0f);
					}
				}
				});
		}
	}
}

void FChangesWatcher::StopSnooze()
{
	if (SnoozeTimerHandle.IsValid()) {
		FTSTicker::GetCoreTicker().RemoveTicker(SnoozeTimerHandle);
		SnoozeTimerHandle.Reset();
	}
}

TArray<FString> FChangesWatcher::SortPackagesByDependencyOrder(const TArray<FString>& PackagePaths)
{
	IAssetRegistry& AssetRegistry = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry").Get();
	TMap<FString, TSet<FString>> DependencyMap;
	
	// Build dependency map - only include dependencies within our reload set
	for (const FString& PackagePath : PackagePaths)
	{
		FString LongPackageName;
		if (!FPackageName::TryConvertFilenameToLongPackageName(PackagePath, LongPackageName)) continue;
		
		TArray<FName> Dependencies;
		AssetRegistry.GetDependencies(FName(*LongPackageName), Dependencies, UE::AssetRegistry::EDependencyCategory::Package);
		
		for (const FName& Dep : Dependencies)
		{
			FString DepPath;
			if (FPackageName::TryConvertLongPackageNameToFilename(Dep.ToString(), DepPath) && PackagePaths.Contains(DepPath))
			{
				DependencyMap.FindOrAdd(PackagePath).Add(DepPath);
			}
		}
	}
	
	// Topological sort using DFS
	TArray<FString> SortedPaths;
	TSet<FString> ProcessedPaths;
	TFunction<void(const FString&)> VisitPackage = [&](const FString& PackagePath)
	{
		if (ProcessedPaths.Contains(PackagePath)) return;
		ProcessedPaths.Add(PackagePath);
		
		if (const TSet<FString>* Dependencies = DependencyMap.Find(PackagePath))
		{
			for (const FString& Dependency : *Dependencies)
			{
				VisitPackage(Dependency);
			}
		}
		SortedPaths.Add(PackagePath);
	};
	
	for (const FString& PackagePath : PackagePaths)
	{
		VisitPackage(PackagePath);
	}
	
	return SortedPaths;
}


bool FChangesWatcher::WaitForAssetRegistryUpdate(const TArray<FString>& PackagePaths, float TimeoutSeconds)
{
	IAssetRegistry& AssetRegistry = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry").Get();
	const double StartTime = FPlatformTime::Seconds();
	
	while (FPlatformTime::Seconds() < StartTime + TimeoutSeconds)
	{
		bool bAllUpdated = true;
		for (const FString& PackagePath : PackagePaths)
		{
			FString LongPackageName;
			if (FPackageName::TryConvertFilenameToLongPackageName(PackagePath, LongPackageName) &&
				!AssetRegistry.GetAssetPackageDataCopy(FName(*LongPackageName)).IsSet())
			{
				bAllUpdated = false;
				break;
			}
		}
		
		if (bAllUpdated)
		{
			UE_LOG(LogChangesWatcher, Verbose, TEXT("Asset registry updated for all packages in %.3fs"), 
				FPlatformTime::Seconds() - StartTime);
			return true;
		}
		
		// Allow asset registry to process
		FPlatformProcess::Sleep(0.01f);
	}
	
	UE_LOG(LogChangesWatcher, Warning, TEXT("Asset registry update timeout after %.3fs"), TimeoutSeconds);
	return false;
}

void FChangesWatcher::ValidatePostReloadState(const TArray<UPackage*>& ReloadedPackages)
{
	for (UPackage* Package : ReloadedPackages)
	{
		if (!IsValid(Package)) continue;
		
		if (UBlueprint* Blueprint = Cast<UBlueprint>(Package->FindAssetInPackage()))
		{
			// Check if Blueprint needs recompilation
			if (Blueprint->Status == BS_Dirty || Blueprint->Status == BS_Unknown)
			{
				UE_LOG(LogChangesWatcher, Log, TEXT("Blueprint %s needs recompilation after reload"), 
					*Blueprint->GetName());
				
				// Mark for compilation - UE will handle the actual compilation timing
				// This ensures Blueprint gets recompiled with proper dependency order
				Blueprint->Status = BS_Dirty;
			}
			
			// Validate Blueprint class integrity
			if (Blueprint->GeneratedClass && Blueprint->GeneratedClass->GetDefaultObject())
			{
				UE_LOG(LogChangesWatcher, Verbose, TEXT("Blueprint %s validation passed"), 
					*Blueprint->GetName());
			}
			else
			{
				UE_LOG(LogChangesWatcher, Warning, TEXT("Blueprint %s may have compilation issues after reload"), 
					*Blueprint->GetName());
			}
		}
	}
}

#undef LOCTEXT_NAMESPACE

DEFINE_LOG_CATEGORY(LogChangesWatcher);
