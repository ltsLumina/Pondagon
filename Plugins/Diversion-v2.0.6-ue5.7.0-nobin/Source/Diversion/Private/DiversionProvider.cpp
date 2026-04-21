// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#include "DiversionProvider.h"
#include "DiversionState.h"
#include "Misc/Paths.h"
#include "Misc/QueuedThreadPool.h"
#include "DiversionCommand.h"
#include "DiversionConfig.h"
#include "ISourceControlModule.h"
#include "SourceControlHelpers.h"
#include "DiversionModule.h"
#include "DiversionUtils.h"
#include "SDiversionSettings.h"
#include "SourceControlOperations.h"
#include "Logging/MessageLog.h"
#include "ScopedSourceControlProgress.h"
#include "Interfaces/IPluginManager.h"
#include "DiversionOperations.h"
#include "DiversionConstants.h"
#include "CustomWidgets/DiversionPotentialClashUI.h"
#include "CustomWidgets/DiversionStatusPanel.h"
#include "CustomWidgets/DiversionCommitHelper.h"
#include "ContentBrowserModule.h"
#include "PackageTools.h"
#include "DirectoryWatcherModule.h"
#include "Modules/ModuleManager.h"
#include "UObject/ObjectSaveContext.h"
#include "Misc/EngineVersionComparison.h"
#include "Framework/Application/SlateApplication.h"
#include "SourceControlOperations.h"
#include "ToolMenuEntry.h"
#include "SourceControlWindows.h"
#include "RevisionControlStyle/RevisionControlStyle.h"

// For status bar registration
#include "LevelEditor.h"
#include "ToolMenus.h"
#include "Framework/MultiBox/MultiBoxBuilder.h"


#include "DataValidationChangelist.h"
#include "EditorValidatorSubsystem.h"
#include <Algo/AnyOf.h>


#define LOCTEXT_NAMESPACE "Diversion"

static FName ProviderName("Diversion");



void OverrideLocalizationStrings()
{
	FTextLocalizationResource LocalizationResource;
	
	// PackagesDialogModule Assets checkout overrides
	LocalizationResource.AddEntry(FTextKey("FileHelpers"),
		FTextKey("Warning_Notification"),
		FString("Warning: Assets have conflict in Revision Control or cannot be written to disk"),
		FString("Warning: Assets you have edited are also being edited in another workspace. To see who edited them cancel this operation and hover the asset in the Content Browser."),
		100);
	
	LocalizationResource.AddEntry(FTextKey("PackagesDialogModule"),
		FTextKey("CheckoutPackagesDialogTitle"),
		FString("Check Out Assets"),
		FString("Override Auto Soft-Locked Assets"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("PackagesDialogModule"),
		FTextKey("CheckoutPackagesDialogMessage"),
		FString("Select assets to check out."),
		FString("Select assets to save."),
		100);

	LocalizationResource.AddEntry(FTextKey("PackagesDialogModule"),
		FTextKey("CheckoutPackagesWarnMessage"),
		FString("Warning: There are modified assets which you will not be able to check out as they are locked or not at the head revision. You may lose your changes if you continue, as you will be unable to submit them to revision control."),
		FString("Warning: These assets are currently being edited in another workspace or branch and were automatically soft-locked. Saving files that are auto soft-locked is possibe, but might create conflicts."),
		100);

	LocalizationResource.AddEntry(FTextKey("PackagesDialogModule"),
		FTextKey("Dlg_MakeWritableButton"),
		FString("Make Writable"),
		FString("Override Soft-Lock"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("PackagesDialogModule"),
		FTextKey("Dlg_MakeWritableTooltip"),
		FString("Makes selected files writable on disk"),
		FString("Save your changes, potentially creating conflicts"),
		100);

	LocalizationResource.AddEntry(FTextKey("PackagesDialogModule"),
		FTextKey("Dlg_CheckOutButtonp"),
		FString("Check Out Selected"),
		FString("Reset Changes"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("PackagesDialogModule"),
		FTextKey("Dlg_CheckOutTooltip"),
		FString("Attempt to Check Out Checked Assets"),
		FString("Use the asset's context menu to reset changes"),
		100);
	
	// General SPackagesDialog overrides
	LocalizationResource.AddEntry(FTextKey("SPackagesDialog"),
		FTextKey("CheckedOutByColumnLabel"),
		FString("Checked Out By"),
		FString("Auto Soft-Locked By"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("UnsavedAssetsTracker"),
		FTextKey("Locked_by_Other_Warning"),
		FString("Warning: Assets you have edited are locked by another user."),
		FString("Warning: Assets you have edited are also being edited in another branch or workspace."),
		100);
	
	LocalizationResource.AddEntry(FTextKey("AssetSourceControlContextMenu"),
		FTextKey("SCCRevert"),
		FString("Revert"),
		FString("Reset"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("AssetSourceControlContextMenu"),
		FTextKey("SCCRevertTooltip"),
		FString("Reverts the selected assets to their original state from revision control."),
		FString("Resets the selected assets to their original state from Diversion."),
		100);
	
	LocalizationResource.AddEntry(FTextKey("SourceControl"),
		FTextKey("SourceControl_CheckIn"),
		FString("Checking file(s) into Revision Control..."),
		FString("Committing file(s) to Diversion..."),
		100);
	
	LocalizationResource.AddEntry(FTextKey("SourceControl"),
		FTextKey("SourceControl_Revert"),
		FString("Reverting file(s) in Revision Control..."),
		FString("Resetting file(s) in Diversion..."),
		100);
	
	LocalizationResource.AddEntry(FTextKey("SourceControl.RevertWindow"),
		FTextKey("Title"),
		FString("Revert Files"),
		FString("Reset Files"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("SourceControl.Revert"),
		FTextKey("SelectFiles"),
		FString("Select the files that should be reverted below"),
		FString("Select the files to reset below"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("SourceControl.Revert"),
		FTextKey("RevertUnchanged"),
		FString("Revert Unchanged Only"),
		FString("Reset Unchanged Only"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("SSourceControlRevert"),
		FTextKey("RevertButton"),
		FString("Revert"),
		FString("Reset"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("FileSourceControlActions"),
		FTextKey("SCCRevertTooltip"),
		FString("Reverts the selected files to their original state from revision control."),
		FString("Resets the selected files to their original state from Diversion."),
		100);
	
	LocalizationResource.AddEntry(FTextKey("SourceControlWindows"),
		FTextKey("ChooseAssetsToCheckInIndicator"),
		FString("Checking for assets to check in..."),
		FString("Waiting for selection of assets to commit..."),
		100);
	
	LocalizationResource.AddEntry(FTextKey("SourceControlWindows"),
		FTextKey("NoAssetsToCheckIn"),
		FString("No assets to check in!"),
		FString("No changes to commit"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("UICommands.SourceControlCommands"),
		FTextKey("SubmitContent_ToolTip"),
		FString("Opens a dialog with check in options for content and levels."),
		FString("Opens a dialog with commit options for content and levels."),
		100);
	
	LocalizationResource.AddEntry(FTextKey("UICommands.SourceControlCommands"),
		FTextKey("SubmitContent"),
		FString("Submit Content"),
		FString("Commit Changes"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("UICommands.SourceControlCommands"),
		FTextKey("CheckOutModifiedFiles_ToolTip"),
		FString("Opens a dialog to check out any assets which have been modified."),
		FString("Saves all modified assets."),
		100);
	
	LocalizationResource.AddEntry(FTextKey("UICommands.SourceControlCommands"),
		FTextKey("CheckOutModifiedFiles"),
		FString("Check Out Modified Files"),
		FString("Save Modified Files"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("SourceControl.SubmitPanel"),
		FTextKey("ChangeListDesc"),
		FString("Changelist Description"),
		FString("Commit Message"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("SourceControl.SubmitPanel"),
		FTextKey("OKButton"),
		FString("Submit"),
		FString("Commit"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("SourceControl.SubmitPanel"),
		FTextKey("KeepCheckedOut"),
		FString("Keep Files Checked Out"),
		FString("Thank you for using Diversion!"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("SourceControl.SubmitPanel"),
		FTextKey("ChangeListDescWarning"),
		FString("Changelist description is required to submit"),
		FString("Commit message is required"),
		100);
	
	LocalizationResource.AddEntry(FTextKey("SourceControl.SubmitWindow"),
		FTextKey("Title"),
		FString("Submit Files"),
		FString("Commit Files"),
		100);

	LocalizationResource.AddEntry(FTextKey("SourceControlCommands"),
		FTextKey("SourceControlStatus_Error_ServerUnavailable"),
		FString("Server Unavailable"),
		FString("Sync Paused"),
		100);
	
	FTextLocalizationManager::Get().UpdateFromLocalizationResource(LocalizationResource);
}

void FDiversionProvider::Init(bool bForceConnection)
{
	bDiversionStopped = false;
	// Init() is called multiple times at startup: do not check dv each time
	if (!bDiversionAvailable)
	{
		OverrideLocalizationStrings();
		if (GetDiversionVersion(EConcurrency::Synchronous, true).IsValid())
		{
			GetWsInfo(EConcurrency::Synchronous, true);
		}
		CheckDiversionAvailability();

		// Handle "Resolve" on package save and "Finalize Merge"
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 4
		UPackage::PackageSavedWithContextEvent.AddRaw(this, &FDiversionProvider::OnPackageSaveWithContext);
#else
		UPackage::PackageSavedEvent.AddRaw(this, &FDiversionProvider::OnPackageSave);
#endif
		UPackage::PreSavePackageWithContextEvent.AddRaw(this, &FDiversionProvider::OnPrePackageSave);

		auto& Module = FDiversionModule::Get();
		if (!DiversionUtils::DiversionValidityCheck(&Module != nullptr, 
				"Diversion Module is not valid!", GetWsInfo().AccountID)) {
			return;
		}
		// Set the original account ID with which the plugin was loaded
		Module.SetOriginalAccountID(GetWsInfo().AccountID);

		auto SendAnalyticsOperation = ISourceControlOperation::Create<FSendAnalytics>();
		SendAnalyticsOperation->SetEventName(FText::FromString("UE Plugin Load"));
		SendAnalyticsOperation->SetEventProperties({{"ue_softlock_enabled", IsDiversionSoftLockEnabled() ? "true" : "false"}});
		Execute(SendAnalyticsOperation, nullptr, TArray<FString>(), EConcurrency::Asynchronous);

		FAgentHealthCheck::SetProgressString();
		FGetWsInfo::SetProgressString();

		// Set the project path delegate
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION <= 4
		ISourceControlModule::Get().RegisterSourceControlProjectDirDelegate(
			FSourceControlProjectDirDelegate::CreateLambda([this]() {
				return WsInfo.Get().GetPath();
			}));
#else
		ISourceControlModule::Get().RegisterCustomProjectsDelegate(
			FSourceControlCustomProjectsDelegate::CreateLambda([this]() {
				FSourceControlProjectInfo ProjectInfo;
				ProjectInfo.ProjectDirectory = WsInfo.Get().GetPath();
				ProjectInfo.ContentDirectories = { FPaths::ProjectContentDir() };
				return TArray<FSourceControlProjectInfo>{ProjectInfo};
			}));
#endif
		RegisterPreSubmitValidationDelegates();

		// Start background checks
		auto BackgroundStatusDelegate = DiversionTimerDelegate::CreateLambda([this]() {
			if (!bDiversionAvailable) {
				return;
			}

			if (!DiversionUtils::DiversionValidityCheck(IsInGameThread(),
	"Call Update Status called outside of main thread",
					FDiversionModule::Get().GetOriginalAccountID())) {
				return;
			}

			const auto Operation = ISourceControlOperation::Create<FUpdateStatus>();
			Execute(Operation, nullptr, { WsInfo.Get().GetPath() }, EConcurrency::Asynchronous);
		});
		
		BackgroundStatus = MakeUnique<FTimedDelegateWrapper>(
			BackgroundStatusDelegate, SECONDS_TO_POLL_STATUS);
		BackgroundStatus->Start();

		auto BackgroundPotentialClashesDelegate = DiversionTimerDelegate::CreateLambda([this]() {
			if (!bDiversionAvailable) {
				return;
			}

			if (!DiversionUtils::DiversionValidityCheck(IsInGameThread(),
			"Get Potential Clashes called outside of main thread",
					FDiversionModule::Get().GetOriginalAccountID())) {
				return;
			}

			auto operation = ISourceControlOperation::Create<FGetPotentialClashes>();
			Execute(operation, nullptr, { WsInfo.Get().GetPath() }, EConcurrency::Asynchronous);
		});

		BackgroundPotentialClashes = MakeUnique<FTimedDelegateWrapper>(
			BackgroundPotentialClashesDelegate, SECONDS_TO_POLL_POTENTIAL_CLASHES);
		BackgroundPotentialClashes->Start();


		auto BackgroundConflictedFilesDelegate = DiversionTimerDelegate::CreateLambda([this]() {
			if (!bDiversionAvailable) {
				return;
			}
			
			if (!DiversionUtils::DiversionValidityCheck(IsInGameThread(),
			"Get Conflicts called outside of main thread",
					FDiversionModule::Get().GetOriginalAccountID())) {
				return;
			}

			auto operation = ISourceControlOperation::Create<FGetConflictedFiles>();
			Execute(operation, nullptr, { }, EConcurrency::Asynchronous);
		});

		BackgroundConflictedFiles = MakeUnique<FTimedDelegateWrapper>(
			BackgroundConflictedFilesDelegate, SECONDS_TO_POLL_CONFLICTED_FILES);
		BackgroundConflictedFiles->Start();
		BackgroundConflictedFiles->TriggerInstantCallAndReset();

		if (FSlateApplication::IsInitialized())
		{
			FocusChangedHandle = FSlateApplication::Get().OnApplicationActivationStateChanged().AddRaw(
				this, &FDiversionProvider::OnApplicationFocusChanged);
		}

		// Add the Diversion potential clash indicator to the asset view
		SPotentialClashIndicator::CacheIndicatorBrush();
		if (FContentBrowserModule* ContentBrowserModule = FModuleManager::Get().GetModulePtr<FContentBrowserModule>(TEXT("ContentBrowser")))
		{
			if (!PotentialClashUIIconDelegateHandle.IsValid()) {
				PotentialClashUIIconDelegateHandle = ContentBrowserModule->AddAssetViewExtraStateGenerator(FAssetViewExtraStateGenerator(
					FOnGenerateAssetViewExtraStateIndicators::CreateRaw(this, &FDiversionProvider::OnGenerateAssetViewPotentialClashIcon),
					FOnGenerateAssetViewExtraStateIndicators::CreateRaw(this, &FDiversionProvider::OnGenerateAssetViewPotentialClashTooltip)
				));
			}
		}
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 6
		// Initialize custom UI commands for submit functionality
		InitializeUICommands();
#endif

		// Register status bar widget
		RegisterStatusBarWidget();
	}

	// TODO bForceConnection: used by commandlets (typically for CI/CD scripts)
}

FString FDiversionProvider::GetBranchId()
{
	return WsInfo.Get().BranchID;
}

bool FDiversionProvider::CheckDiversionAvailability()
{
	if(!DiversionUtils::IsDiversionInstalled())
	{
		DiversionUtils::PrintSupportNeededLogLine("Diversion agent is not installed. Please install the desktop app as documented at https://docs.diversion.dev/quickstart?utm_source=ue-plugin&utm_medium=plugin or contact support if the issue persists.", true);

		return false;
	}

	if (const TSharedPtr<IPlugin> Plugin = FDiversionModule::GetPlugin())
	{
		PluginVersion = Plugin->GetDescriptor().VersionName;
		UE_LOG(LogSourceControl, Log, TEXT("Diversion plugin %s"), *PluginVersion);
	}
	else
	{
		// TODO: Can we get more info here?
		DiversionUtils::PrintSupportNeededLogLine("Failed loading Diversion plugin. Try disabling and re-enabling the plugin (Edit -> Plugins -> Diversion), or reinstalling on the marketplace. Please contact support if the issue persists.");

		return false;
	}

	if(!IsAgentAlive())
	{
		DiversionUtils::PrintSupportNeededLogLine("Diversion agent is not running or properly configured. Check Diversion tray icon or open Diversion Desktop to verify agent is up.", true);

		return false;
	}

	bDiversionAvailable = GetDiversionVersion().IsValid();
	return bDiversionAvailable;
}

void FDiversionProvider::Close()
{
	if (FSlateApplication::IsInitialized() && FocusChangedHandle.IsValid())
	{
		FSlateApplication::Get().OnApplicationActivationStateChanged().Remove(FocusChangedHandle);
	}

	UnregisterAndRestorePreSubmitValidationDelegates();

	// clear the cache
	StateCache.Empty();

	bDiversionAvailable = false;
	UserEmail.Empty();
	bDiversionStopped = true;

	// Wait for all commands to finish but exit if it takes too long
	// This is to avoid a deadlock when the engine is shutting down	

	auto WaitForCommandsDelegate = WaitForConditionPredicate::CreateLambda([this]() { 
		Tick();
		return CommandQueue.Num() == 0; 
	});
	bool Success = DiversionUtils::WaitForCondition(WaitForCommandsDelegate, 30.0);
	if(!Success)
	{
		UE_LOG(LogSourceControl, Error, TEXT("Failed to fully close Diversion provider, there are still pending commands"));
	}
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 4
	UPackage::PackageSavedWithContextEvent.RemoveAll(this);
#else
	UPackage::PackageSavedEvent.RemoveAll(this);
#endif
	UPackage::PreSavePackageWithContextEvent.RemoveAll(this);

	// Reset localization strings
	FTextLocalizationManager::Get().RefreshResources();


	if (FContentBrowserModule* ContentBrowserModule = FModuleManager::Get().GetModulePtr<FContentBrowserModule>(TEXT("ContentBrowser")))
	{
		if (PotentialClashUIIconDelegateHandle.IsValid())
		{
			ContentBrowserModule->RemoveAssetViewExtraStateGenerator(PotentialClashUIIconDelegateHandle);
		}
	}
	PotentialClashUIIconDelegateHandle.Reset();

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 6
	// Shutdown custom UI commands
	ShutdownUICommands();
#endif

	// Unregister status bar widget
	UnregisterStatusBarWidget();
}

FText FDiversionProvider::GetStatusText() const
{
	FString AgentStatus = IsAgentAlive() ? "alive" : "not running";
	FString WsSyncStatus = IsAgentAlive() ? DiversionUtils::GetWsSyncStatusString(SyncStatus.Get()) : "";
	// Combine AgentStatus WsSyncStatus
	FString Status = FString::Printf(TEXT("%s. %s"), *AgentStatus, *WsSyncStatus);

	FFormatNamedArguments Args;
	Args.Add(TEXT("Version"), FText::FromString(GetDiversionVersion().ToString()));
	Args.Add(TEXT("PluginVersion"), FText::FromString(PluginVersion));
	Args.Add(TEXT("AgentAlive"), FText::FromString(Status));
	Args.Add(TEXT("PathToWorkspaceRoot"), FText::FromString(WsInfo.Get().GetPath()));
	Args.Add(TEXT("WorkspaceName"), FText::FromString(GetWorkspaceName()));
	Args.Add(TEXT("RepositoryName"), FText::FromString(WsInfo.Get().RepoName));
	Args.Add(TEXT("BranchName"), FText::FromString(WsInfo.Get().BranchName));

	return FText::Format(NSLOCTEXT("Status", "Provider: Diversion\nEnabledLabel", "Version {Version} (plugin {PluginVersion})\nAgent {AgentAlive}\nWorkspace: {WorkspaceName}\nRepository: {RepositoryName}\nBranch: {BranchName}\n"), Args);
}

TMap<ISourceControlProvider::EStatus, FString> FDiversionProvider::GetStatus() const
{
	TMap<EStatus, FString> Result;
	Result.Add(EStatus::Enabled, IsEnabled() ? TEXT("Yes") : TEXT("No"));
	Result.Add(EStatus::Connected, (IsEnabled() && IsAvailable()) ? TEXT("Yes") : TEXT("No"));
	Result.Add(EStatus::WorkspacePath, WsInfo.Get().GetPath());
	Result.Add(EStatus::Workspace, GetWorkspaceName());
	Result.Add(EStatus::Repository, WsInfo.Get().RepoName);
	Result.Add(EStatus::Branch, WsInfo.Get().BranchName);
	return Result;
}

/** Quick check if version control is enabled */
bool FDiversionProvider::IsEnabled() const
{
	return IsRepoFound();
}

/** Diversion version for feature checking */

const FDiversionVersion& FDiversionProvider::GetDiversionVersion(EConcurrency::Type Concurrency, bool InForceUpdate)
{
	if (!DiversionUtils::DiversionValidityCheck(IsInGameThread(), 
			"GetDiversionVersion called outside of main thread", FDiversionModule::Get().GetOriginalAccountID())) {
		return DvVersion.Get();
	}

	return DvVersion.GetUpdate(DvVersion.Get(),
		FOnCacheUpdate::CreateLambda([this, &Concurrency]() {
			auto operation = ISourceControlOperation::Create<FAgentHealthCheck>();
			Execute(operation, nullptr, TArray<FString>(), Concurrency);
			}), InForceUpdate);
}

const FDiversionVersion& FDiversionProvider::GetDiversionVersion() const 
{
	return DvVersion.Get();
}

WorkspaceInfo FDiversionProvider::GetWsInfo(EConcurrency::Type Concurrency, bool InForceUpdate)
{
	if (!DiversionUtils::DiversionValidityCheck(IsInGameThread(),
		"GetWsInfo called outside of main thread", FDiversionModule::Get().GetOriginalAccountID())) {
		return WsInfo.Get();
	}

	return WsInfo.GetUpdate(
		WsInfo.Get(), FOnCacheUpdate::CreateLambda([this, &Concurrency]() {
			auto operation = ISourceControlOperation::Create<FGetWsInfo>();
			Execute(operation, nullptr, TArray<FString>(), Concurrency);
		}), InForceUpdate);
}

WorkspaceInfo FDiversionProvider::GetWsInfo() const {
	return WsInfo.Get();
}

void FDiversionProvider::SetDvVersion(const FDiversionVersion& InVersion)
{
	if (!DiversionUtils::DiversionValidityCheck(IsInGameThread(),
		"SetDvVersion must be called on the main game thread", FDiversionModule::Get().GetOriginalAccountID())) {
		return;
	}

	DvVersion.Set(InVersion);
}

void FDiversionProvider::SetWorkspaceInfo(const WorkspaceInfo& InWsInfo)
{
	if (!DiversionUtils::DiversionValidityCheck(IsInGameThread(),
		"SetWorkspaceInfo must be called on the main game thread", FDiversionModule::Get().GetOriginalAccountID())) {
		return;
	}

	bDiversionAvailable = WsInfo.Get().IsValid();
	WsInfo.Set(InWsInfo);
}

void FDiversionProvider::SetSyncStatus(const DiversionUtils::EDiversionWsSyncStatus& InSyncStatus)
{
	if (!DiversionUtils::DiversionValidityCheck(IsInGameThread(),
		"SetSyncStatus must be called on the main game thread", FDiversionModule::Get().GetOriginalAccountID())) {
		return;
	}

	SyncStatus.Set(InSyncStatus);
}

DiversionUtils::EDiversionWsSyncStatus FDiversionProvider::GetSyncStatus() const
{
	return SyncStatus.Get();
}

bool FDiversionProvider::IsRepoFound() const {
	FString RepoId = WsInfo.Get().RepoID;
	return (!RepoId.IsEmpty()) && (RepoId != "N/a");
}

/** Quick check if version control is available for use (useful for server-based providers) */
bool FDiversionProvider::IsAvailable() const
{
	return IsRepoFound() && IsAgentAlive() && 
		(
			SyncStatus.Get() == DiversionUtils::EDiversionWsSyncStatus::PathError  ||
			SyncStatus.Get() == DiversionUtils::EDiversionWsSyncStatus::InProgress ||
			SyncStatus.Get() == DiversionUtils::EDiversionWsSyncStatus::Completed
		);
}

const FName& FDiversionProvider::GetName(void) const
{
	return ProviderName;
}

ECommandResult::Type FDiversionProvider::GetState(const TArray<FString>& InFiles, TArray< TSharedRef<ISourceControlState, ESPMode::ThreadSafe> >& OutState, EStateCacheUsage::Type InStateCacheUsage)
{
	if (!IsEnabled())
	{
		return ECommandResult::Failed;
	}

	TArray<FString> AbsoluteFiles = SourceControlHelpers::AbsoluteFilenames(InFiles);

	if (InStateCacheUsage == EStateCacheUsage::ForceUpdate)
	{
		Execute(ISourceControlOperation::Create<FUpdateStatus>(), AbsoluteFiles);
	}

	const FString WsPath = GetPathToWorkspaceRoot();

	for (const auto& AbsoluteFile : AbsoluteFiles)
	{
		TSharedRef<FDiversionState, ESPMode::ThreadSafe> State = GetStateInternal(*AbsoluteFile);

		// When ForceUpdate is requested but the state is still Unknown (e.g. the synchronous
		// Execute path deferred actual status queries to background polling), provide a
		// preliminary state based on disk presence within the workspace. The background
		// poller will later correct this with actual API data if needed.
		if (InStateCacheUsage == EStateCacheUsage::ForceUpdate &&
			State->WorkingCopyState == EWorkingCopyState::Unknown &&
			FPaths::IsUnderDirectory(*AbsoluteFile, WsPath))
		{
			State->SetStateFromDiskPresence();
		}

		OutState.Add(State);
	}

	return ECommandResult::Succeeded;
}

void FDiversionProvider::AddModifiedState(const TSharedRef<class FDiversionState>& InState)
{
	ModifiedStates.Add(InState->LocalFilename, InState);
	ChangelistState->Files.Add(InState);
}

bool FDiversionProvider::IsRepoWithSameNameExists(const FString& RepoName, EConcurrency::Type Concurrency, bool InForceUpdate) {
	if (!DiversionUtils::DiversionValidityCheck(IsInGameThread(),
		"IsRepoWithSameNameExists must be called on the main game thread", FDiversionModule::Get().GetOriginalAccountID())) {
		return bRepoWithSameNameExists.Get();
	}

	return bRepoWithSameNameExists.GetUpdate(bRepoWithSameNameExists.Get(),
		FOnCacheUpdate::CreateLambda([this, &Concurrency, &RepoName]() {
			auto operation = ISourceControlOperation::Create<FCheckForRepoWithSameName>();
			operation->SetRepoName(RepoName);
			Execute(operation, nullptr, TArray<FString>(), Concurrency);
		}), InForceUpdate);
}

bool FDiversionProvider::IsWorkspaceExistsInPath(const FString& RepoName, const FString& Path, EConcurrency::Type Concurrency, bool InForceUpdate) {
	if (!DiversionUtils::DiversionValidityCheck(IsInGameThread(),
		"IsWorkspaceExistsInPath must be called on the main game thread", FDiversionModule::Get().GetOriginalAccountID())) {
		return bWorkspaceExistsInPath.Get();
	}
	return bWorkspaceExistsInPath.GetUpdate(bWorkspaceExistsInPath.Get(),
		FOnCacheUpdate::CreateLambda([this, &Concurrency, &RepoName, &Path]() {
			auto operation = ISourceControlOperation::Create<FCheckIfWorkspaceExistsInPath>();
			operation->SetPath(Path);
			operation->SetRepoName(RepoName);
			Execute(operation, nullptr, TArray<FString>(), Concurrency);
		}), InForceUpdate);
}

void FDiversionProvider::AddCurrentChangesToChangelistState()
{
	ChangelistState->Files.Empty();
	for (auto& state : ModifiedStates)
	{
		ChangelistState->Files.Add(state.Value);
	}
}

TArray<TSharedRef<FDiversionState>> FDiversionProvider::PerformPreSubmitValidation(
	const TArray<FString>& FilesInChangeList,
	EDataValidationResult& Result,
	TArray<FText>& ValidationErrors,
	TArray<FText>& ValidationWarnings)
{
	// This is the common validation logic used by both changelist and files validation.
	// It works around Perforce-specific UE implementations.
	//
	// Since UE is coupled with perforce, the validation makes sure that if a Package's dependencies are
	// not in the changelists they are not "Added" and not "Checked-out"
	//
	// as performed in UDataValidationChangelist::IsDataValid(...)
	// in the condition: if (ExternalDependencyFileState->IsCheckedOut() || ExternalDependencyFileState->IsAdded())
	//
	// Since in Diversion everything is checked out by default, we need to work around this condition so
	// the changelist validation won't fail.
	//
	// This overrides the dependencies and "uncheck them out" for the duration of the validation check.

	// States that need to be cleaned up after the validation run
	TArray<TSharedRef<FDiversionState>> StatesToClean;

	for (const auto& FilePath : FilesInChangeList)
	{
		auto* Package = DiversionUtils::UPackageUtils::PackageFromPath(FilePath, true);
		if (Package != nullptr) {
			TArray<FString> ExternalDependenciesFilenames;

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 6
			TSet<TPair<FName, FName>> ExternalDependenciesSet;
#else
			TSet<FName> ExternalDependenciesSet;
#endif
			UDataValidationChangelist::GatherDependencies(Package->GetFName(), ExternalDependenciesSet);
			auto ExternalDependencies = ExternalDependenciesSet.Array();

			// Remove the files that are already in the changelist
			ExternalDependencies.RemoveAll([&FilesInChangeList](auto& File) -> bool {
			return Algo::AnyOf(FilesInChangeList, [&File](const auto& FileInChangelist) {
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 6
				return File.Value == FileInChangelist;
#else
				return File == FileInChangelist;
#endif
				});
			});

			// Transform the dependencies packages to their filenames
			Algo::Transform(ExternalDependencies, ExternalDependenciesFilenames, [](auto& InFilename) -> FString
			{
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 6
				return USourceControlHelpers::PackageFilename(InFilename.Value.ToString());
#else
				return USourceControlHelpers::PackageFilename(InFilename.ToString());
#endif
			});

			for (const FString& DependencyFilePath : ExternalDependenciesFilenames)
			{
				auto DependencyState = GetStateInternal(DependencyFilePath);
				DependencyState->SetOverrideDefaultCheckout();
				StatesToClean.Add(DependencyState);
			}
		}
	}

	return StatesToClean;
}

void FDiversionProvider::RegisterPreSubmitValidationDelegates()
{
	// Safe to unregister: original delegates were copied (not handles) in constructor before this call
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
	ISourceControlModule::Get().UnregisterPreSubmitFilesValidation();
	ISourceControlModule::Get().RegisterPreSubmitFilesValidation(
		FSourceControlPreSubmitFilesValidationDelegate::CreateRaw(
			this, &FDiversionProvider::PreFilesValidationDelegateWrapper
		)
	);
	ISourceControlModule::Get().UnregisterPreSubmitChangelistValidation();
	ISourceControlModule::Get().RegisterPreSubmitChangelistValidation(
#else
	ISourceControlModule::Get().UnregisterPreSubmitDataValidation();
	ISourceControlModule::Get().RegisterPreSubmitDataValidation(
#endif
		FSourceControlPreSubmitDataValidationDelegate::CreateRaw(
			this, &FDiversionProvider::PreChangelistValidationDelegateWrapper
		)
	);
}

void FDiversionProvider::UnregisterAndRestorePreSubmitValidationDelegates()
{
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
	ISourceControlModule::Get().UnregisterPreSubmitChangelistValidation();
	ISourceControlModule::Get().UnregisterPreSubmitFilesValidation();

	// Restore original delegates only if not shutting down the editor
	// (to avoid dangling delegate if original owner is already destroyed)
	if (!IsEngineExitRequested())
	{
		if (OriginalPreChangelistValidationDelegate.IsBound())
		{
			ISourceControlModule::Get().RegisterPreSubmitChangelistValidation(OriginalPreChangelistValidationDelegate);
		}
		if (OriginalPreFilesValidationDelegate.IsBound())
		{
			ISourceControlModule::Get().RegisterPreSubmitFilesValidation(OriginalPreFilesValidationDelegate);
		}
	}
#else
	ISourceControlModule::Get().UnregisterPreSubmitDataValidation();
	if (!IsEngineExitRequested() && OriginalPreChangelistValidationDelegate.IsBound())
	{
		ISourceControlModule::Get().RegisterPreSubmitDataValidation(OriginalPreChangelistValidationDelegate);
	}
#endif
}

void FDiversionProvider::PreChangelistValidationDelegateWrapper(
	FSourceControlChangelistPtr Changelist,
	EDataValidationResult& Result,
	TArray<FText>& ValidationErrors, TArray<FText>& ValidationWarnings)
{
    TArray<FString> FilesInChangeList;
    FilesInChangeList.Reserve(ChangelistState->Files.Num());
	for (const auto& File : ChangelistState->Files) {
		FilesInChangeList.Add(File->GetFilename());
	}

	TArray<TSharedRef<FDiversionState>> StatesToClean = PerformPreSubmitValidation(FilesInChangeList, Result, ValidationErrors, ValidationWarnings);

	OriginalPreChangelistValidationDelegate.ExecuteIfBound(Changelist, Result, ValidationErrors, ValidationWarnings);

	for (auto State : StatesToClean) {
		State->ClearOverrideDefaultCheckout();
	}
}

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
void FDiversionProvider::PreFilesValidationDelegateWrapper(
	TArray<FSourceControlStateRef>& InStates,
	EDataValidationResult& Result,
	TArray<FText>& ValidationErrors,
	TArray<FText>& ValidationWarnings)
{
	TArray<FString> FilePaths;
	FilePaths.Reserve(InStates.Num());
	for (const auto& State : InStates)
	{
		FilePaths.Add(State->GetFilename());
	}

	TArray<TSharedRef<FDiversionState>> StatesToClean = PerformPreSubmitValidation(FilePaths, Result, ValidationErrors, ValidationWarnings);
	OriginalPreFilesValidationDelegate.ExecuteIfBound(InStates, Result, ValidationErrors, ValidationWarnings);

	for (auto State : StatesToClean) {
		State->ClearOverrideDefaultCheckout();
	}
}
#endif

void FDiversionProvider::UpdateModifiedStates(const TMap<FString, TSharedRef<FDiversionState>>& InNewModifiedStates)
{
	for (auto& State : ModifiedStates) {
		if (!InNewModifiedStates.Contains(State.Key)) {
			State.Value->ResetState();
		}
	}
	// Reset the list of modified states only if we requested a full repo status update
	ModifiedStates = InNewModifiedStates;
	AddCurrentChangesToChangelistState();
}

void FDiversionProvider::OnApplicationFocusChanged(const bool bIsFocused)
{
	if (!IsInGameThread())
	{
		return;
	}

	if (bIsFocused && bDiversionAvailable)
	{
		if (BackgroundStatus)
		{
			BackgroundStatus->TriggerInstantCallAndReset();
		}
		if (BackgroundPotentialClashes)
		{
			BackgroundPotentialClashes->TriggerInstantCallAndReset();
		}
		if (BackgroundConflictedFiles)
		{
			BackgroundConflictedFiles->TriggerInstantCallAndReset();
		}
	}
}

bool FDiversionProvider::IsPackageExpired(const FSyncInaccessiblePackages& SyncInaccessiblePackage) const
{
	return FDateTime::Now() - SyncInaccessiblePackage.LockTime > SyncInaccessiblePackageRefreshTime;
}

bool FDiversionProvider::UpdateCachedStates(const TMap<FString, FDiversionState>& InNewStates, const bool IsFullStatusUpdate)
{
	int NbStatesUpdated = 0;
	TMap<FString, TSharedRef<FDiversionState>> NewModifiedStates;
	
	// Update the local cached states
	for (const auto& [_, NewStateValue] : InNewStates)
	{
		const TSharedRef<FDiversionState> CachedState = GetStateInternal(NewStateValue.LocalFilename);
		CachedState->WorkingCopyState = NewStateValue.WorkingCopyState;
		CachedState->TimeStamp = NewStateValue.TimeStamp;
		if(NewStateValue.Hash != TEXT(""))
		{
			CachedState->Hash = NewStateValue.Hash;
		}
		NbStatesUpdated++;

		// State handling parts:
		// Used for modified states cache management
		// TODO: better explain this
		if(IsFullStatusUpdate)
		{
			if(CachedState->IsModified())
			{
				// Make sure to add only states that has active modifications
				NewModifiedStates.Add(CachedState->LocalFilename, CachedState);
			}
		}
	}

	// Handles updating the list of modified states and resetting
	// reverted previously modified states.
	// TODO: Fix the bug in UE level - part of AssetRegistry module
	if(IsFullStatusUpdate)
	{
		UpdateModifiedStates(NewModifiedStates);
		// Reset the caching interval timer to maintain the inetrval between calls to the BE 
		// Note - This doesn't affect calls generated by UE!
	}

	// Remove synching from states if necessary
	if (SyncStatus.Get() == DiversionUtils::EDiversionWsSyncStatus::Completed)
	{
		for (auto& State : SynchingStates)
		{
			State.Value->IsSyncing = false;
		}
	}

	BackgroundStatusSkipToNextInterval();
	return (NbStatesUpdated > 0);
}

bool FDiversionProvider::UpdateConflictedStates(const TMap<FString, FDiversionResolveInfo>& ConflictedFilesData)
{
	int NbStatesUpdated = 0;

	// Reset the states data
	for(auto& [_, State] : ConflictedStates)
	{
		State->ClearResolveInfo();
	}
	ConflictedStates.Empty();
	
	// Update the conflicted states
	for(auto& [FilePath, ResolveInfo] : ConflictedFilesData)
	{
		const TSharedRef<FDiversionState> CachedState = GetStateInternal(FilePath);
		CachedState->AddPendingResolveInfo(ResolveInfo);
		ConflictedStates.Add(FilePath, CachedState);
		NbStatesUpdated++;
	}

	return (NbStatesUpdated > 0);
}

bool FDiversionProvider::RemoveConflictedState(const FString& Path)
{
	auto ConflictedState = ConflictedStates.Find(Path);
	if(ConflictedState == nullptr)
	{
		return false;
	}
	ConflictedState->Get().ClearResolveInfo();
	return ConflictedStates.Remove(Path) > 0;
}

TUniquePtr<FDiversionResolveInfo> FDiversionProvider::GetFileResolveInfo(const FString& Path) const
{
	if(const auto* ResolveInfo = ConflictedStates.Find(Path); ResolveInfo != nullptr)
	{
		return MakeUnique<FDiversionResolveInfo>(ResolveInfo->Get().GetPendingResolveInfo());
	}
	return nullptr;
}

void FDiversionProvider::GetConflictedFilesPaths(TArray<FString>& OutArray) const
{
	return ConflictedStates.GenerateKeyArray(OutArray);
}

void FDiversionProvider::SetFilesToResolve(const TMap<FString, FDiversionResolveInfo>& InFilesToResolve)
{
    FilesToResolve = InFilesToResolve;
}

bool FDiversionProvider::UpdatePotentialClashedStates(
	const TMap<FString, TArray<EDiversionPotentialClashInfo>>& InPotentialClashes,
	bool IsFullStatusUpdate)
{
	
	check(IsInGameThread());

	int NbStatesUpdated = 0;

	// Clear potential clashes cache only if we perform a full status update
	if(IsFullStatusUpdate)
	{
		TArray<FString> KeysToRemove;
		// Reset the potential clashes that are no longer in the list
		for(auto& [FileName, State] : PotentiallyClashedStates)
		{
			if(!InPotentialClashes.Contains(FileName))
			{
				State->PotentialClashes.ResetPotentialClashes();
				KeysToRemove.Add(FileName);
			}
			NbStatesUpdated++;
		}
		
		// Remove the keys that are no longer in the list
		for(const auto& Key : KeysToRemove)
		{
			PotentiallyClashedStates.Remove(Key);
		}
	}
	
	// Update existing states or add new ones
	for(const auto& [Filename, PotentialClashInfo] : InPotentialClashes)
	{
		if(const auto* CachedState = PotentiallyClashedStates.Find(Filename); CachedState != nullptr)
		{
			(*CachedState)->PotentialClashes.SetPotentialClashes(PotentialClashInfo);
		}
		else
		{
			TSharedRef<FDiversionState> NewCachedState = GetStateInternal(Filename);
			NewCachedState->PotentialClashes.SetPotentialClashes(PotentialClashInfo);
			PotentiallyClashedStates.Add(Filename, NewCachedState);
		}
		NbStatesUpdated++;
	}
	
	return (NbStatesUpdated > 0);
}

void FDiversionProvider::GetCurrentPotentialClashes(TArray<FString>& OutPotentialClashedPaths) const
{
	PotentiallyClashedStates.GetKeys(OutPotentialClashedPaths);
}

TSharedRef<FDiversionState, ESPMode::ThreadSafe> FDiversionProvider::GetStateInternal(const FString& Filename)
{
	TSharedRef<FDiversionState, ESPMode::ThreadSafe>* State = StateCache.Find(Filename);
	if (State != NULL)
	{
		// found cached item
		return (*State);
	}
	else
	{
		// cache an unknown state for this item
		TSharedRef<FDiversionState, ESPMode::ThreadSafe> NewState = MakeShareable(new FDiversionState(Filename));
		StateCache.Add(Filename, NewState);
		return NewState;
	}
}

void FDiversionProvider::AddSyncingState(const FString& Path, const TSharedRef<class FDiversionState>& InState)
{
	SynchingStates.Add(Path, InState);
}

ECommandResult::Type FDiversionProvider::GetState(const TArray<FSourceControlChangelistRef>& InChangelists, TArray<FSourceControlChangelistStateRef>& OutState, EStateCacheUsage::Type InStateCacheUsage)
{
	if (!IsEnabled())
	{
		return ECommandResult::Failed;
	}
	OutState.Add(ChangelistState);
	
	return ECommandResult::Succeeded;
}

bool IsConfigFile(const FString& FilePath)
{
	// Check if the file has an .ini extension
	if (!FilePath.EndsWith(TEXT(".ini")))
	{
		return false;
	}

	// Get the path to the project's Config directory
	FString ConfigDir = FPaths::ConvertRelativePathToFull(FPaths::ProjectConfigDir());

	// Check if FilePath starts with the project's Config directory path
	if (FilePath.StartsWith(ConfigDir))
	{
		return true;
	}

	return false;
}

TArray<FSourceControlStateRef> FDiversionProvider::GetCachedStateByPredicate(TFunctionRef<bool(const FSourceControlStateRef&)> Predicate) const
{
	TArray<FSourceControlStateRef> Result;
	for (const auto& CacheItem : StateCache)
	{
		FSourceControlStateRef State = CacheItem.Value;

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 6
		// In 5.6+ we use our own commit flow (FDiversionCommitHelper) which gathers
		// ALL files (packages and config) directly from the cache. No filtering needed
		// here since GatherCommittableFiles handles deduplication and categorization.
		if (Predicate(State))
		{
			Result.Add(State);
		}
#else
		// In older versions, UE's ChoosePackagesToCheckIn flow causes duplicate files
		// when using custom projects - config files are returned both by
		// FindAllSubmittableProjectFiles (via GetCachedStateByPredicate) and
		// FindAllSubmittableConfigFiles (via GetState). Filter them here to avoid duplicates.
		if (Predicate(State) && !IsConfigFile(State->GetFilename()))
		{
			Result.Add(State);
		}
#endif
	}
	return Result;
}

bool FDiversionProvider::RemoveFileFromCache(const FString& Filename)
{
	return StateCache.Remove(Filename) > 0;
}


FDelegateHandle FDiversionProvider::RegisterSourceControlStateChanged_Handle(const FSourceControlStateChanged::FDelegate& SourceControlStateChanged)
{
	return OnSourceControlStateChanged.Add(SourceControlStateChanged);
}

void FDiversionProvider::UnregisterSourceControlStateChanged_Handle(FDelegateHandle Handle)
{
	OnSourceControlStateChanged.Remove(Handle);
}

ECommandResult::Type FDiversionProvider::Execute(const FSourceControlOperationRef& InOperation, FSourceControlChangelistPtr InChangelist, const TArray<FString>& InFiles, EConcurrency::Type InConcurrency, const FSourceControlOperationComplete& InOperationCompleteDelegate)
{
	if (bDiversionStopped) {
		return ECommandResult::Failed;
	}

	// Workers/Commands must not call to other workers/commands and to this command directly!
	// Workers should call directly to the SyncAPI methods and update the provider state accordingly
	if (!DiversionUtils::DiversionValidityCheck(IsInGameThread(),
		"Provider Execute called outside of main thread", FDiversionModule::Get().GetOriginalAccountID())) {
		return ECommandResult::Failed;
	}

	if (!IsEnabled() && !(CanExecuteBeforeEnabled.Contains(InOperation->GetName())))
	{
		// Note that IsEnabled() always returns true so unless it is changed, this code will never be executed
		InOperationCompleteDelegate.ExecuteIfBound(InOperation, ECommandResult::Failed);
		return ECommandResult::Failed;
	}

	TArray<FString> AbsoluteFiles = SourceControlHelpers::AbsoluteFilenames(InFiles);

	// Query to see if we allow this operation
	TSharedPtr<IDiversionWorker, ESPMode::ThreadSafe> Worker = CreateWorker(InOperation->GetName());
	if (!Worker.IsValid())
	{
		// this operation is unsupported by this version control provider
		FFormatNamedArguments Arguments;
		Arguments.Add(TEXT("OperationName"), FText::FromName(InOperation->GetName()));
		Arguments.Add(TEXT("ProviderName"), FText::FromName(GetName()));
		FText Message(FText::Format(LOCTEXT("UnsupportedOperation", "Operation '{OperationName}' not supported by revision control provider '{ProviderName}'"), Arguments));
		FMessageLog("SourceControl").Error(Message);
		InOperation->AddErrorMessge(Message);

		InOperationCompleteDelegate.ExecuteIfBound(InOperation, ECommandResult::Failed);
		return ECommandResult::Failed;
	}

	FDiversionCommand* Command = new FDiversionCommand(InOperation, Worker.ToSharedRef(), InConcurrency);
	Command->Files = AbsoluteFiles;
	Command->OperationCompleteDelegate = InOperationCompleteDelegate;

	// fire off operation
	if (InConcurrency == EConcurrency::Synchronous)
	{
		Command->bAutoDelete = false;
		return ExecuteSynchronousCommand(*Command, InOperation->GetInProgressString());
	}
	else
	{
		Command->bAutoDelete = true;
		return IssueCommand(*Command);
	}
}

bool FDiversionProvider::CanExecuteOperation(const FSourceControlOperationRef& InOperation) const
{
	return WorkersMap.Find(InOperation->GetName()) != nullptr;
}

bool FDiversionProvider::CanCancelOperation(const FSourceControlOperationRef& InOperation) const
{
	return false;
}

void FDiversionProvider::CancelOperation(const FSourceControlOperationRef& InOperation)
{
}

bool FDiversionProvider::UsesLocalReadOnlyState() const
{
	return false;
}

bool FDiversionProvider::UsesChangelists() const
{
	if (bOverrideUsesChangelists)
	{
		return false;
	}
	return true;
}

bool FDiversionProvider::UsesUncontrolledChangelists() const
{
	return false;
}

bool FDiversionProvider::UsesCheckout() const
{
	return false;
}

bool FDiversionProvider::UsesFileRevisions() const
{
	return false;
}

bool FDiversionProvider::UsesSnapshots() const
{
	return false;
}

bool FDiversionProvider::AllowsDiffAgainstDepot() const
{
	return true;
}

TOptional<bool> FDiversionProvider::IsAtLatestRevision() const
{
	return TOptional<bool>();
}

TOptional<int> FDiversionProvider::GetNumLocalChanges() const
{
	if(GetSyncStatus() == DiversionUtils::EDiversionWsSyncStatus::Completed)
	{
		return TOptional<int>(ModifiedStates.Num());
	} else
	{
		return TOptional<int>(0);
	}
}

TSharedRef<SWidget> FDiversionProvider::OnGenerateAssetViewPotentialClashIcon(const FAssetData& AssetData) {
	return SNew(SPotentialClashIndicator).AssetPath(
		DiversionUtils::GetFilePathFromAssetData(AssetData)
	);
}

TSharedRef<SWidget> FDiversionProvider::OnGenerateAssetViewPotentialClashTooltip(const FAssetData& AssetData)
{
	return SNew(SPotentialClashTooltip).AssetPath(
		DiversionUtils::GetFilePathFromAssetData(AssetData)
	);
}

TSharedPtr<IDiversionWorker, ESPMode::ThreadSafe> FDiversionProvider::CreateWorker(const FName& InOperationName) const
{
	const FGetDiversionWorker* Operation = WorkersMap.Find(InOperationName);
	if (Operation != nullptr)
	{
		return Operation->Execute();
	}

	return nullptr;
}

void FDiversionProvider::RegisterWorker(const FName& InName, const FGetDiversionWorker& InDelegate)
{
	WorkersMap.Add(InName, InDelegate);
}

void FDiversionProvider::OutputCommandMessages(const FDiversionCommand& InCommand)
{
	FMessageLog SourceControlLog("SourceControl");

	for (int32 ErrorIndex = 0; ErrorIndex < InCommand.ErrorMessages.Num(); ++ErrorIndex)
	{
		SourceControlLog.Error(FText::FromString(InCommand.ErrorMessages[ErrorIndex]));
	}

	for (int32 InfoIndex = 0; InfoIndex < InCommand.InfoMessages.Num(); ++InfoIndex)
	{
		SourceControlLog.Info(FText::FromString(InCommand.InfoMessages[InfoIndex]));
	}

	if(InCommand.PopupNotification.IsValid())
	{
		NotificationManager.ShowNotification(*(InCommand.PopupNotification));
	}
}

void FDiversionProvider::Tick()
{

	// Revalidate the agent status and WsInfo
	IsAgentAlive(EConcurrency::Asynchronous, ReloadStatusRequired);
	GetWsInfo(EConcurrency::Asynchronous, ReloadStatusRequired);
	if(ReloadStatusRequired)
	{
		ReloadStatusRequired = false;
	}

	bool bStatesUpdated = false;
	for (int32 CommandIndex = 0; CommandIndex < CommandQueue.Num(); ++CommandIndex)
	{
		FDiversionCommand& Command = *CommandQueue[CommandIndex];
		if (Command.bExecuteProcessed)
		{
			// Remove command from the queue
			CommandQueue.RemoveAt(CommandIndex);

			// let command update the states of any files
			bStatesUpdated |= Command.Worker->UpdateStates();

			// dump any messages to output log
			OutputCommandMessages(Command);

			Command.ReturnResults();

			// commands that are left in the array during a tick need to be deleted
			if (Command.bAutoDelete)
			{
				// Only delete commands that are not running 'synchronously'
				delete &Command;
			}

			// only do one command per tick loop, as we don't want concurrent modification
			// of the command queue (which can happen in the completion delegate)
			break;
		}
	}

	if (bStatesUpdated)
	{
		OnSourceControlStateChanged.Broadcast();
	}
}

TArray< TSharedRef<ISourceControlLabel> > FDiversionProvider::GetLabels(const FString& InMatchingSpec) const
{
	TArray< TSharedRef<ISourceControlLabel> > Tags;

	return Tags;
}

TArray<FSourceControlChangelistRef> FDiversionProvider::GetChangelists(EStateCacheUsage::Type InStateCacheUsage)
{
	return TArray<FSourceControlChangelistRef>();
}

#if SOURCE_CONTROL_WITH_SLATE
TSharedRef<class SWidget> FDiversionProvider::MakeSettingsWidget() const
{
	return SNew(SDiversionSettings);
}
#endif

ECommandResult::Type FDiversionProvider::ExecuteSynchronousCommand(FDiversionCommand& InCommand, const FText& Task)
{
	ECommandResult::Type Result = ECommandResult::Failed;

	// Display the progress dialog if a string was provided
	{
		FScopedSourceControlProgress Progress(Task);

		// Issue the command asynchronously...
		IssueCommand(InCommand);

		// ... then wait for its completion (thus making it synchronous)
		while (!InCommand.bExecuteProcessed)
		{
			// Tick the command queue and update progress.
			Tick();

			Progress.Tick();

			// Sleep for a bit so we don't busy-wait so much.
			FPlatformProcess::Sleep(0.01f);
		}

		// always do one more Tick() to make sure the command queue is cleaned up.
		Tick();

		if (InCommand.bCommandSuccessful)
		{
			Result = ECommandResult::Succeeded;
		}
	}

	// Delete the command now (asynchronous commands are deleted in the Tick() method)
	if (!DiversionUtils::DiversionValidityCheck(!InCommand.bAutoDelete,
		"InCommand was configures to execute synchronously with auto delete on", WsInfo.Get().AccountID)) {
		return Result;
	}

	// ensure commands that are not auto deleted do not end up in the command queue
	if (CommandQueue.Contains(&InCommand))
	{
		CommandQueue.Remove(&InCommand);
	}
	delete &InCommand;

	return Result;
}

ECommandResult::Type FDiversionProvider::IssueCommand(FDiversionCommand& InCommand)
{
	if (GThreadPool != nullptr && CommandQueue.Num() < GThreadPool->GetNumThreads())
	{
		// Queue this to our worker thread(s) for resolving
		GThreadPool->AddQueuedWork(&InCommand);
		CommandQueue.Add(&InCommand);
		return ECommandResult::Succeeded;
	}
	else
	{
		FText Message(
            FText::Format(LOCTEXT("NoSCCThreads", "There are no threads available to process the revision control command: {0}."), FText::FromName(InCommand.Worker->GetName()))
		);
		FMessageLog("SourceControl").Error(Message);
		InCommand.Operation->AddErrorMessge(Message);
		UE_LOG(LogSourceControl, Error, TEXT("There are no threads available to process the revision control command: %s."), *(InCommand.Worker->GetName().ToString()));
		
		int availableThreads = (GThreadPool != nullptr) ? GThreadPool->GetNumThreads() : 0;
		UE_LOG(LogSourceControl, Error, TEXT("There are currently %d active worker threads out of: %d"), CommandQueue.Num(), availableThreads);
		for (auto& cmd : CommandQueue) {
			UE_LOG(LogSourceControl, Error, TEXT("% s"), *(cmd->Worker->GetName().ToString()));
		}

		InCommand.MarkOperationCompleted(false);
		return ECommandResult::Cancelled;
	}
}

void RemoveCallbackRestoreAfterFileFinishedSyncing(const FString& RestoreDestPath, int DirectoryWatcherHandleIndex)
{
	auto& Provider = FDiversionModule::Get().GetProvider();
	FDelegateHandle DirectoryWatcherHandle = Provider.GetRestoreAfterSyncDelegateHandle(DirectoryWatcherHandleIndex);
	if (DirectoryWatcherHandle.IsValid() && FModuleManager::Get().IsModuleLoaded("DirectoryWatcher"))
	{
		IDirectoryWatcher* DirectoryWatcher = FModuleManager::LoadModuleChecked<FDirectoryWatcherModule>("DirectoryWatcher").Get();
		FString DirectoryPath = FPaths::GetPath(RestoreDestPath);
		DirectoryWatcher->UnregisterDirectoryChangedCallback_Handle(DirectoryPath, DirectoryWatcherHandle);
		Provider.RemoveRestoreAfterSyncDelegateHandle(DirectoryWatcherHandleIndex);
	}
}

void RestoreFileAfterSync(const FString& RestoreDestPath,
	int DirectoryWatcherHandleIndex, const TArray<FFileChangeData>& FileChanges)
{
	FString NormalizedRestoreDestPath = RestoreDestPath.Replace(TEXT("\\"), TEXT("/"));
	for (const FFileChangeData& Change : FileChanges)
	{
		FString NormalizedChangePath = Change.Filename.Replace(TEXT("\\"), TEXT("/"));
		if (NormalizedChangePath.Equals(NormalizedRestoreDestPath) && Change.Action == FFileChangeData::FCA_Modified)
		{
			try {
				auto* LoadPackage = DiversionUtils::UPackageUtils::PackageFromPath(NormalizedChangePath);
				UPackageTools::ReloadPackages({ LoadPackage });
			}
			catch (const std::exception& e) {
				UE_LOG(LogSourceControl, Error, TEXT("Failed to reload package: %s"), *FString(e.what()));
			}

			UE_LOG(LogSourceControl, Display, TEXT("Detected modification of %s and restored unsaved changes."), *RestoreDestPath);
			// Unregister the callback after the file has been restored
			RemoveCallbackRestoreAfterFileFinishedSyncing(RestoreDestPath, DirectoryWatcherHandleIndex);
			return;
		}
	}
}

void RegisterCallbackRestoreAfterFileFinishedSyncing(const FString& PackagePath)
{
	if (FModuleManager::Get().IsModuleLoaded("DirectoryWatcher"))
	{
		auto& Provider = FDiversionModule::Get().GetProvider();
		int DirectoryWatcherHandleIndex = Provider.AddRestoreAfterSyncDelegateHandle();
		IDirectoryWatcher* DirectoryWatcher = FModuleManager::LoadModuleChecked<FDirectoryWatcherModule>("DirectoryWatcher").Get();
		FString DirectoryPath = FPaths::GetPath(PackagePath);
		DirectoryWatcher->RegisterDirectoryChangedCallback_Handle(
			DirectoryPath,
			// The actual callback that will be called when the file is modified
			// It will also unregister its delegate handle after the file has been restored
			IDirectoryWatcher::FDirectoryChanged::CreateLambda([PackagePath, DirectoryWatcherHandleIndex](const TArray<FFileChangeData>& FileChanges)
				{
					RestoreFileAfterSync(PackagePath, DirectoryWatcherHandleIndex, FileChanges);
				}),
			Provider.GetRestoreAfterSyncDelegateHandle(DirectoryWatcherHandleIndex));

		UE_LOG(LogTemp, Display, TEXT("Started monitoring directory: %s"), *DirectoryPath);
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("DirectoryWatcher module is not loaded, cannot monitor file changes"));
	}
}

void FDiversionProvider::OnPrePackageSave(UPackage* Package, FObjectPreSaveContext SaveContext)
{
	const FString FileName = FPaths::ConvertRelativePathToFull(SaveContext.GetTargetFilename());

#if PLATFORM_WINDOWS
	const FString OSNormalizedFileName = FileName.Replace(TEXT("/"), TEXT("\\"));
#else
	const FString OSNormalizedFileName = FileName;
#endif
	if (GetSyncInaccessiblePackages(OSNormalizedFileName)) {
		// Handling saving local-remote conflicted files
		// It's should be safe to assume that if we're saving a loaded file it 
		// means we will have conflicts against the remote version
		FText OnSaveLoadedPAckageMessage = FText::Format(
			LOCTEXT("DiversionLockedFiles_OnSaveMessage",
				"The file \"{0}\" has been updated in the cloud repo."
				"To protect your unsaved local changes, Diversion created a backup copy with a `_resolved` postfix."
				"This backup allows you to compare your changes with the incoming version."),
			FText::FromString(FileName));

		FDiversionNotification PopUpNotification(
			OnSaveLoadedPAckageMessage,
			TArray<FNotificationButtonInfo>(),
			SNotificationItem::CS_Fail);
		NotificationManager.ShowNotification(PopUpNotification);
		RegisterCallbackRestoreAfterFileFinishedSyncing(OSNormalizedFileName);
		if (!DiversionUtils::UPackageUtils::BackupUnsavedChanges(Package)) {
			// Fallback to simple OS file copy -- Note, this makes the package undetectable by UE!
			// To use it you'll need to rename it back to the originals file name (overriding the exitsing asset).
			// This should be used only as a last resort if copying the package with UE asset tools failed.
			DiversionUtils::UPackageUtils::MakeSimpleOSCopyPackageBackup(OSNormalizedFileName, FPaths::GetPath(OSNormalizedFileName));
		}

		if (DiversionUtils::UPackageUtils::IsPackageOpenedInEditor(Package->GetName())) {
			DiversionUtils::UPackageUtils::ClosePackageEditor(Package);
		}
		Package->SetDirtyFlag(false);
		RemoveSyncInaccessiblePackage(OSNormalizedFileName);
	}
}

void FDiversionProvider::OnPackageSave(const FString& PackageFileName, UObject*)
{
	const FString FileName = FPaths::ConvertRelativePathToFull(PackageFileName);

	// After a file resolve operation is called, after the file was saved we need to
	// trigger a Diversion Resolve operation on it
	// If we left with 0 files to resolve, we can finalize the merge
	if (const auto FileResolveInfo = FilesToResolve.Find(FileName))
	{
		FString MergeId = FileResolveInfo->MergeId;
		auto ResolveFileOperation = ISourceControlOperation::Create<FResolveFile>();
		ResolveFileOperation->SetMergeID(MergeId);
		ResolveFileOperation->SetConflictID(FileResolveInfo->ConflictId);
		Execute(ResolveFileOperation, nullptr, {FileName}, EConcurrency::Synchronous);

		FilesToResolve.Remove(FileName);
		// We will revert the change only after finalizing the merge to avoid losing the changes
		FilesToRevert.Add(FileName);

		if (ConflictedStates.Num() + FilesToResolve.Num() == 0)
		{
			// Run finalize merge and wait for it to finish
			auto FinalizeMergeOperation = ISourceControlOperation::Create<FFinalizeMerge>();
			FinalizeMergeOperation->SetMergeID(MergeId);
			Execute(FinalizeMergeOperation, nullptr, {}, EConcurrency::Synchronous,
			FSourceControlOperationComplete::CreateLambda([this](const FSourceControlOperationRef&, ECommandResult::Type InResult) {
				if (InResult == ECommandResult::Succeeded)
				{
					// Reset the workspace to avoid showing wrong changes - We committed them in the merge already
					Execute(ISourceControlOperation::Create<FRevert>(), nullptr,
						FilesToRevert, EConcurrency::Synchronous);
				}
			}));
		}
	}
}

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 4
void FDiversionProvider::OnPackageSaveWithContext(const FString& PackageFileName, UPackage* Package, FObjectPostSaveContext ObjectSaveContext)
{
	// UE 5.4+ version - delegate to the existing implementation
	// Explicitly mark unused parameters
	(void)Package;
	(void)ObjectSaveContext;
	OnPackageSave(PackageFileName, nullptr);
}
#endif

void FDiversionProvider::RemoveRestoreAfterSyncDelegateHandle(int DelegateHandleIndex)
{
	DirectoryWatcherHandles.RemoveAtSwap(DelegateHandleIndex);
}

bool FDiversionProvider::ReleaseLockedPackage(UPackage* Package, const FString& PackagePath)
{
	UE_LOG(LogSourceControl, Warning,
	       TEXT("'%s' possibly opened by UE, attempting to close it to continue Diversion agent syncing"),
	       *PackagePath);
	if (UPackageTools::UnloadPackages({ Package }))
	{
		RemoveSyncInaccessiblePackage(PackagePath);
		UE_LOG(LogSourceControl, Display, TEXT("Successfully unloaded package: '%s'"), *PackagePath);
		return true;
	}
		
	UE_LOG(LogSourceControl, Warning,
	       TEXT("Failed to unload the opened package: '%s', make sure the file is not being edited somewhere else, "
		       "is not 'readonly' and you have the permissions to edit it."), *PackagePath);
	return false;
}

void FDiversionProvider::HandleUnsavedPackage(UPackage* Package, const FString& PackagePath, const FString& PackageName)
{
	// Notify only if the package isn't in the SyncInaccessiblePackages list
	if (GetSyncInaccessiblePackages(PackagePath))
	{
		return;
	}
	
	FNotificationButtonInfo KeepChangesButton(LOCTEXT("DiversionPopup_BackupMineButton", "Backup"),
		LOCTEXT("DiversionPopup_BackupMineButton_Tooltip", 
			"Save a copy of your current changes to a new file with a `_resolved` postfix. The package will be closed, and both versions can be opened from the drawer for comparison."),
		FSimpleDelegate::CreateLambda([Package, PackagePath]() {
			if (!DiversionUtils::UPackageUtils::BackupUnsavedChanges(Package)) {
				// Fallback to simple OS file copy -- Note, this makes the package undetectable by UE!
				// To use it you'll need to rename it back to the originals file name (overriding the exitsing asset).
				// This should be used only as a last resort if copying the package with UE asset tools failed.
				DiversionUtils::UPackageUtils::MakeSimpleOSCopyPackageBackup(PackagePath, FPaths::GetPath(PackagePath));
			}
			RegisterCallbackRestoreAfterFileFinishedSyncing(PackagePath);

			// Actions needed to resume the synching
			Package->SetDirtyFlag(false);
			DiversionUtils::UPackageUtils::ClosePackageEditor(Package);
	}),SNotificationItem::CS_Pending);
	
	FNotificationButtonInfo DiscardChangesButton(LOCTEXT("DiversionPopup_AcceptIncomingButton", "Accept incoming"),
	LOCTEXT("DiversionPopup_AcceptIncomingButton_Tooltip", "Discard your local changes and update the package with the latest version from the cloud."),
	FSimpleDelegate::CreateLambda([Package](){
		// Actions needed to resume the synching
		Package->SetDirtyFlag(false);
		DiversionUtils::UPackageUtils::ClosePackageEditor(Package);
	}),SNotificationItem::CS_Pending);

	FText UnsavedChangesMessage = FText::Format(
		LOCTEXT("LockedFiles_UnsavedMessage",
				"The package \"{0}\" has been updated in the cloud repo." 
			    "To protect your unsaved local changes, you can create a backup copy with a `_recovered` suffix."
			    "This backup allows you to compare your changes with the incoming version."
			    "Otherwise, your local changes will be overwritten by the update."),
		FText::FromString(PackageName));
		
	FDiversionNotification PopUpNotification(
		UnsavedChangesMessage,
		TArray<FNotificationButtonInfo>({KeepChangesButton, DiscardChangesButton}),
		SNotificationItem::CS_Pending
	);

	AddAndNotifySyncInaccessiblePackage(PackagePath, PopUpNotification);
	UE_LOG(LogSourceControl, Warning, TEXT("%s"), *UnsavedChangesMessage.ToString());
}

void FDiversionProvider::HandleOpenedInEditorPackage(UPackage* Package, const FString& PackagePath, const FString& PackageName)
{
	// Notify only if the package isn't in the SyncInaccessiblePackages list
	if (GetSyncInaccessiblePackages(PackagePath))
	{
		return;
	}

	FNotificationButtonInfo CloseButton(LOCTEXT("DiversionPopup_ClosePackageButton", "Close tabs"),
	                                    LOCTEXT("DiversionPopup_ClosePackageButton_Tooltip", "Close the package opened editor tabs to continue syncing"),
	                                    FSimpleDelegate::CreateLambda([Package]()
	                                    {
		                                    DiversionUtils::UPackageUtils::ClosePackageEditor(Package);
	                                    }),
	                                    SNotificationItem::CS_Pending);
	FText OpenedChangesMessage =  FText::Format(
		LOCTEXT("LockedFiles_OpenedMessage",
		        "'{0}' is currently opened in the editor view - Close it in order to continue synching"),
		FText::FromString(PackageName));

	FDiversionNotification PopUpNotification(
		OpenedChangesMessage,
		TArray<FNotificationButtonInfo>({CloseButton}),
		SNotificationItem::CS_Pending
	);
	AddAndNotifySyncInaccessiblePackage(PackagePath, PopUpNotification);
	UE_LOG(LogSourceControl, Warning, TEXT("%s"), *OpenedChangesMessage.ToString());
}

void FDiversionProvider::AddAndNotifySyncInaccessiblePackage(const FString& Path, const FDiversionNotification& InNotificationInfo)
{
	FDiversionNotificationManager::FNotificationId NotificationId = NotificationManager.ShowNotification(InNotificationInfo);
	SyncInaccessiblePackages.Add(Path, FSyncInaccessiblePackages({NotificationId, FDateTime::Now()}));
}

void FDiversionProvider::RemoveSyncInaccessiblePackage(const FString& PackagePath)
{
	if(FSyncInaccessiblePackages* SyncInaccessiblePackage = SyncInaccessiblePackages.Find(PackagePath))
	{
		NotificationManager.DismissNotification(SyncInaccessiblePackage->NotificationId);
		SyncInaccessiblePackages.Remove(PackagePath);
	}
}

bool FDiversionProvider::GetSyncInaccessiblePackages(const FString& PackagePath)
{
	if(FSyncInaccessiblePackages* SyncInaccessiblePackage = SyncInaccessiblePackages.Find(PackagePath))
	{
		// If the package has been locked for too long, remove it from the list
		if(IsPackageExpired(*SyncInaccessiblePackage))
		{
			NotificationManager.DismissNotification(SyncInaccessiblePackage->NotificationId);
			SyncInaccessiblePackages.Remove(PackagePath);
			return false;
		}
		return true;
	}
	return false;
}

bool FDiversionProvider::TryUnloadingOpenedPackage(const FString& InOpenedPackagePath)
{
	const FString PackageName = FPackageName::FilenameToLongPackageName(InOpenedPackagePath);
	UPackage* Package = DiversionUtils::UPackageUtils::PackageFromPath(InOpenedPackagePath);
	
	if (Package == nullptr)
	{
		UE_LOG(LogSourceControl, Warning, TEXT("'%s' is not a valid package, skipping unload"),
		       *InOpenedPackagePath);
		return false;
	}

	if (Package->IsDirty())
	{
		HandleUnsavedPackage(Package, InOpenedPackagePath, PackageName);
		return false;
	}

	if (DiversionUtils::UPackageUtils::IsPackageOpenedInEditor(PackageName)) {
		HandleOpenedInEditorPackage(Package, InOpenedPackagePath, PackageName);
		return false;
	}

	return ReleaseLockedPackage(Package, InOpenedPackagePath);
}

int FDiversionProvider::AddRestoreAfterSyncDelegateHandle()
{
	return DirectoryWatcherHandles.Add(FDelegateHandle());
}

FDelegateHandle& FDiversionProvider::GetRestoreAfterSyncDelegateHandle(int DelegateHandleIndex)
{
	return DirectoryWatcherHandles[DelegateHandleIndex];
}

void FDiversionProvider::InitializeUICommands()
{
	// Add to source control menu following the same pattern as existing Diversion menu
	const FToolMenuOwnerScoped SourceControlMenuOwner("DiversionCommitMenu");
	if (UToolMenu* SourceControlMenu = UToolMenus::Get()->ExtendMenu("StatusBar.ToolBar.SourceControl"))
	{
		if (SourceControlMenu) 
		{
			MenuSectionName = FName("DiversionActions");
			FToolMenuSection& Section = SourceControlMenu->AddSection(MenuSectionName, LOCTEXT("DiversionRevisionControlActions", "Diversion"), FToolMenuInsert(NAME_None, EToolMenuInsertType::First));
			Section.AddMenuEntry(
				"DiversionCommitChanges",
				LOCTEXT("DiversionCommitChanges", "Commit Changes"),
				LOCTEXT("DiversionCommitChangesTooltip", "Opens a dialog with check in options for content and levels."),
				FSlateIcon(FRevisionControlStyleManager::GetStyleSetName(), "RevisionControl.Actions.Submit"),
				FUIAction(
					FExecuteAction::CreateRaw(this, &FDiversionProvider::ExecuteCommitChanges),
					FCanExecuteAction::CreateRaw(this, &FDiversionProvider::CanExecuteCommitChanges)
				)
			);
			UE_LOG(LogSourceControl, Log, TEXT("Diversion: Added Commit Changes button to Source Control menu"));
		}
	}
}

void FDiversionProvider::ShutdownUICommands()
{
	// Remove our menu section during shutdown
	if (UToolMenus* ToolMenus = UToolMenus::Get())
	{
		if (UToolMenu* SourceControlMenu = ToolMenus->FindMenu("StatusBar.ToolBar.SourceControl"); SourceControlMenu && !MenuSectionName.IsNone())
		{
			SourceControlMenu->RemoveSection(MenuSectionName);
			UE_LOG(LogSourceControl, Log, TEXT("Diversion: Removed Commit Changes button from Source Control menu"));
		}
	}
}

void FDiversionProvider::ExecuteCommitChanges()
{
	// Use our custom commit flow that properly handles file gathering
	// without duplicates from GetCachedStateByPredicate
	FDiversionCommitHelper::ExecuteCommit();
}

bool FDiversionProvider::CanExecuteCommitChanges() const
{
	return FDiversionCommitHelper::CanExecuteCommit();
}

void FDiversionProvider::RegisterStatusBarWidget()
{
	UToolMenus::RegisterStartupCallback(FSimpleMulticastDelegate::FDelegate::CreateRaw(this, &FDiversionProvider::RegisterStatusBarMenus));
}

void FDiversionProvider::RegisterStatusBarMenus()
{
	const FToolMenuOwnerScoped OwnerScoped("DiversionStatusBarMenu");
	UToolMenus* TM = UToolMenus::Get();
	
	// Use the same toolbar path as Plastic SCM plugin
	if (UToolMenu* ToolbarMenu = TM->ExtendMenu("LevelEditor.StatusBar.ToolBar"))
	{
		// Insert before SourceControl like Plastic SCM does
		FToolMenuSection& Section = ToolbarMenu->AddSection("DiversionStatus", FText::GetEmpty(), FToolMenuInsert("SourceControl", EToolMenuInsertType::Before));
		
		Section.AddEntry(FToolMenuEntry::InitWidget(
			"DiversionStatusWidget",
			SAssignNew(StatusPanelWidget, SDiversionStatusPanel),
			FText::GetEmpty(), true, false
		));
	}
	else
	{
		UE_LOG(LogSourceControl, Warning, TEXT("Diversion: Could not find LevelEditor.StatusBar.ToolBar menu"));
	}
}

void FDiversionProvider::UnregisterStatusBarWidget()
{
	if (UToolMenus::IsToolMenuUIEnabled())
	{
		UToolMenus::Get()->UnregisterOwnerByName("DiversionStatusBarMenu"); // clean up our specific menu entries
	}
	StatusPanelWidget.Reset();
}

#undef LOCTEXT_NAMESPACE
