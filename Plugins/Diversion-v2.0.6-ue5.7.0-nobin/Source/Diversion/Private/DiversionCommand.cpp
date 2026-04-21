// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#include "DiversionCommand.h"

#include "DiversionModule.h"
#include "DiversionAPIAccess.h"
#include "SourceControlHelpers.h"

FDiversionCommand::FDiversionCommand(const TSharedRef<class ISourceControlOperation, ESPMode::ThreadSafe>& InOperation, const TSharedRef<class IDiversionWorker, ESPMode::ThreadSafe>& InWorker, EConcurrency::Type InConcurrency, const FSourceControlOperationComplete& InOperationCompleteDelegate)
	: Operation(InOperation)
	, Worker(InWorker)
	, OperationCompleteDelegate(InOperationCompleteDelegate)
	, bExecuteProcessed(0)
	, bCommandSuccessful(false)
	, bAutoDelete(true)
	, Concurrency(InConcurrency)
{
	// grab the providers settings here, so we don't access them once the worker thread is launched
	check(IsInGameThread());
	FDiversionModule& Diversion = FDiversionModule::Get();
	
	auto& Provider = Diversion.GetProvider();
	// Get the latest values - revalidate the cache
	WsInfo = Provider.GetWsInfo();
	IsAgentAlive = Provider.IsAgentAlive();
	Provider.GetConflictedFilesPaths(ConflictedFiles);
	Provider.GetCurrentPotentialClashes(ExistingPotentialConflicts);
	SyncStatus = Provider.GetSyncStatus();
}

void FDiversionCommand::DoWork()
{
	Worker->Execute(*this);
}

void FDiversionCommand::Abandon()
{
	FPlatformAtomics::InterlockedExchange(&bExecuteProcessed, 1);
}

void FDiversionCommand::DoThreadedWork()
{
	// Ensure the Diversion API access layer is initialized before doing work
	if (!FDiversionAPIAccess::IsInitialized())
	{
		UE_LOG(LogSourceControl, Error, TEXT("Diversion API access not initialized before starting worker thread!"));
		MarkOperationCompleted(false);
		return;
	}

	DoWork();
}

ECommandResult::Type FDiversionCommand::ReturnResults()
{
	// Save any messages that have accumulated
	for (FString& String : InfoMessages)
	{
		Operation->AddInfoMessge(FText::FromString(String));
	}
	for (FString& String : ErrorMessages)
	{
		Operation->AddErrorMessge(FText::FromString(String));
	}
	
	// run the completion delegate if we have one bound
	ECommandResult::Type Result = bCommandSuccessful ? ECommandResult::Succeeded : ECommandResult::Failed;
	OperationCompleteDelegate.ExecuteIfBound(Operation, Result);

	return Result;
}

void FDiversionCommand::MarkOperationCompleted(bool InCommandSuccessful)
{
	bCommandSuccessful = InCommandSuccessful;
	FPlatformAtomics::InterlockedExchange(&bExecuteProcessed, 1);
}
