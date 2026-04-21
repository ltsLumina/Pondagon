// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#pragma once

#include "Templates/SharedPointer.h"
#include "DiversionUtils.h"

class IDiversionWorker
{
public:
	virtual ~IDiversionWorker() = default;
	/**
	 * Name describing the work that this worker does. Used for factory method hookup.
	 */
	virtual FName GetName() const = 0;

	/**
	 * Function that actually does the work. Can be executed on another thread.
	 */
	virtual bool Execute(class FDiversionCommand& InCommand) = 0;

	/**
	 * Updates the state of any items after completion (if necessary). This is always executed on the main thread.
	 * @returns true if states were updated
	 */
	virtual bool UpdateStates() const;

public:
	/** Storing the state of agent sync 
	* Relevant for most operations, since we need the FS state to be stable 
	*/
	TOptional<DiversionUtils::EDiversionWsSyncStatus> SyncStatus;

	TArray<FString> OpenedPackagePaths = TArray<FString>();
	bool ReloadStatusReuired = false;

private:
	bool UpdateSyncStatus() const;

	void ReleaseLockedPackages() const;
};

typedef TSharedRef<IDiversionWorker, ESPMode::ThreadSafe> FDiversionWorkerRef;


