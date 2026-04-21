// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#pragma once

// Forward declarations for API managers
namespace Diversion
{
	namespace AgentAPI { class DefaultApi; }
	namespace CoreAPI
	{
		class SupportApi;
		class AnalyticsApi;
		class RepositoryManagementApi;
		class RepositoryManipulationApi;
		class RepositoryMergeManipulationApi;
		class RepositoryCommitManipulationApi;
		class RepositoryWorkspaceManipulationApi;
	}
}

namespace DiversionHttp
{
	class FHttpRequestManager;
}

class FCredentialsManager;

/**
 * Thread-safe static access to Diversion API managers and credentials.
 * Owns and initializes API managers during module startup.
 * Safe to read from worker threads after initialization is complete.
 *
 * The API manager objects are owned by this class and created during Initialize().
 * Memory barriers ensure writes are visible to worker threads.
 */
class FDiversionAPIAccess
{
public:
	// Static pointers set during module startup, safe to read from any thread after initialization
	static Diversion::AgentAPI::DefaultApi* AgentAPI;
	static Diversion::CoreAPI::SupportApi* SupportAPI;
	static Diversion::CoreAPI::AnalyticsApi* AnalyticsAPI;
	static Diversion::CoreAPI::RepositoryManagementApi* RepositoryManagementAPI;
	static Diversion::CoreAPI::RepositoryManipulationApi* RepositoryManipulationAPI;
	static Diversion::CoreAPI::RepositoryMergeManipulationApi* RepositoryMergeManipulationAPI;
	static Diversion::CoreAPI::RepositoryCommitManipulationApi* RepositoryCommitManipulationAPI;
	static Diversion::CoreAPI::RepositoryWorkspaceManipulationApi* RepositoryWorkspaceManipulationAPI;

	/**
	 * Initialize API managers and credentials manager.
	 * Creates all API manager instances and sets up HTTP clients.
	 * Must be called from game thread during FDiversionModule::StartupModule()
	 * @param OriginalAccountID The account ID for logging and validity checks
	 */
	static void Initialize(const FString& OriginalAccountID);

	/**
	 * Shutdown API access - clears pointers and destroys API managers.
	 * Must be called from game thread during FDiversionModule::ShutdownModule()
	 * Must be called AFTER provider shutdown to ensure all workers have completed.
	 */
	static void Shutdown();

	/**
	 * Check if the API access layer has been initialized.
	 * Thread-safe, can be called from any thread.
	 * @return true if initialized and ready for use
	 */
	static bool IsInitialized();

	/**
	 * Get access token for a user. Thread-safe, can be called from worker threads.
	 * @param InUserID The user ID to get the token for
	 * @return The access token string
	 */
	static FString GetAccessToken(const FString& InUserID);

	/**
	 * Get the CoreAPI HTTP client for direct file downloads.
	 * Thread-safe after initialization.
	 * @return Shared pointer to the CoreAPI HTTP client
	 */
	static TSharedPtr<DiversionHttp::FHttpRequestManager> GetCoreAPIClient();

private:
	// HTTP clients (owned by this class)
	static TSharedPtr<DiversionHttp::FHttpRequestManager> AgentAPIClient;
	static TSharedPtr<DiversionHttp::FHttpRequestManager> CoreAPIClient;

	// API managers (owned by this class)
	static TUniquePtr<Diversion::AgentAPI::DefaultApi> AgentAPIManager;
	static TUniquePtr<Diversion::CoreAPI::SupportApi> SupportAPIManager;
	static TUniquePtr<Diversion::CoreAPI::AnalyticsApi> AnalyticsAPIManager;
	static TUniquePtr<Diversion::CoreAPI::RepositoryManagementApi> RepositoryManagementAPIManager;
	static TUniquePtr<Diversion::CoreAPI::RepositoryManipulationApi> RepositoryManipulationAPIManager;
	static TUniquePtr<Diversion::CoreAPI::RepositoryMergeManipulationApi> RepositoryMergeManipulationAPIManager;
	static TUniquePtr<Diversion::CoreAPI::RepositoryCommitManipulationApi> RepositoryCommitManipulationAPIManager;
	static TUniquePtr<Diversion::CoreAPI::RepositoryWorkspaceManipulationApi> RepositoryWorkspaceManipulationAPIManager;

	// Credentials manager (thread-safe with internal locking)
	static TUniquePtr<FCredentialsManager> CredentialsManager;

	// Initialization state flag (written once on main thread, read from any thread)
	static volatile bool bIsInitialized;

	// Original account ID for logging
	static FString CachedOriginalAccountID;
};
