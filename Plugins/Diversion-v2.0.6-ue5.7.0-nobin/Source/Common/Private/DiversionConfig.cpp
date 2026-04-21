// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#include "DiversionConfig.h"
#include "UObject/Package.h"

UDiversionConfig::UDiversionConfig()
{
}

bool IsDiversionSoftLockEnabled()
{
        const UDiversionConfig* ConcertClientConfig = GetDefault<UDiversionConfig>();
        return ConcertClientConfig->bEnableSoftLock;
}

bool IsDiversionChangesWatcherEnabled()
{
        const UDiversionConfig* DiversionConfig = GetDefault<UDiversionConfig>();
        return DiversionConfig->bEnableChangesWatcher;
}

int32 GetDiversionResponseCacheSize()
{
        const UDiversionConfig* DiversionConfig = GetDefault<UDiversionConfig>();
        return FMath::Max(10, DiversionConfig->ResponseCacheSize);
}
