// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#pragma once

#include "HAL/CriticalSection.h"

class FCredentialsManager
{

public:
	FString GetUserAccessToken(const FString& InUserId);

private:

	TMap<FString, TSharedPtr<FJsonObject>> UserCredsMap;

	FString RefreshAndCacheAccessToken(TSharedPtr<FJsonObject> ExistingCredFile);

	TSharedPtr<FJsonObject> GetCredFileForUser(const FString& InUserId);

	bool AccessTokenExpired(FString AccessToken);

	// Read-write lock to allow multiple concurrent readers but exclusive writer
	// Protects UserCredsMap and prevents multiple simultaneous token refreshes
	FRWLock CredentialsLock;
};
