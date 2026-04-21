// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#include "DiversionCredentialsManager.h"
#include "HAL/PlatformProcess.h"
#include "HAL/PlatformFile.h"
#include "HAL/PlatformFileManager.h"
#include "Misc/FileHelper.h"
#include "HAL/FileManagerGeneric.h"
#include "Misc/Paths.h"
#include "TimerManager.h"

#include "DiversionHttpManager.h"

#if PLATFORM_WINDOWS
#include "Windows/AllowWindowsPlatformTypes.h"
#include <shlobj.h>
#include "Windows/HideWindowsPlatformTypes.h"
#endif

#include "Framework/Notifications/NotificationManager.h"
#include "Widgets/Notifications/SNotificationList.h"

#include "DiversionUtils.h"
#include "DiversionCommonUtils.h"


#if PLATFORM_LINUX
#endif


TSharedPtr<FJsonObject> FCredentialsManager::GetCredFileForUser(const FString& InUserId)
{
	// First check cache with read lock
	{
		FRWScopeLock ReadLock(CredentialsLock, SLT_ReadOnly);
		auto ExistingCredFilePtr = UserCredsMap.Find(InUserId);
		if (ExistingCredFilePtr != nullptr) {
			return *ExistingCredFilePtr;
		}
	}

	// Not in cache, read from disk (no lock needed for file I/O)
	FString FilePath = "";
	if (InUserId == "N/a") {
		auto CredDir = DiversionUtils::GetUserHomeDirectory() / TEXT(".diversion") / DIVERSION_CREDENTIALS_FOLDER;
		TArray<FString> FileNames;
		FFileManagerGeneric FileMgr;
		FileMgr.SetSandboxEnabled(true);
		FString wildcard("*");
		FString search_path(FPaths::Combine(CredDir, *wildcard));

		FileMgr.FindFiles(FileNames, *search_path, true, false);
		auto TargetUserId = InUserId;
		if (FileNames.Num() == 1) {
			TargetUserId = FileNames[0];
		}
		FilePath = CredDir / TargetUserId;
	}
	else {
		FilePath = DiversionUtils::GetUserHomeDirectory() / TEXT(".diversion") / DIVERSION_CREDENTIALS_FOLDER / InUserId;
	}

	FString JsonString;
	TSharedPtr<FJsonObject> JsonObject;

	if (FFileHelper::LoadFileToString(JsonString, *FilePath)) {
		TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonString);

		if (FJsonSerializer::Deserialize(Reader, JsonObject))
		{
			if (!JsonObject->HasField(TEXT("token"))) {
				UE_LOG(LogTemp, Error, TEXT("Token field not found."));
				return TSharedPtr<FJsonObject>();
			}
		}
		else {
			UE_LOG(LogTemp, Error, TEXT("Failed to deserialize credentials file."));
			return TSharedPtr<FJsonObject>();
		}
	}
	else {
		UE_LOG(LogTemp, Error, TEXT("Failed to load credentials file."));
		return TSharedPtr<FJsonObject>();
	}

	// Add to cache with write lock
	{
		FRWScopeLock WriteLock(CredentialsLock, SLT_Write);

		// Double-check: another thread might have just added it
		auto ExistingCredFilePtr = UserCredsMap.Find(InUserId);
		if (ExistingCredFilePtr != nullptr) {
			return *ExistingCredFilePtr;
		}

		UserCredsMap.Add(InUserId, JsonObject);
	}

	return JsonObject;
}

FString FCredentialsManager::GetUserAccessToken(const FString& InUserId)
{
	// GetCredFileForUser handles its own locking
	TSharedPtr<FJsonObject> ExistingCredFile = GetCredFileForUser(InUserId);

	if (!ExistingCredFile.IsValid()) {
		return "";
	}

	// Try to get token with read lock (allows multiple concurrent readers)
	FString AccessToken;
	bool NeedsRefresh = false;
	{
		FRWScopeLock ReadLock(CredentialsLock, SLT_ReadOnly);

		auto TokenObject = ExistingCredFile->GetObjectField(TEXT("token"));
		if (TokenObject->HasField(TEXT("access_token"))) {
			TokenObject->TryGetStringField(TEXT("access_token"), AccessToken);

			// Check if token is expired
			if (AccessTokenExpired(AccessToken)) {
				NeedsRefresh = true;
			}
		}
		else {
			// No access token exists, need to refresh
			NeedsRefresh = true;
		}
	} // Release read lock

	// If token doesn't need refresh, return it
	if (!NeedsRefresh) {
		return AccessToken;
	}

	// Token needs refresh - acquire write lock (exclusive access)
	{
		FRWScopeLock WriteLock(CredentialsLock, SLT_Write);

		// Double-check: another thread might have just refreshed the token
		auto TokenObject = ExistingCredFile->GetObjectField(TEXT("token"));
		if (TokenObject->HasField(TEXT("access_token"))) {
			TokenObject->TryGetStringField(TEXT("access_token"), AccessToken);

			// Check again if token is still expired
			if (!AccessTokenExpired(AccessToken)) {
				// Another thread just refreshed it, use that token
				return AccessToken;
			}
		}

		// Still needs refresh - we're the ones to do it
		AccessToken = RefreshAndCacheAccessToken(ExistingCredFile);
		return AccessToken;
	}
}

bool FCredentialsManager::AccessTokenExpired(FString AccessToken)
{
	TArray<FString> JwtComponents;
	AccessToken.ParseIntoArray(JwtComponents, TEXT("."), true);

	if (JwtComponents.Num() != 3)
	{
		UE_LOG(LogTemp, Error, TEXT("Invalid JWT"));
		return true;
	}

	FString EncodedPayload = JwtComponents[1];
	FString DecodedPayload;
	FBase64::Decode(EncodedPayload, DecodedPayload);

	TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject());
	TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(DecodedPayload);

	if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
	{
		int64 ExpiryTime = static_cast<int64>(JsonObject->GetNumberField(TEXT("exp")));
		const int64 ExpiryMarginSec = 60;
		FDateTime ExpiryDateTime = FDateTime::FromUnixTimestamp(ExpiryTime - ExpiryMarginSec);
		FDateTime Now = FDateTime::UtcNow();

		if (Now > ExpiryDateTime)
		{
			UE_LOG(LogTemp, Warning, TEXT("JWT has expired"));
		}
		else
		{
			return false;
		}
	}
	else {
		UE_LOG(LogTemp, Error, TEXT("Invalid JWT body"));
	}
	return true;
}

FString FCredentialsManager::RefreshAndCacheAccessToken(TSharedPtr<FJsonObject> ExistingCredFile) {
	const FString OauthURL = "https://auth.diversion.dev/oauth2/token";
	const FString ClientId = "nmm65ta2r48pvj1lsjcmoeb7l";
	FString RefreshToken;
	FString AccessToken;
	volatile bool DelegateDone = false;
	auto TokenObject = ExistingCredFile->GetObjectField(TEXT("token"));
	if (TokenObject->HasField(TEXT("refresh_token"))) {
		TokenObject->TryGetStringField(TEXT("refresh_token"), RefreshToken);

		TMap<FString, FString> Headers;
		FString ContentType = TEXT("application/x-www-form-urlencoded");
		//Headers.Add("Content-Type", ContentType);
		FString Body = FString::Printf(TEXT("grant_type=refresh_token&refresh_token=%s&client_id=%s"),
			*FString(RefreshToken), *FString(ClientId));
		DiversionHttp::FHttpRequestManager CredentialsRequestManager(OauthURL);
		FString RequestPath = DiversionHttp::GetPathFromUrl(OauthURL);

		auto Response = CredentialsRequestManager.SendRequest(RequestPath, DiversionHttp::HttpMethod::POST, FString(), ContentType, Body, Headers, 5, 120);
		if(Response.Error.IsSet()) {
			UE_LOG(LogTemp, Error, TEXT("Failed using the refresh token auth flow: %s"), *Response.GetErrorMessage());
			return "";
		}

		if(Response.ResponseCode >= 400) {
			FString ErrorResponse = Response.GetErrorMessage();
			UE_LOG(LogTemp, Error, TEXT("Failed using the refresh token auth flow: %d:%s"), Response.ResponseCode, *ErrorResponse);
			return "";
		}

		FString ResponseStr = Response.Contents;

		TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject());
		TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(ResponseStr);

		if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
		{
			AccessToken = JsonObject->GetStringField(TEXT("access_token"));
			FString TokenType = JsonObject->GetStringField(TEXT("token_type"));
			int32 ExpiresIn = JsonObject->GetIntegerField(TEXT("expires_in"));
			FString IdToken = JsonObject->GetStringField(TEXT("id_token"));
			if (TokenType != "Bearer") {
				UE_LOG(LogTemp, Warning, TEXT("Got a token of type != Bearer"));
			}
			TokenObject->SetStringField(TEXT("access_token"), AccessToken);
			ExistingCredFile->SetObjectField(TEXT("token"), TokenObject);
		}
	}
	else {
		UE_LOG(LogTemp, Error, TEXT("Refresh token field not found."));
	}
	return AccessToken;
}
