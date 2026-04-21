// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#pragma once
#include "DiversionState.h"
#include "DiversionWorkspaceInfo.h"
#include "ISourceControlProvider.h"
#include "IDiversionWorker.h"
#include "DiversionVersion.h"
#include "CachedState.h"
#include "DiversionChangelistState.h"
#include "DiversionTimedDelegate.h"
#include "DiversionNotificationManager.h"
#include "IDirectoryWatcher.h"

class FDiversionState;

class FDiversionCommand;

DECLARE_DELEGATE_RetVal(FDiversionWorkerRef, FGetDiversionWorker)


class FDiversionProvider : public ISourceControlProvider
{
public:
	FDiversionProvider() : DvVersion(FDiversionVersion(""), FTimespan::FromSeconds(3)),
	                       WsInfo(WorkspaceInfo(), FTimespan::FromSeconds(3)),
	                       SyncStatus(DiversionUtils::EDiversionWsSyncStatus::Paused, FTimespan::FromSeconds(1)),
						   bRepoWithSameNameExists(false, FTimespan::FromSeconds(15)),  // BE call - slow interval
						   bWorkspaceExistsInPath(false, FTimespan::FromSeconds(2)),
						   ChangelistState(MakeShared<FDiversionChangelistState>())
	{
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
		OriginalPreChangelistValidationDelegate = ISourceControlModule::Get().GetRegisteredPreSubmitChangelistValidation();
		OriginalPreFilesValidationDelegate = ISourceControlModule::Get().GetRegisteredPreSubmitFilesValidation();
#else
		OriginalPreChangelistValidationDelegate = ISourceControlModule::Get().GetRegisteredPreSubmitDataValidation();
#endif
	}

	/* ISourceControlProvider implementation */
	virtual void Init(bool bForceConnection = true) override;
	virtual void Close() override;
	virtual FText GetStatusText() const override;
	virtual TMap<EStatus, FString> GetStatus() const override;
	virtual bool IsEnabled() const override;
	virtual bool IsAvailable() const override;
	virtual const FName& GetName(void) const override;
	virtual bool QueryStateBranchConfig(const FString& ConfigSrc, const FString& ConfigDest) override { return false; }
	virtual void RegisterStateBranches(const TArray<FString>& BranchNames, const FString& ContentRoot) override {}
	virtual int32 GetStateBranchIndex(const FString& InBranchName) const override { return INDEX_NONE; }
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
	virtual bool GetStateBranchAtIndex(int32 BranchIndex, FString& OutBranchName) const override { return false; }
#endif
	virtual ECommandResult::Type GetState(const TArray<FString>& InFiles, TArray<FSourceControlStateRef>& OutState, EStateCacheUsage::Type InStateCacheUsage) override;
	virtual ECommandResult::Type GetState(const TArray<FSourceControlChangelistRef>& InChangelists, TArray<FSourceControlChangelistStateRef>& OutState, EStateCacheUsage::Type InStateCacheUsage) override;
	virtual TArray<FSourceControlStateRef> GetCachedStateByPredicate(TFunctionRef<bool(const FSourceControlStateRef&)> Predicate) const override;
	virtual FDelegateHandle RegisterSourceControlStateChanged_Handle(const FSourceControlStateChanged::FDelegate& SourceControlStateChanged) override;
	virtual void UnregisterSourceControlStateChanged_Handle(FDelegateHandle Handle) override;
	virtual ECommandResult::Type Execute(const FSourceControlOperationRef& InOperation, FSourceControlChangelistPtr InChangelist, const TArray<FString>& InFiles, EConcurrency::Type InConcurrency = EConcurrency::Synchronous, const FSourceControlOperationComplete& InOperationCompleteDelegate = FSourceControlOperationComplete()) override;
	virtual bool CanExecuteOperation(const FSourceControlOperationRef& InOperation) const override;
	virtual bool CanCancelOperation(const FSourceControlOperationRef& InOperation) const override;
	virtual void CancelOperation(const FSourceControlOperationRef& InOperation) override;
	virtual bool UsesLocalReadOnlyState() const override;
	virtual bool UsesChangelists() const override;
	virtual bool UsesUncontrolledChangelists() const override;
	virtual bool UsesCheckout() const override;
	virtual bool UsesFileRevisions() const override;
	virtual bool UsesSnapshots() const override;
	virtual bool AllowsDiffAgainstDepot() const override;
	virtual TOptional<bool> IsAtLatestRevision() const override;
	virtual TOptional<int> GetNumLocalChanges() const override;
	virtual void Tick() override;
	virtual TArray< TSharedRef<class ISourceControlLabel> > GetLabels(const FString& InMatchingSpec) const override;
	virtual TArray<FSourceControlChangelistRef> GetChangelists(EStateCacheUsage::Type InStateCacheUsage) override;
#if SOURCE_CONTROL_WITH_SLATE
	virtual TSharedRef<class SWidget> MakeSettingsWidget() const override;
	FString GetBranchId();
#endif

	using ISourceControlProvider::Execute;

	/**
	 * Check configuration, else standard paths, and run a Diversion "version" command to check the availability of the binary.
	 */
	bool CheckDiversionAvailability();

	/** Diversion version for feature checking */
	const FDiversionVersion& GetDiversionVersion(EConcurrency::Type Concurrency, bool InForceUpdate);
	const FDiversionVersion& GetDiversionVersion() const;

	bool IsAgentAlive(EConcurrency::Type Concurrency, bool InForceUpdate){
		return GetDiversionVersion(Concurrency, InForceUpdate).IsValid();
	}
	bool IsAgentAlive() const { return GetDiversionVersion().IsValid(); }


	WorkspaceInfo GetWsInfo(EConcurrency::Type Concurrency, bool InForceUpdate);
	WorkspaceInfo GetWsInfo() const;

	void SetDvVersion(const FDiversionVersion& InVersion);

	void SetWorkspaceInfo(const WorkspaceInfo& InWsInfo);

	DiversionUtils::EDiversionWsSyncStatus GetSyncStatus() const;
	void SetSyncStatus(const DiversionUtils::EDiversionWsSyncStatus& InSyncStatus);

	void SetReloadStatus() {
		ReloadStatusRequired = true;
	}

	const FString& GetPluginVersion() const
	{
		return PluginVersion;
	}

	bool IsRepoFound() const;

	/** Get the path to the root of the Diversion repository: can be the ProjectDir itself, or any parent directory */
	FString GetPathToWorkspaceRoot() const
	{
		return WsInfo.Get().GetPath();
	}

	/** Diversion config user.name */
	FString GetUserEmail() const
	{
		return WsInfo.Get().AccountID;
	}

	FString GetWorkspaceName() const
	{
		return WsInfo.Get().WorkspaceID;
	}

	FString GetRepositoryName() const
	{
		return WsInfo.Get().RepoName;
	}

	/**
	 * Register a worker with the provider.
	 * This is used internally so the provider can maintain a map of all available operations.
	 */
	void RegisterWorker(const FName& InName, const FGetDiversionWorker& InDelegate);

	/** Remove a named file from the state cache */
	bool RemoveFileFromCache(const FString& Filename);

	FString GetRepositoryId() const
	{
		return WsInfo.Get().RepoID;
	}

	FString GetWorkspacId() const
	{
		return WsInfo.Get().WorkspaceID;
	}

	void SetWorkspaceMergesList(const TArray<Diversion::CoreAPI::Model::Merge>& InList)
	{
		WorkspaceMergeList = InList;
	}

	const TArray<Diversion::CoreAPI::Model::Merge>& GetWorkspaceMergesList() const
	{
		return WorkspaceMergeList;
	}
	
	void SetBranchMergesList(const TArray<Diversion::CoreAPI::Model::Merge>& InList)
	{
		BranchMergeList = InList;
	}

	const TArray<Diversion::CoreAPI::Model::Merge>& GetBranchMergesList() const
	{
		return BranchMergeList;
	}

	void ShowNotification(const FDiversionNotification& Notification) {
		NotificationManager.ShowNotification(Notification);
	}

	/** Status panel status bar functionality */
	void RegisterStatusBarWidget();
	void RegisterStatusBarMenus();
	void UnregisterStatusBarWidget();

private:

#pragma region PotentialClashesUIExtension

	/** Delegate handle for the potential clash UI icon that was added to the AssetViewExtraStateGenerator */
	FDelegateHandle PotentialClashUIIconDelegateHandle;
	TSharedRef<SWidget> OnGenerateAssetViewPotentialClashIcon(const FAssetData& AssetData);
	TSharedRef<SWidget> OnGenerateAssetViewPotentialClashTooltip(const FAssetData& AssetData);

#pragma endregion

	/** Is dv binary found and working. */
	bool bDiversionAvailable = false;
	bool bDiversionStopped = false;

	/** Helper function for Execute() */
	TSharedPtr<class IDiversionWorker, ESPMode::ThreadSafe> CreateWorker(const FName& InOperationName) const;

	/** Helper function for running command synchronously. */
	ECommandResult::Type ExecuteSynchronousCommand(class FDiversionCommand& InCommand, const FText& Task);
	/** Issue a command asynchronously if possible. */
	ECommandResult::Type IssueCommand(class FDiversionCommand& InCommand);

	/** Output any messages this command holds */
	void OutputCommandMessages(const class FDiversionCommand& InCommand);

	/** Version of the Diversion plugin */
	FString PluginVersion;

	/** Diversion user email */
	FString UserEmail;

	bool ReloadStatusRequired = false;

	/** The currently registered version control operations */
	TMap<FName, FGetDiversionWorker> WorkersMap;

	/** Queue for commands given by the main thread */
	TArray<FDiversionCommand*> CommandQueue;

	/** For notifying when the version control states in the cache have changed */
	FSourceControlStateChanged OnSourceControlStateChanged;

	TCached<FDiversionVersion> DvVersion;
	TCached<WorkspaceInfo> WsInfo;
	TCached<DiversionUtils::EDiversionWsSyncStatus> SyncStatus;
	
	const TArray<FString> CanExecuteBeforeEnabled = {
		"Connect",
		"AgentHealthCheck",
		"GetWsInfo",
		"InitRepo",
		"SendAnalytics",
		"CheckIfWorkspaceExistsInPath",
		"CheckForRepoWithSameName"
	};

	/** Saves undismissed Diversion generated notifications */
	FDiversionNotificationManager NotificationManager;
// TODO: Make sure this is necessary 
public:
	TMap<FString, FDiversionResolveInfo> ConflictedFiles;
#pragma region MergeConflictsMembers
	TArray<Diversion::CoreAPI::Model::Merge> WorkspaceMergeList;
	TArray<Diversion::CoreAPI::Model::Merge> BranchMergeList;
	TMap<FString, FDiversionResolveInfo> FilesToResolve;
	TArray<FString> FilesToRevert;
	void OnPackageSave(const FString& PackageFileName, UObject* Outer);
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 4
	void OnPackageSaveWithContext(const FString& PackageFileName, UPackage* Package, FObjectPostSaveContext ObjectSaveContext);
#endif
	void OnPrePackageSave(UPackage*, FObjectPreSaveContext);
#pragma endregion

#pragma region UnrealOpenedFiles
	/**
	 * Fucntions and members for handling files opened(and FS-locked) by UE
	 * that diversion tries to sync incoming changes for.
	 */

public:
	bool TryUnloadingOpenedPackage(const FString& InOpenedPackagePath);

	// Functions to interact with the restoring files after sync delegates
	int AddRestoreAfterSyncDelegateHandle();
	FDelegateHandle& GetRestoreAfterSyncDelegateHandle(int DelegateHandleIndex);
	void RemoveRestoreAfterSyncDelegateHandle(int DelegateHandleIndex);
	
private:

	bool ReleaseLockedPackage(UPackage* Package, const FString& PackagePath);
	// Functions to handle unsaved packages
	void HandleUnsavedPackage(UPackage* Package, const FString& PackagePath, const FString& PackageName);
	TArray<FDelegateHandle> DirectoryWatcherHandles;

	// Function to handle opened in editor packages
	void HandleOpenedInEditorPackage(UPackage* Package, const FString& PackagePath, const FString& PackageName);

	// Adds a package to the list of packages that are locked by UE and are being synched by Diversion
	void AddAndNotifySyncInaccessiblePackage(const FString& Path, const FDiversionNotification& InNotificationInfo);
	void RemoveSyncInaccessiblePackage(const FString& Path);
	bool GetSyncInaccessiblePackages(const FString& PackagePath);
	
	struct FSyncInaccessiblePackages
	{
		FDiversionNotificationManager::FNotificationId NotificationId;
		FDateTime LockTime;
	};
	TMap<FString, FSyncInaccessiblePackages> SyncInaccessiblePackages;
	// Time to invalidate entries in SyncInaccessiblePackages
	const FTimespan SyncInaccessiblePackageRefreshTime = FTimespan::FromSeconds(30);
	bool IsPackageExpired(const FSyncInaccessiblePackages& SyncInaccessiblePackage) const;
#pragma endregion
	
#pragma region StatesCache
public:
	
	/**
	 * Helper function for various commands to update cached states.
	 * @param InNewStates - new states to update the cache with
	 * @param IsFullStatusUpdate - if true, this will clear the modified states cache
	 * @param InConflictedFiles - Conflicted paths to update the states of
	 * @returns true if any states were updated
	 */
	bool UpdateCachedStates(const TMap<FString, FDiversionState>& InNewStates, bool IsFullStatusUpdate);

	/**
	 * Updates the states with the conflicted data of current open merges.
	 * @param InConflictedFiles 
	 * @param IsFullStatusUpdate 
	 * @return True if any state was updated
	 */
	bool UpdateConflictedStates(const TMap<FString, FDiversionResolveInfo>& ConflictedFilesData);

	/**
	 * Helper function to remove a conflict data from a state in the cache.
	 * @param Path - Path of the file to remove the conflict data from
	 * @returns true if any states were updated
	 */
	bool RemoveConflictedState(const FString& Path);

	/**
	 * Retrieves the resolve information for a given file path.
	 * @param Path - The path of the file to get the resolve information for.
	 * @return The resolve information for the specified file.
	 */
	TUniquePtr<FDiversionResolveInfo> GetFileResolveInfo(const FString& Path) const;
	/**
	 * Helper function to get the paths values of conflicted files.
	 * @param OutArray - Array to fill with the conflicted files paths
	 */
	void GetConflictedFilesPaths(TArray<FString>& OutArray) const;
	
	void SetFilesToResolve(const TMap<FString, FDiversionResolveInfo>& InFilesToResolve);
	/**
	 * Helper function for various commands to update states with their potential clashes status.
	 * @param InPotentialClashes - Potential clashes to update the states with
	 *                             Will remove the potential clash info from local cache if its empty (Num==0).
	 * @returns true if any states were updated
	 */
	bool UpdatePotentialClashedStates(const TMap<FString, TArray<EDiversionPotentialClashInfo>>& InPotentialClashes,
		bool IsFullStatusUpdate);
	
	void GetCurrentPotentialClashes(TArray<FString>& OutPotentialClashedPaths) const;
	
	/** Helper function used to update state cache */
	TSharedRef<FDiversionState, ESPMode::ThreadSafe> GetStateInternal(const FString& Filename);

	/** Adds a state to the synching states cache */
	void AddSyncingState(const FString& Path, const TSharedRef<class FDiversionState>& InState);

// Background status triggering functions
	// Use when want to mark BG status as called and wait for next interval
	void BackgroundStatusSkipToNextInterval()
	{
		BackgroundStatus->SkipToNextInterval();
	}
	// Force trigger calling BG status on the next tick
	void BackgroundStatusTriggerInstantCall()
	{
		BackgroundStatus->TriggerInstantCallAndReset();
	}
//
	void BackgroundConflictedFilesSkipToNextInterval()
	{
		BackgroundConflictedFiles->SkipToNextInterval();
	}

private:
	/** Helper function for UpdateCachedStates. Updates the modified states cache.
	 * @param InNewModifiedStates - new states to update the cache with
	 */
	void UpdateModifiedStates(const TMap<FString, TSharedRef<FDiversionState>>& InNewModifiedStates);

	/** Adds a state to the modified states cache */
	void AddModifiedState(const TSharedRef<class FDiversionState>& InState);

	/** Called when the editor gains or loses focus */
	void OnApplicationFocusChanged(const bool bIsFocused);

	/** State cache */
	TMap<FString, TSharedRef<FDiversionState>> StateCache;
	/** Tracking modified states - enables resetting the changes to apply external to UE changes too */
	TMap<FString, TSharedRef<FDiversionState>> ModifiedStates;
	/** Tracking potential clashes - this used to keep track of resolved potential clashes*/
	TMap<FString, TSharedRef<FDiversionState>> PotentiallyClashedStates;
	/** Tracking synching states - enables restting them once finished synching */
	TMap<FString, TSharedRef<FDiversionState>> SynchingStates;
	/** Tracking conflicted states - enables restting them once finished resolving/Updating conflicts data */
	TMap<FString, TSharedRef<FDiversionState>> ConflictedStates;

// Background status triggering variables
	TUniquePtr<FTimedDelegateWrapper> BackgroundStatus = nullptr;
	TUniquePtr<FTimedDelegateWrapper> BackgroundPotentialClashes = nullptr;
	TUniquePtr<FTimedDelegateWrapper> BackgroundConflictedFiles = nullptr;
	FDelegateHandle FocusChangedHandle;
//

#pragma endregion

#pragma region InitializationStatusCache
public:
	bool IsRepoWithSameNameExists(const FString& RepoName, EConcurrency::Type Concurrency, bool InForceUpdate);
	bool IsWorkspaceExistsInPath(const FString& RepoName, const FString& Path, EConcurrency::Type Concurrency, bool InForceUpdate);

	// To be used by the API calls
	void SetRepoWithSameNameExists(bool InValue) {
		bRepoWithSameNameExists.Set(InValue);
	}
	void SetWorkspaceExistsInPath(bool InValue) {
		bWorkspaceExistsInPath.Set(InValue);
	}

private:
	TCached<bool> bRepoWithSameNameExists;
	TCached<bool> bWorkspaceExistsInPath;
#pragma endregion

#pragma region changelists
public:
	void AddCurrentChangesToChangelistState();

private:
	TSharedRef<FDiversionChangelistState> ChangelistState;
#pragma endregion
	
// Misc
private:
	FSourceControlPreSubmitDataValidationDelegate OriginalPreChangelistValidationDelegate;

	void RegisterPreSubmitValidationDelegates();
	void UnregisterAndRestorePreSubmitValidationDelegates();

	void PreChangelistValidationDelegateWrapper(FSourceControlChangelistPtr Changelist,
		EDataValidationResult& Result, TArray<FText>& ValidationErrors, TArray<FText>& ValidationWarnings);

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
	FSourceControlPreSubmitFilesValidationDelegate OriginalPreFilesValidationDelegate;
	void PreFilesValidationDelegateWrapper(TArray<FSourceControlStateRef>& InStates,
		EDataValidationResult& Result, TArray<FText>& ValidationErrors, TArray<FText>& ValidationWarnings);
#endif

	// Helper function to perform validation logic common to both changelist and files validation
	// Returns array of states that need to be cleaned up after validation delegate execution
	TArray<TSharedRef<FDiversionState>> PerformPreSubmitValidation(const TArray<FString>& FilesInChangeList,
		EDataValidationResult& Result, TArray<FText>& ValidationErrors, TArray<FText>& ValidationWarnings);

	// UI Commands for custom submit functionality
	FName MenuSectionName;
	
	void InitializeUICommands();
	void ShutdownUICommands();
	void ExecuteCommitChanges();
	bool CanExecuteCommitChanges() const;

	// Status panel widget
	TSharedPtr<class SDiversionStatusPanel> StatusPanelWidget;

	// Override for UsesChangelists() - used by custom commit flow to enable file checkboxes
	// When true, UsesChangelists() returns false to allow unchecking files in the commit dialog
	// This is due to UE not allowing using Git style commits while changelists enabled
	TAtomic<bool> bOverrideUsesChangelists{false};

public:
	void SetUsesChangelistsOverride(bool bOverride)
	{
		bOverrideUsesChangelists = bOverride;
	}

	/** RAII guard for temporarily overriding UsesChangelists() to return false */
	struct FUsesChangelistsOverrideGuard
	{
		FDiversionProvider& Provider;

		FUsesChangelistsOverrideGuard(FDiversionProvider& InProvider)
			: Provider(InProvider)
		{
			Provider.SetUsesChangelistsOverride(true);
		}

		~FUsesChangelistsOverrideGuard()
		{
			Provider.SetUsesChangelistsOverride(false);
		}

		// Non-copyable
		FUsesChangelistsOverrideGuard(const FUsesChangelistsOverrideGuard&) = delete;
		FUsesChangelistsOverrideGuard& operator=(const FUsesChangelistsOverrideGuard&) = delete;
	};

};
