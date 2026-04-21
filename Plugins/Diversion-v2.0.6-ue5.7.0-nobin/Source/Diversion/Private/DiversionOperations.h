// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#pragma once

#include "IDiversionWorker.h"
#include "IDiversionStatusWorker.h"
#include "DiversionState.h"

#include "DiversionUtils.h"

#include "SourceControlOperationBase.h"
#include "FileEntry.h"

#define LOCTEXT_NAMESPACE "SourceControl"


#pragma region Diversion Source Control Operations

class FUpdateWorkspaceOperation : public FSourceControlOperationBase
{
public:
	// ISourceControlOperation interface
	virtual FName GetName() const override
	{
		return "UpdateWorkspace";
	}

	virtual FText GetInProgressString() const override
	{
		return FText();
	}
};

class FGetWsInfo : public FSourceControlOperationBase
{
public:
	// ISourceControlOperation interface
	virtual FName GetName() const override
	{
		return "GetWsInfo";
	}

	virtual FText GetInProgressString() const override
	{
		return ProgressString;
	}

	static void SetProgressString()
	{
		ProgressString = LOCTEXT("SourceControl_GetWsInfo", "Getting Workspace Info...");
	}
private:
	static FText ProgressString;
};

class FSendAnalytics : public FSourceControlOperationBase
{
public:
	// ISourceControlOperation interface
	virtual FName GetName() const override
	{
		return "SendAnalytics";
	}

	virtual FText GetInProgressString() const override
	{
		// We don't really want to pop up a progress dialog for this
		return LOCTEXT("SourceControl_SendAnalytics", "");
	}

	const FText& GetEventName() const
	{
		return EventName;
	}

	void SetEventName(const FText& InEventName)
	{
		EventName = InEventName;
	}

	void SetEventProperties(const TMap<FString, FString>& InProperties)
	{
		Properties = InProperties;
	}
	
	const TMap<FString, FString>& GetEventProperties() const
	{
		return Properties;
	}

protected:
	FText EventName;
	TMap<FString, FString> Properties;
};

class FAgentHealthCheck : public FSourceControlOperationBase
{
public:
	// ISourceControlOperation interface
	virtual FName GetName() const override
	{
		return "AgentHealthCheck";
	}

	virtual FText GetInProgressString() const override
	{
		return ProgressString;
	}

	static void SetProgressString()
	{
		ProgressString = LOCTEXT("SourceControl_AgentHealthCheck", "Checking Diversion Sync Agent status...");
	}
private:
	static FText ProgressString;
};

class FFinalizeMerge : public FSourceControlOperationBase
{
public:
	virtual FName GetName() const override
	{
		return "FinalizeMerge";
	}

	virtual FText GetInProgressString() const override
	{
		return LOCTEXT("SourceControl_FinalizeMerge", "Finalizing merge...");
	}

	const FString& GetMergeID() const
	{
		return MergeID;
	}

	void SetMergeID(const FString& InMergeID)
	{
		MergeID = InMergeID;
	}

private:
	FString MergeID;
};

class FResolveFile : public FSourceControlOperationBase
{
public:
	virtual FName GetName() const override
	{
		return "ResolveFile";
	}

	virtual FText GetInProgressString() const override
	{
		return LOCTEXT("SourceControl_ResolveFile", "Resolving file(s)...");
	}

	void SetMergeID(const FString& InMergeID)
	{
		MergeID = InMergeID;
	}

	void SetConflictID(const FString& InConflictID)
	{
		ConflictID = InConflictID;
	}

	const FString& GetMergeID() const
	{
		return MergeID;
	}

	const FString& GetConflictID() const
	{
		return ConflictID;
	}

private:
	FString MergeID;
	FString ConflictID;
};

class FInitRepo : public FSourceControlOperationBase
{
public:
	virtual FName GetName() const override
	{
		return "InitRepo";
	}
	
	virtual FText GetInProgressString() const override
	{
		return LOCTEXT("SourceControl_InitRepo", "Initializing repository...");
	}

	void SetRepoPath(const FString& InRepoPath)
	{
		RepoPath = InRepoPath;
	}

	void SetRepoName(const FString& InRepoName)
	{
		RepoName = InRepoName;
	}

	const FString& GetRepoPath() const
	{
		return RepoPath;
	}

	const FString& GetRepoName() const
	{
		return RepoName;
	}

private:
	FString RepoPath;
	FString RepoName;
};


class FGetPotentialClashes : public FSourceControlOperationBase
{
public:
	virtual FName GetName() const override
	{
		return "GetPotentialClashes";
	}
	
	virtual FText GetInProgressString() const override
	{
		return LOCTEXT("SourceControl_GetPotentialClashes", "Updating file Revision Control status...");
	}
};

class FGetConflictedFiles : public FSourceControlOperationBase
{
public:
	virtual FName GetName() const override
	{
		return "GetConflictedFiles";
	}
	
	virtual FText GetInProgressString() const override
	{
		return LOCTEXT("SourceControl_GetPotentialClashes", "Checking for conflicts in your workspace...");
	}
};

class FCheckForRepoWithSameName : public FSourceControlOperationBase
{
public:
	virtual FName GetName() const override
	{
		return "CheckForRepoWithSameName";
	}

	virtual FText GetInProgressString() const override
	{
		return LOCTEXT("SourceControl_CheckForRepoWithSameName", "Making sure a repo with the same name doesn't already exist");
	}

	void SetRepoName(const FString& InRepoName)
	{
		RepoName = InRepoName;
	}

	const FString& GetRepoName() const
	{
		return RepoName;
	}

private:
	FString RepoName;
};

class FCheckIfWorkspaceExistsInPath : public FSourceControlOperationBase
{
public:
	virtual FName GetName() const override
	{
		return "CheckIfWorkspaceExistsInPath";
	}

	virtual FText GetInProgressString() const override
	{
		return LOCTEXT("SourceControl_CheckIfWorkspaceExistsInPath", "Checking if a workspace already exists in the path");
	}

	void SetPath(const FString& InRepoPath)
	{
		Path = InRepoPath;
	}

	const FString& GetPath() const
	{
		return Path;
	}

	void SetRepoName(const FString& InRepoName)
	{
		RepoName = InRepoName;
	}

	const FString& GetRepoName() const
	{
		return RepoName;
	}

private:
	FString Path;
	FString RepoName;

};

#pragma endregion

#undef LOCTEXT_NAMESPACE

#pragma region Diversion Workers


class FDiversionCheckForRepoWithSameNameWorker final : public IDiversionWorker
{
public:
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;

public:
	bool bRepoWithSameNameExists = false;
};


class FDiversionCheckIfWorkspaceExistsInPathWorker final : public IDiversionWorker
{
public:
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;

public:
	bool bWorkspaceExistsInPath = false;
	bool bRepoWithSameNameExists = false;
	bool bFetchSuccess = false;
};


class FDiversionUpdateWorkspaceWorker final : public IDiversionWorker
{
public:
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;
};


class FDiversionInitRepoWorker final : public IDiversionWorker, public TSharedFromThis<FDiversionInitRepoWorker>
{
public:
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
};

class FDiversionFinalizeMergeWorker final : public IDiversionWorker, public TSharedFromThis<FDiversionFinalizeMergeWorker>
{
public:
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
};

class FDiversionResolveFileWorker final : public IDiversionWorker, public TSharedFromThis<FDiversionResolveFileWorker>
{
public:
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;

public:
	Diversion::CoreAPI::Model::FileEntry FileEntry;
	DiversionUtils::EDiversionWsSyncStatus SyncStatus;
};

class FDiversionWsInfoWorker final : public IDiversionWorker, public TSharedFromThis<FDiversionWsInfoWorker>
{
	public:
	FDiversionWsInfoWorker() : WsInfo(WorkspaceInfo()) {}
	virtual ~FDiversionWsInfoWorker() override {}
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;

	WorkspaceInfo WsInfo;
};

class FDiversionAgentHealthCheckWorker final : public IDiversionWorker, public TSharedFromThis<FDiversionAgentHealthCheckWorker>
{
public:
	FDiversionAgentHealthCheckWorker() : AgentVersion("N/a"), IsAgentAlive(false), SyncStatus()
	{
	}

	virtual ~FDiversionAgentHealthCheckWorker() override {}
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;

public:
	FString AgentVersion;
	bool IsAgentAlive;
	DiversionUtils::EDiversionWsSyncStatus SyncStatus;
};

class FDiversionAnalyticsEventWorker final : public IDiversionWorker, public TSharedFromThis<FDiversionAnalyticsEventWorker>
{
public:
	virtual ~FDiversionAnalyticsEventWorker() override {}
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
};

class FDiversionGetPotentialClashes final : public IDiversionWorker
{
public:
	virtual ~FDiversionGetPotentialClashes() override {}
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;
	
private:
	bool IsFullRepoStatusQuery(const FString& RepoPath) const;

	/** Map of filenames to potential clash data*/
	TMap<FString, TArray<EDiversionPotentialClashInfo>> PotentialClashes;
	TArray<FString> QueriedPaths;
	bool bRecursiveRequest = false;
};

class FDiversionGetConflictedFiles final : public IDiversionWorker
{
public:
	virtual ~FDiversionGetConflictedFiles() override {}
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;

private:
	bool bRequireUpdate = false;
	TMap<FString, FDiversionResolveInfo> ConflictedFilesData;

	TArray<Diversion::CoreAPI::Model::Merge> WorkspaceMergesList;
	TArray<Diversion::CoreAPI::Model::Merge> BranchMergesList;
};

#pragma endregion

#pragma region Source Control Workers

/** Called when first activated on a project, and then at project load time.
 *  Look for the root directory of the Diversion workspace (where the ".diversion/" subdirectory is located). */
class FDiversionConnectWorker final : public IDiversionWorker
{
public:
	virtual ~FDiversionConnectWorker() override {}
	// IDiversionWorker interface
	virtual FName GetName() const override;
	// Background thread
	virtual bool Execute(class FDiversionCommand& InCommand) override;
	// Main thread => update states
	virtual bool UpdateStates() const override;
};

/** Commit (check-in) a set of file to the local depot. */
class FDiversionCheckInWorker final : public IDiversionWorker
{
public:
	virtual ~FDiversionCheckInWorker() override {}
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;

private:
	TArray<FString> CommittedFilesPaths;	
};

/** Add an untracked file to version control (so only a subset of the dv add command). */
class FDiversionMarkForAddWorker final : public IDiversionWorker
{
public:
	virtual ~FDiversionMarkForAddWorker() override {}
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
};

/** Delete a file and remove it from version control. */
class FDiversionDeleteWorker final : public IDiversionWorker
{
public:
	virtual ~FDiversionDeleteWorker() override {}
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
};

/** Revert any change to a file to its state on the local depot. */
class FDiversionRevertWorker final : public IDiversionStatusWorker
{
public:
	virtual ~FDiversionRevertWorker() override {}
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;

private:
	bool bShouldUpdateStates = false;
	TMap<FString, TArray<EDiversionPotentialClashInfo>> PotentialClashes;
};

// Todo: Diversion doesn't have sync command, this should replace `dv update`
/** Diversion pull --rebase to update branch from its configure remote */
// class FDiversionSyncWorker : public IDiversionWorker
// {
// public:
// 	virtual ~FDiversionSyncWorker() {}
// 	// IDiversionWorker interface
// 	virtual FName GetName() const override;
// 	virtual bool Execute(class FDiversionCommand& InCommand) override;
// };

/** 
 * Update status is called internally by UE, without Diversion granular control and sometime might block
 * the main thread if called synchronously.
 * As a solution, Diversion is polling and caching the status (changes, potential clashed, conflict info etc.)
 * in the background.
 *
 * We keep this worker not to update cached states data, but to optimize and retrieve file history only on demand.
 * Any other status requirements should be handled by the background polling worker.
 *
 * Todo: add here indications of files being currently synced by the agent.
 * Since this is only relevant per path, we should have it here and not in the background worker.
 */
class FDiversionUpdateStatusWorker final : public IDiversionStatusWorker
{
public:
	virtual ~FDiversionUpdateStatusWorker() override {}
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;

private:
	bool UpdateHistory(FDiversionCommand& InCommand);
	bool UpdateConflicts() const;
	bool IsFullRepoStatusQuery(const FString& RepoPath) const;
	void MarkSyncingFiles() const;
	
private:
	/** The paths passed in the command we want the status of */
	TArray<FString> QueriedPaths;
	/** flag to update cached provider states */
	bool bShouldUpdateStates = false;
	/** Indicates if we want to trigger an async status update call */
	bool bTriggerStatusReload = false;

	/** Storing Conflicts states output information from API calls*/
	bool bShouldUpdateConflicts = false;
	TMap<FString, FDiversionResolveInfo> ConflictedFilesData;

	TArray<Diversion::CoreAPI::Model::Merge> WorkspaceMergesList;
	TArray<Diversion::CoreAPI::Model::Merge> BranchMergesList;
	/***/
};

/** Copy or Move operation on a single file */
class FDiversionCopyWorker final : public IDiversionWorker
{
public:
	virtual ~FDiversionCopyWorker() override {}
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(class FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;

public:
	/** Temporary states for results */
	TArray<FDiversionState> OutStates;
};

/** dv add to mark a conflict as resolved */
class FDiversionResolveWorker final : public IDiversionWorker
{
public:
	virtual ~FDiversionResolveWorker() override {}
	virtual FName GetName() const override;
	virtual bool Execute(FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;
	
private:
	/** Temporary FilesToResolve list to update the Provider */
	TArray<FString> FilesToResolve;
};

class FDiversionSyncWorker final : public IDiversionWorker
{
public:
	virtual ~FDiversionSyncWorker() override {}
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;
};

class FDiversionGetPendingChangelistsWorker final : public IDiversionWorker
{
public:
	virtual ~FDiversionGetPendingChangelistsWorker() override {}
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;
};


class FDiversionOperationNotSupportedWorker final : public IDiversionWorker
{
public:
	// IDiversionWorker interface
	virtual FName GetName() const override;
	virtual bool Execute(FDiversionCommand& InCommand) override;
	virtual bool UpdateStates() const override;
};


#pragma endregion