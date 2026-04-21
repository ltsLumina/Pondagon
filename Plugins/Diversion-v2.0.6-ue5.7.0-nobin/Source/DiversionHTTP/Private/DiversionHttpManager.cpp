// Copyright 2024 Diversion Company, Inc. All Rights Reserved.
#include "DiversionHttpManager.h"
#include "DiversionHttpModule.h"
#include "Interfaces/IPluginManager.h"
#include "Misc/Paths.h"
#include "Framework/Application/SlateApplication.h"
#include "DiversionValidityUtils.h"
#include "Containers/LruCache.h"
#include "DiversionConfig.h"

#include "HttpSession.h"
#include "SslSession.h"
#include "TcpSession.h"
#include "BoostHeaders.h"
#include "ConnectionPool.h"
#include "PooledConnection.h"

#include <string>
#include <future>
#include <functional>
#include <atomic>
#include <stdexcept>

namespace beast = boost::beast;         // from <boost/beast.hpp>
namespace http = beast::http;           // from <boost/beast/http.hpp>
namespace net = boost::asio;            // from <boost/asio.hpp>

using namespace DiversionHttp;


class IoContextManager {
public:
	IoContextManager() :
		IoContext(boost::asio::io_context()),
		IsRunning(false)
	{}

	~IoContextManager()
	{
		if(IsRunning) {
			Stop();
			Join();
		}
	}

	void Start(std::size_t InThreadCount = 1) {
		if(IsRunning) {
			return;
		}

		IsRunning.store(true);
		WorkGuard = std::make_unique<WorkGuardType>(boost::asio::make_work_guard(IoContext));

		Threads.Reserve(InThreadCount);
		for(std::size_t i = 0; i < InThreadCount; ++i) {
			Threads.Emplace([this]() { this->RunLoop(); });
		}
	}

	void Stop() {
		if(!IsRunning) {
			return;
		}

		IsRunning.store(false);

		if(WorkGuard) {
			WorkGuard->reset();
		}
		WorkGuard.reset();
		IoContext.stop();
	}

	void Join() {
		for(auto& Thread : Threads) {
			if(Thread.joinable()) {
				Thread.join();
			}
		}
		Threads.Empty();
	}

	boost::asio::io_context& GetIoContext() {
		return IoContext;
	}

private:
	using WorkGuardType = boost::asio::executor_work_guard<
		boost::asio::io_context::executor_type>;

	std::unique_ptr<WorkGuardType> WorkGuard;
	TArray<std::thread> Threads;
	boost::asio::io_context IoContext;
	std::atomic<bool> IsRunning;

private:
#if PLATFORM_WINDOWS
	// Separate function for SEH handling without C++ objects (to avoid unwinding conflicts)
	static DWORD RunIoContextWithSEH(boost::asio::io_context* InIoContext) {
		__try {
			InIoContext->run();
			return 0; // Success
		}
		__except(EXCEPTION_EXECUTE_HANDLER) {
			DWORD ExceptionCode = GetExceptionCode();
			UE_LOG(LogDiversionHttp, Error, TEXT("Structured exception in HTTP io context: 0x%08X"), ExceptionCode);

			switch (ExceptionCode) {
				case EXCEPTION_ACCESS_VIOLATION:
					UE_LOG(LogDiversionHttp, Error, TEXT("Access violation detected - likely use-after-free or dangling pointer"));
					break;
				case EXCEPTION_STACK_OVERFLOW:
					UE_LOG(LogDiversionHttp, Error, TEXT("Stack overflow detected"));
					break;
				default:
					UE_LOG(LogDiversionHttp, Error, TEXT("SEH exception code: 0x%08X"), ExceptionCode);
					break;
			}

			return ExceptionCode;
		}
	}
#endif

	void RunLoop() {
		while (IsRunning.load()) {
			try {
#if PLATFORM_WINDOWS
				// Use SEH wrapper on Windows to catch access violations
				DWORD ExceptionCode = RunIoContextWithSEH(&IoContext);
				if (ExceptionCode != 0) {
					// SEH exception occurred - stop the context and exit
					IoContext.stop();
					break;
				}
#else
				IoContext.run();
#endif
				// If the context finished running due to no more work, we should restart it and continue
				if (IoContext.stopped() && IsRunning) {
					UE_LOG(LogDiversionHttp, Warning, TEXT("IoContext stopped due to no more work, restarting"));
					IoContext.restart();
				}
			}
			catch (const std::exception& Ex) {
				UE_LOG(LogDiversionHttp, Error, TEXT("Error in HTTP io context: %s"), UTF8_TO_TCHAR(Ex.what()));
			}
			catch(...) {
				UE_LOG(LogDiversionHttp, Error, TEXT("Unknown error in HTTP io context"));
				IoContext.stop();
				break;
			}
		}
	}
};


// Internal implementation class
class FHttpRequestManagerImpl
{
	typedef boost::asio::executor_work_guard<boost::asio::io_context::executor_type> WorkGuardType;

public:
	FHttpRequestManagerImpl(const FString& InHost, const FString& InPort, bool UseSSL, int HttpVersion, bool bRequireEditorFocus)
		: SslContext(std::make_unique<net::ssl::context>(net::ssl::context::tlsv12_client)),
		Host(TCHAR_TO_UTF8(*InHost)),
		Port(TCHAR_TO_UTF8(*InPort)),
		UseSSL(UseSSL),
		httpVersion(HttpVersion),
		bRequireEditorFocus(bRequireEditorFocus && IsInGameThread()),
		bEditorHasFocus(true),
		ResponseCache(GetDiversionResponseCacheSize())
	{
		// Focus tracking requires game thread - disable if not available
		DiversionValidityUtils::DiversionValidityCheck(
			!bRequireEditorFocus || IsInGameThread(),
			TEXT("FHttpRequestManagerImpl constructor called off game thread. Focus tracking disabled.")
		);

		ConfigureSslContext();
		IoContextManager.Start();
		InitializeConnectionPool();

		if (this->bRequireEditorFocus)
		{
			if (FSlateApplication::IsInitialized())
			{
				FocusChangedHandle = FSlateApplication::Get().OnApplicationActivationStateChanged().AddRaw(
					this, &FHttpRequestManagerImpl::OnApplicationFocusChanged);
				bEditorHasFocus.store(FSlateApplication::Get().IsActive());
			}
		}
	}

	~FHttpRequestManagerImpl()
	{
		bIsShuttingDown.store(true);

		// Slate operations must happen on the game thread - defer cleanup if needed
		if (FocusChangedHandle.IsValid())
		{
			if (IsInGameThread())
			{
				// Safe to remove directly
				if (FSlateApplication::IsInitialized())
				{
					FSlateApplication::Get().OnApplicationActivationStateChanged().Remove(FocusChangedHandle);
				}
			}
			else
			{
				// Defer to game thread to avoid crash
				FDelegateHandle HandleToRemove = FocusChangedHandle;
				AsyncTask(ENamedThreads::GameThread, [HandleToRemove]()
				{
					if (FSlateApplication::IsInitialized())
					{
						FSlateApplication::Get().OnApplicationActivationStateChanged().Remove(HandleToRemove);
					}
				});
			}
		}

		if (ConnectionPool)
		{
			ConnectionPool->Shutdown();
		}

		IoContextManager.Stop();
		IoContextManager.Join();
	}

	HTTPCallResponse SendRequest(
		const FString& Url,
		DiversionHttp::HttpMethod Method,
		const FString& Token,
		const FString& ContentType,
		const FString& Content,
		const TMap<FString, FString>& Headers,
		const int ConnectionTimeoutSeconds,
		const int RequestTimeoutSeconds,
		const FString& OutputFilePath = TEXT(""))
	{
		if (bIsShuttingDown.load())
		{
			UE_LOG(LogDiversionHttp, Verbose, TEXT("HTTP request skipped: Manager is shutting down. URL: %s"), *Url);
			return HTTPCallResponse(TEXT(""), DiversionHttp::HTTP_STATUS_CUSTOM_REQUEST_NOT_SENT, TMap<FString, FString>());
		}

		if (bRequireEditorFocus && !bEditorHasFocus.load())
		{
			UE_LOG(LogDiversionHttp, Verbose, TEXT("HTTP request skipped: Editor is not in focus. URL: %s"), *Url);
			return HTTPCallResponse(TEXT(""), DiversionHttp::HTTP_STATUS_CUSTOM_REQUEST_NOT_SENT, TMap<FString, FString>());
		}

		// Snapshot address fields under read lock to avoid races with UpdateAddress
		std::string SnapshotHost;
		std::string SnapshotPort;
		bool SnapshotUseSSL;
		{
			FRWScopeLock ReadLock(AddressLock, SLT_ReadOnly);
			SnapshotHost = Host;
			SnapshotPort = Port;
			SnapshotUseSSL = UseSSL;
		}

		// Declare Key and PooledConnection outside try block so they're available in catch
		FConnectionKey Key{SnapshotHost, SnapshotPort, SnapshotUseSSL};
		std::shared_ptr<FPooledConnection> PooledConnection;

		try {
			// Check for cached ETag and add If-None-Match header
			TMap<FString, FString> RequestHeaders = Headers;
			AddIfNoneMatchHeader(Method, Url, RequestHeaders);

			http::request<http::string_body> Request;
			BuildRequest(Request, SnapshotHost, Url, Method, Token, ContentType, Content, RequestHeaders);

			// Add connection keep-alive header for pooled connections
			Request.set(http::field::connection, "keep-alive");

			// Get validated timeouts
			auto TimeoutPair = ConnectionPoolConfig.GetValidatedTimeouts(
				SnapshotHost, ConnectionTimeoutSeconds, RequestTimeoutSeconds);
			auto ConnectionTimeout = TimeoutPair.first;
			auto RequestTimeout = TimeoutPair.second;
			
			// Get connection from pool (required - no fallback)
			if (!ConnectionPool)
			{
				return HTTPCallResponse(TEXT("Connection pool not initialized"));
			}
			
			PooledConnection = ConnectionPool->AcquireConnection(Key, RequestTimeout / 3);
			if (!PooledConnection)
			{
				// Record failed connection acquisition
				ConnectionPool->GetMetrics()->RecordRequestResult(Key, false, DiversionHttp::EMetricEvent::ConnectionTimeout);
				return HTTPCallResponse(TEXT("Failed to acquire connection from pool"));
			}
			
			// Set timeouts for this specific request
			PooledConnection->SetTimeouts(ConnectionTimeout, RequestTimeout);
			
			HTTPCallResponse Response;
			auto RequestStart = std::chrono::steady_clock::now();
			
			// Record request start
			ConnectionPool->GetMetrics()->RecordEvent(DiversionHttp::EMetricEvent::RequestServed, &Key);
			
			// Use pooled connection
			if (SnapshotUseSSL && PooledConnection->GetSslSession()) {
				auto Session = PooledConnection->GetSslSession();
				
				// Ensure connection is established
				auto ConnectionFuture = Session->ConnectAsync();
				if (ConnectionFuture.wait_for(std::chrono::seconds(static_cast<int>(ConnectionTimeout.count()))) == std::future_status::timeout) {
					Response = HTTPCallResponse(TEXT("Connection timeout"));
				} else if (!ConnectionFuture.get()) {
					Response = HTTPCallResponse(TEXT("Connection failed"));
				} else {
					// Connection established, execute request
					Response = Session->ExecuteRequest(Request, OutputFilePath);
				}
			}
			else if (!SnapshotUseSSL && PooledConnection->GetTcpSession()) {
				auto Session = PooledConnection->GetTcpSession();
				
				// Ensure connection is established
				auto ConnectionFuture = Session->ConnectAsync();
				if (ConnectionFuture.wait_for(std::chrono::seconds(static_cast<int>(ConnectionTimeout.count()))) == std::future_status::timeout) {
					Response = HTTPCallResponse(TEXT("Connection timeout"));
				} else if (!ConnectionFuture.get()) {
					Response = HTTPCallResponse(TEXT("Connection failed"));
				} else {
					// Connection established, execute request
					Response = Session->ExecuteRequest(Request, OutputFilePath);
				}
			}
			else {
				UE_LOG(LogDiversionHttp, Error, TEXT("Pooled connection session mismatch for SSL=%d"), SnapshotUseSSL);
				Response = HTTPCallResponse(TEXT("Pooled connection session mismatch"));
			}
			
			// Record timing and result metrics
			auto RequestEnd = std::chrono::steady_clock::now();
			auto Duration = std::chrono::duration_cast<std::chrono::milliseconds>(RequestEnd - RequestStart);

			ConnectionPool->GetMetrics()->RecordTiming(DiversionHttp::EMetricEvent::RequestServed, Duration);

			// Handle 304 Not Modified - return cached response
			if (Response.ResponseCode == DiversionHttp::HTTP_STATUS_NOT_MODIFIED)
			{
				const FString CacheKey = GetCacheKey(Method, Url);
				FScopeLock Lock(&ResponseCacheMutex);
				if (const FCachedResponse* Cached = ResponseCache.FindAndTouch(CacheKey))
				{
					UE_LOG(LogDiversionHttp, Verbose, TEXT("Returning cached response for 304 Not Modified: %s"), *CacheKey);
					ConnectionPool->GetMetrics()->RecordRequestResult(Key, true);
					ConnectionPool->ReleaseConnection(PooledConnection);
					return Cached->Response;
				}
				// No cached response available - treat as error to avoid returning empty 304 body
				FString Error = TEXT("Received 304 Not Modified but no cached response is available");
				UE_LOG(LogDiversionHttp, Error, TEXT("%s for %s"), *Error, *CacheKey);
				Response = HTTPCallResponse(Error);
			}

			// Record request result
			if (!Response.Error.IsSet()) {
				ConnectionPool->GetMetrics()->RecordRequestResult(Key, true);
				CacheResponse(Method, Url, Response);
			} else {
				// Determine failure reason based on error message
				DiversionHttp::EMetricEvent FailureReason = DiversionHttp::EMetricEvent::NetworkError;
				if (Response.Error->Contains(TEXT("timeout"))) {
					FailureReason = DiversionHttp::EMetricEvent::RequestTimeout;
				} else if (Response.Error->Contains(TEXT("Connection timeout")) || Response.Error->Contains(TEXT("Connection failed"))) {
					FailureReason = DiversionHttp::EMetricEvent::ConnectionTimeout;
				} else if (Response.Error->Contains(TEXT("DNS")) || Response.Error->Contains(TEXT("resolve"))) {
					FailureReason = DiversionHttp::EMetricEvent::DNSResolutionFailure;
				} else if (Response.ResponseCode >= 400) {
					FailureReason = DiversionHttp::EMetricEvent::HTTPError;
				}
				
				ConnectionPool->GetMetrics()->RecordRequestResult(Key, false, FailureReason);
				
				// Increment failure count on the connection for connection management decisions
				if (PooledConnection)
				{
					PooledConnection->IncrementFailureCount();
				}
			}
			
			// Return connection to pool (or mark invalid on error)
			if (!Response.Error.IsSet()) {
				ConnectionPool->ReleaseConnection(PooledConnection);
			} else {
				// Conservative approach: invalidate by default, only preserve for known safe errors
				bool bShouldPreserveConnection = false;
				
				// Only preserve connection for HTTP errors that indicate server/content issues
				// (not connection issues) AND the connection has low error count
				if (Response.ResponseCode >= 400 && Response.ResponseCode < 600 && 
					PooledConnection->GetFailureCount() < 10) {
					// HTTP 4XX/5XX with valid response code = server responded, connection is likely healthy
					bShouldPreserveConnection = true;
				}
				
				if (!bShouldPreserveConnection) {
					PooledConnection->SetState(EConnectionState::Invalid);
				}
				ConnectionPool->ReleaseConnection(PooledConnection);
			}
			
			return Response;
		}
		catch (const std::exception& Ex) {
			// Record failed request in exception case
			if (ConnectionPool && ConnectionPool->GetMetrics()) {
				ConnectionPool->GetMetrics()->RecordRequestResult(Key, false, DiversionHttp::EMetricEvent::NetworkError);
			}
			
			// Exception during request execution - invalidate the connection
			if (PooledConnection)
			{
				PooledConnection->SetState(EConnectionState::Invalid);
				ConnectionPool->ReleaseConnection(PooledConnection);
			}
			
			return HTTPCallResponse(UTF8_TO_TCHAR(Ex.what()));
		}
	}

	void SetPort(const FString& InPort)
	{
		FRWScopeLock WriteLock(AddressLock, SLT_Write);
		Port = TCHAR_TO_UTF8(*InPort);
	}

	void SetHost(const FString& InHost)
	{
		FRWScopeLock WriteLock(AddressLock, SLT_Write);
		Host = TCHAR_TO_UTF8(*InHost);
	}

	void SetUseSSL(bool InUseSSL)
	{
		FRWScopeLock WriteLock(AddressLock, SLT_Write);
		UseSSL = InUseSSL;
	}

	/** Atomically update host/port/ssl, only taking write lock if values actually changed. */
	void UpdateAddress(const FString& InHost, const FString& InPort, bool InUseSSL)
	{
		std::string NewHost = TCHAR_TO_UTF8(*InHost);
		std::string NewPort = TCHAR_TO_UTF8(*InPort);

		{
			FRWScopeLock ReadLock(AddressLock, SLT_ReadOnly);
			if (Host == NewHost && Port == NewPort && UseSSL == InUseSSL)
			{
				return;
			}
		}

		FRWScopeLock WriteLock(AddressLock, SLT_Write);
		Host = MoveTemp(NewHost);
		Port = MoveTemp(NewPort);
		UseSSL = InUseSSL;
	}

private:
	static FString GetCacheKey(DiversionHttp::HttpMethod Method, const FString& Url)
	{
		const TCHAR* MethodStr = TEXT("UNKNOWN");
		switch (Method)
		{
			case DiversionHttp::HttpMethod::GET: MethodStr = TEXT("GET"); break;
			case DiversionHttp::HttpMethod::POST: MethodStr = TEXT("POST"); break;
			case DiversionHttp::HttpMethod::PUT: MethodStr = TEXT("PUT"); break;
			case DiversionHttp::HttpMethod::DEL: MethodStr = TEXT("DELETE"); break;
		}
		return FString::Printf(TEXT("%s:%s"), MethodStr, *Url);
	}

	void AddIfNoneMatchHeader(DiversionHttp::HttpMethod Method, const FString& Url, TMap<FString, FString>& OutHeaders)
	{
		if (!OutHeaders.Contains(TEXT("If-None-Match")))
		{
			return;  // Client didn't request caching, skip.
		}

		const FString CacheKey = GetCacheKey(Method, Url);
		FScopeLock Lock(&ResponseCacheMutex);
		if (const FCachedResponse* Cached = ResponseCache.Find(CacheKey))
		{
			OutHeaders[TEXT("If-None-Match")] = Cached->ETag;
			UE_LOG(LogDiversionHttp, Verbose, TEXT("Using cached ETag for %s: %s"), *CacheKey, *Cached->ETag);
		}
		else
		{
			OutHeaders.Remove(TEXT("If-None-Match"));
			UE_LOG(LogDiversionHttp, Verbose, TEXT("No cached response for %s, removing If-None-Match header"), *CacheKey);
		}
	}

	void CacheResponse(DiversionHttp::HttpMethod Method, const FString& Url, const HTTPCallResponse& Response)
	{
		// Only cache successful responses with content
		if (Response.ResponseCode < 200 || Response.ResponseCode >= 300)
		{
			return;
		}

		// HTTP header names are case-insensitive per RFC 7230
		FString ETag;
		for (const auto& HeaderPair : Response.Headers)
		{
			if (HeaderPair.Key.Equals(TEXT("etag"), ESearchCase::IgnoreCase))
			{
				ETag = HeaderPair.Value;
				break;
			}
		}

		if (!ETag.IsEmpty())
		{
			const FString CacheKey = GetCacheKey(Method, Url);
			FScopeLock Lock(&ResponseCacheMutex);
			FCachedResponse CachedEntry;
			CachedEntry.ETag = ETag;
			CachedEntry.Response = Response;
			ResponseCache.Add(CacheKey, MoveTemp(CachedEntry));
			UE_LOG(LogDiversionHttp, Verbose, TEXT("Cached response for %s with ETag: %s"), *CacheKey, *ETag);
		}
	}

	void ConfigureSslContext() const
	{
		SslContext->set_default_verify_paths();
		SslContext->set_verify_mode(net::ssl::verify_peer);

		// Disable older protocols.
		SslContext->set_options(
			net::ssl::context::default_workarounds
			| net::ssl::context::no_sslv2
			| net::ssl::context::no_sslv3
			| net::ssl::context::single_dh_use);

#if PLATFORM_WINDOWS
		// OpenSSL doesn't work with Windows Certificate Store, so we need to provide the certificate manually
		FString PluginDir = IPluginManager::Get().FindPlugin(TEXT("Diversion"))->GetBaseDir();
		FString CertPath = FPaths::Combine(PluginDir, TEXT("Resources"), TEXT("cacert.pem"));
		SslContext->load_verify_file(TCHAR_TO_UTF8(*CertPath));
#endif
	}
	
	boost::beast::http::verb ExtractHttpVerb(DiversionHttp::HttpMethod Method) const
	{
		switch (Method)
		{
		case DiversionHttp::HttpMethod::GET:
			return http::verb::get;
		case DiversionHttp::HttpMethod::POST:
			return http::verb::post;
		case DiversionHttp::HttpMethod::PUT:
			return http::verb::put;
		case DiversionHttp::HttpMethod::DEL:
			return http::verb::delete_;
		default:
			throw std::runtime_error("Invalid or unsupported HTTP method");
		}
	}

	void BuildRequest(http::request<http::string_body>& OutRequest,
		const std::string& InHost, const FString& Url, DiversionHttp::HttpMethod Method, const FString& Token,
		const FString& ContentType, const FString& Content,
		const TMap<FString, FString>& Headers) const {
		OutRequest.version(httpVersion);
		OutRequest.method(ExtractHttpVerb(Method));
		OutRequest.target(TCHAR_TO_UTF8(*Url));
		OutRequest.set(http::field::host, InHost);
		OutRequest.set(http::field::user_agent, BOOST_BEAST_VERSION_STRING);
		OutRequest.set(http::field::content_type, TCHAR_TO_UTF8(*ContentType));
		OutRequest.set(http::field::accept_encoding, "gzip, deflate");

		if (!Token.IsEmpty()) {
			OutRequest.set(http::field::authorization, "Bearer " + std::string(TCHAR_TO_UTF8(*Token)));
		}

		// Set the extra headers
		for (const auto& Header : Headers) {
			OutRequest.set(TCHAR_TO_UTF8(*Header.Key), TCHAR_TO_UTF8(*Header.Value));
		}

		if (Method == DiversionHttp::HttpMethod::POST || Method == DiversionHttp::HttpMethod::PUT) {
			OutRequest.body() = TCHAR_TO_UTF8(*Content);
			OutRequest.prepare_payload();
		}
	}

private:
	void InitializeConnectionPool()
	{
		// Create default connection pool configuration with no hardcoded host settings
		ConnectionPoolConfig = FConnectionPoolConfig();

		// Initialize the connection pool
		ConnectionPool = std::make_unique<FConnectionPool>(
			ConnectionPoolConfig,
			std::shared_ptr<net::ssl::context>(SslContext.get(), [](net::ssl::context*){}), // Non-owning shared_ptr
			IoContextManager.GetIoContext());

		UE_LOG(LogDiversionHttp, Log, TEXT("Connection pool initialized for host %s:%s"),
			   UTF8_TO_TCHAR(Host.c_str()), UTF8_TO_TCHAR(Port.c_str()));
	}

	/**
	 * Callback invoked when the editor's focus state changes.
	 * Updates the bEditorHasFocus flag to track whether the editor window currently has focus.
	 * @param bIsFocused True if the editor gained focus, false if it lost focus
	 */
	void OnApplicationFocusChanged(const bool bIsFocused)
	{
		if (bIsShuttingDown.load())
		{
			return;
		}
		bEditorHasFocus.store(bIsFocused);
	}

private:
	IoContextManager IoContextManager;
	std::unique_ptr<boost::asio::ssl::context> SslContext;

	// Connection pool
	FConnectionPoolConfig ConnectionPoolConfig;
	std::unique_ptr<FConnectionPool> ConnectionPool;

	std::string Host;
	std::string Port;
	bool UseSSL;
	mutable FRWLock AddressLock;

	int httpVersion;

	/**
	 * If true, HTTP requests will only be processed when the editor has focus.
	 * When false, requests are processed regardless of focus state.
	 */
	bool bRequireEditorFocus;

	/**
	 * Handle for the delegate that tracks application focus changes.
	 * Used to register/unregister the focus change callback.
	 */
	FDelegateHandle FocusChangedHandle;

	/**
	 * Tracks whether the editor currently has focus.
	 * Atomic to allow safe access from multiple threads.
	 */
	std::atomic<bool> bEditorHasFocus;

	/**
	 * Flag to prevent focus callback execution during shutdown.
	 * Set to true at the start of the destructor to prevent race conditions.
	 */
	std::atomic<bool> bIsShuttingDown{false};
	// Cached response for conditional requests (stores ETag + full response body)
	struct FCachedResponse
	{
		FString ETag;
		HTTPCallResponse Response;
	};

	// LRU cache for response caching (URL -> FCachedResponse)
	// Size is configured via UDiversionConfig::ResponseCacheSize
	TLruCache<FString, FCachedResponse> ResponseCache;
	FCriticalSection ResponseCacheMutex;
};


namespace DiversionHttp {
	
	FHttpRequestManager::FHttpRequestManager(const FString& HostUrl, bool bRequireEditorFocus, const TMap<FString, FString>& DefaultHeaders, int HttpVersion) :
		Impl(MakeUnique<FHttpRequestManagerImpl>(ExtractHostFromUrl(HostUrl), ExtractPortFromUrl(HostUrl),
			IsEncrypted(HostUrl), HttpVersion, bRequireEditorFocus)),
		DefaultHeaders(DefaultHeaders)
	{}

	FHttpRequestManager::FHttpRequestManager(const FString& Host, const FString& Port, bool bRequireEditorFocus, const TMap<FString, FString>& DefaultHeaders,
		bool UseSSL, int HttpVersion) :
		Impl(MakeUnique<FHttpRequestManagerImpl>(Host, Port, UseSSL, HttpVersion, bRequireEditorFocus)),
		DefaultHeaders(DefaultHeaders)
	{}

	FHttpRequestManager::~FHttpRequestManager() = default;

	HTTPCallResponse FHttpRequestManager::SendRequest(const FString& Url, DiversionHttp::HttpMethod Method, const FString& Token,
		const FString& ContentType, const FString& Content, const TMap<FString, FString>& Headers,
		int ConnectionTimeoutSeconds, int RequestTimeoutSeconds) const
	{
		RefreshUrlFromProvider();
		TMap<FString, FString> RequestHeaders;
		RequestHeaders.Append(DefaultHeaders);
		RequestHeaders.Append(Headers);
		return Impl->SendRequest(Url, Method, Token, ContentType, Content,
			RequestHeaders, ConnectionTimeoutSeconds, RequestTimeoutSeconds, TEXT(""));
	}
	HTTPCallResponse FHttpRequestManager::DownloadFileFromUrl(const FString& OutputFilePath, const FString& Url, const FString& Token, 
		const TMap<FString, FString>& Headers, int ConnectionTimeoutSeconds, int RequestTimeoutSeconds) const
	{
		TMap<FString, FString> FileHeaders = {
			{TEXT("Accept"), TEXT("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7")},
			{TEXT("Accept-Encoding"), TEXT("gzip, deflate, br, zstd")}
		};

		TMap<FString, FString> RequestHeaders;
		RequestHeaders.Append(FileHeaders);
		RequestHeaders.Append(DefaultHeaders);
		RequestHeaders.Append(Headers);
		
		return Impl->SendRequest(Url, HttpMethod::GET, Token, TEXT("application/octet-stream"), "",
			RequestHeaders, ConnectionTimeoutSeconds, RequestTimeoutSeconds, OutputFilePath);
	}
	void FHttpRequestManager::SetHost(const FString& Host) const 
	{
		Impl->SetHost(Host);
	}
	void FHttpRequestManager::SetPort(const FString& Port) const 
	{
		Impl->SetPort(Port);
	}
	void FHttpRequestManager::SetUseSSL(const bool UseSSL) const 
	{
		Impl->SetUseSSL(UseSSL);
	}

	void FHttpRequestManager::SetDefaultHeaders(const TMap<FString, FString>& Headers)
	{
		DefaultHeaders = Headers;
	}

	void FHttpRequestManager::SetUrlProvider(TFunction<FString()> InUrlProvider)
	{
		UrlProvider = MoveTemp(InUrlProvider);
	}

	void FHttpRequestManager::RefreshUrlFromProvider() const
	{
		if (!UrlProvider)
		{
			return;
		}
		FString Url = UrlProvider();
		Impl->UpdateAddress(ExtractHostFromUrl(Url), ExtractPortFromUrl(Url), IsEncrypted(Url));
	}
}
