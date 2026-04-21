// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#include "DiversionAPIAccess.h"
#include "DiversionUtils.h"
#include "DiversionAgentAddress.h"
#include "DiversionCredentialsManager.h"
#include "DiversionHttpManager.h"
#include "HAL/PlatformMisc.h"
#include "ISourceControlModule.h"

// API headers
#include "DefaultApi.h"
#include "SupportApi.h"
#include "AnalyticsApi.h"
#include "RepositoryManipulationApi.h"
#include "RepositoryMergeManipulationApi.h"
#include "RepositoryCommitManipulationApi.h"
#include "RepositoryWorkspaceManipulationApi.h"
#include "RepositoryManagementApi.h"

// Define static members - Public pointers
Diversion::AgentAPI::DefaultApi* FDiversionAPIAccess::AgentAPI = nullptr;
Diversion::CoreAPI::SupportApi* FDiversionAPIAccess::SupportAPI = nullptr;
Diversion::CoreAPI::AnalyticsApi* FDiversionAPIAccess::AnalyticsAPI = nullptr;
Diversion::CoreAPI::RepositoryManagementApi* FDiversionAPIAccess::RepositoryManagementAPI = nullptr;
Diversion::CoreAPI::RepositoryManipulationApi* FDiversionAPIAccess::RepositoryManipulationAPI = nullptr;
Diversion::CoreAPI::RepositoryMergeManipulationApi* FDiversionAPIAccess::RepositoryMergeManipulationAPI = nullptr;
Diversion::CoreAPI::RepositoryCommitManipulationApi* FDiversionAPIAccess::RepositoryCommitManipulationAPI = nullptr;
Diversion::CoreAPI::RepositoryWorkspaceManipulationApi* FDiversionAPIAccess::RepositoryWorkspaceManipulationAPI = nullptr;

// Define static members - Private ownership
TSharedPtr<DiversionHttp::FHttpRequestManager> FDiversionAPIAccess::AgentAPIClient = nullptr;
TSharedPtr<DiversionHttp::FHttpRequestManager> FDiversionAPIAccess::CoreAPIClient = nullptr;

TUniquePtr<Diversion::AgentAPI::DefaultApi> FDiversionAPIAccess::AgentAPIManager = nullptr;
TUniquePtr<Diversion::CoreAPI::SupportApi> FDiversionAPIAccess::SupportAPIManager = nullptr;
TUniquePtr<Diversion::CoreAPI::AnalyticsApi> FDiversionAPIAccess::AnalyticsAPIManager = nullptr;
TUniquePtr<Diversion::CoreAPI::RepositoryManagementApi> FDiversionAPIAccess::RepositoryManagementAPIManager = nullptr;
TUniquePtr<Diversion::CoreAPI::RepositoryManipulationApi> FDiversionAPIAccess::RepositoryManipulationAPIManager = nullptr;
TUniquePtr<Diversion::CoreAPI::RepositoryMergeManipulationApi> FDiversionAPIAccess::RepositoryMergeManipulationAPIManager = nullptr;
TUniquePtr<Diversion::CoreAPI::RepositoryCommitManipulationApi> FDiversionAPIAccess::RepositoryCommitManipulationAPIManager = nullptr;
TUniquePtr<Diversion::CoreAPI::RepositoryWorkspaceManipulationApi> FDiversionAPIAccess::RepositoryWorkspaceManipulationAPIManager = nullptr;

TUniquePtr<FCredentialsManager> FDiversionAPIAccess::CredentialsManager = nullptr;

volatile bool FDiversionAPIAccess::bIsInitialized = false;
FString FDiversionAPIAccess::CachedOriginalAccountID;

void FDiversionAPIAccess::Initialize(const FString& OriginalAccountID)
{
	if (!DiversionUtils::DiversionValidityCheck(IsInGameThread(),
		"FDiversionAPIAccess::Initialize must be called on the main game thread", OriginalAccountID)) {
		return;
	}

	// Cache the account ID for logging
	CachedOriginalAccountID = OriginalAccountID;

	const bool DONT_REQUIRE_EDITOR_FOCUS = false;
	const bool REQUIRE_EDITOR_FOCUS = true;

	// Create the Agent API request manager
	AgentAPIClient = MakeShared<DiversionHttp::FHttpRequestManager>(FDiversionAgentAddress::GetAgentURL(),
		DONT_REQUIRE_EDITOR_FOCUS, DiversionUtils::GetDiversionHeaders());
	AgentAPIClient->SetUrlProvider([]() { return FDiversionAgentAddress::GetAgentURL(); });
	AgentAPIManager = MakeUnique<Diversion::AgentAPI::DefaultApi>(AgentAPIClient);

	// Create the Core API request managers
	CoreAPIClient = MakeShared<DiversionHttp::FHttpRequestManager>(DIVERSION_API_HOST, DIVERSION_API_PORT, REQUIRE_EDITOR_FOCUS,
		DiversionUtils::GetDiversionHeaders());
	SupportAPIManager = MakeUnique<Diversion::CoreAPI::SupportApi>(CoreAPIClient);
	AnalyticsAPIManager = MakeUnique<Diversion::CoreAPI::AnalyticsApi>(CoreAPIClient);
	RepositoryManagementAPIManager = MakeUnique<Diversion::CoreAPI::RepositoryManagementApi>(CoreAPIClient);
	RepositoryManipulationAPIManager = MakeUnique<Diversion::CoreAPI::RepositoryManipulationApi>(CoreAPIClient);
	RepositoryMergeManipulationAPIManager = MakeUnique<Diversion::CoreAPI::RepositoryMergeManipulationApi>(CoreAPIClient);
	RepositoryCommitManipulationAPIManager = MakeUnique<Diversion::CoreAPI::RepositoryCommitManipulationApi>(CoreAPIClient);
	RepositoryWorkspaceManipulationAPIManager = MakeUnique<Diversion::CoreAPI::RepositoryWorkspaceManipulationApi>(CoreAPIClient);

	// Set public pointers to the owned managers
	AgentAPI = AgentAPIManager.Get();
	SupportAPI = SupportAPIManager.Get();
	AnalyticsAPI = AnalyticsAPIManager.Get();
	RepositoryManagementAPI = RepositoryManagementAPIManager.Get();
	RepositoryManipulationAPI = RepositoryManipulationAPIManager.Get();
	RepositoryMergeManipulationAPI = RepositoryMergeManipulationAPIManager.Get();
	RepositoryCommitManipulationAPI = RepositoryCommitManipulationAPIManager.Get();
	RepositoryWorkspaceManipulationAPI = RepositoryWorkspaceManipulationAPIManager.Get();

	// Create credentials manager for thread-safe token access
	CredentialsManager = MakeUnique<FCredentialsManager>();

	// Memory barrier to ensure all writes are visible to other threads before setting initialized flag
	FPlatformMisc::MemoryBarrier();

	// Mark as initialized (this write happens after the barrier, so other threads will see all previous writes)
	bIsInitialized = true;
}

void FDiversionAPIAccess::Shutdown()
{
	if (!DiversionUtils::DiversionValidityCheck(IsInGameThread(),
		"FDiversionAPIAccess::Shutdown must be called on the main game thread", CachedOriginalAccountID)) {
		return;
	}

	// Mark as not initialized
	bIsInitialized = false;

	// Clear public pointers
	AgentAPI = nullptr;
	SupportAPI = nullptr;
	AnalyticsAPI = nullptr;
	RepositoryManagementAPI = nullptr;
	RepositoryManipulationAPI = nullptr;
	RepositoryMergeManipulationAPI = nullptr;
	RepositoryCommitManipulationAPI = nullptr;
	RepositoryWorkspaceManipulationAPI = nullptr;

	// Destroy owned API managers
	AgentAPIManager.Reset();
	SupportAPIManager.Reset();
	AnalyticsAPIManager.Reset();
	RepositoryManagementAPIManager.Reset();
	RepositoryManipulationAPIManager.Reset();
	RepositoryMergeManipulationAPIManager.Reset();
	RepositoryCommitManipulationAPIManager.Reset();
	RepositoryWorkspaceManipulationAPIManager.Reset();

	// Destroy HTTP clients
	AgentAPIClient.Reset();
	CoreAPIClient.Reset();

	// Destroy credentials manager
	CredentialsManager.Reset();

	// Clear cached account ID
	CachedOriginalAccountID.Empty();
}

bool FDiversionAPIAccess::IsInitialized()
{
	return bIsInitialized;
}

FString FDiversionAPIAccess::GetAccessToken(const FString& InUserID)
{
	if (!CredentialsManager.IsValid())
	{
		UE_LOG(LogSourceControl, Error, TEXT("FDiversionAPIAccess::GetAccessToken called before Initialize()"));
		return "";
	}

	return CredentialsManager->GetUserAccessToken(InUserID);
}

TSharedPtr<DiversionHttp::FHttpRequestManager> FDiversionAPIAccess::GetCoreAPIClient()
{
	return CoreAPIClient;
}
