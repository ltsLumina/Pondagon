// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "UObject/ObjectMacros.h"
#include "UObject/SoftObjectPath.h"

#include "DiversionConfig.generated.h"

UCLASS(config = Editor, defaultconfig)
class COMMON_API UDiversionConfig : public UObject
{
        GENERATED_BODY()
public:
        UDiversionConfig();

        /*
         * Mark this setting object as editor only.
         * This so soft object path reference made by this setting object won't be automatically grabbed by the cooker.
         * @see UPackage::Save, FSoftObjectPathThreadContext::GetSerializationOptions, FSoftObjectPath::ImportTextItem
         */
        virtual bool IsEditorOnly() const override
        {
                return true;
        }
        /**
         * True if this client should be "headless"? (ie, not display any UI).
         */
        UPROPERTY(config, EditAnywhere, Category="General Settings", Meta=(ConfigRestartRequired=false,
                DisplayName="Enable Diversion Auto Soft Lock Confirmations",
                Tooltip="If unchecked, Diversion will not warn for potential conflicts before opening and saving files that have been modified in another branch or workspace"))
        bool bEnableSoftLock = true;

        /**
         * Enable automatic reload of externally modified files.
         */
        UPROPERTY(config, EditAnywhere, Category="General Settings", Meta=(ConfigRestartRequired=true,
                DisplayName="Enable External Changes Watcher",
                Tooltip="If checked, Diversion will automatically detect and reload files that have been modified externally. e.g. by switching branches, resetting changes from the app etc. (requires editor restart)"))
        bool bEnableChangesWatcher = false;

        /**
         * Maximum number of HTTP responses to cache for ETag-based caching.
         * Higher values use more memory but may reduce network requests for unchanged resources.
         */
        UPROPERTY(config, EditAnywhere, Category="Advanced Settings", Meta=(ConfigRestartRequired=true,
                DisplayName="HTTP Response Cache Size",
                Tooltip="Maximum number of HTTP responses to cache for conditional requests (ETag caching). Higher values use more memory but may reduce network requests. Minimum: 10. (requires editor restart)",
                ClampMin=10))
        int32 ResponseCacheSize = 100;
};

COMMON_API bool IsDiversionSoftLockEnabled();
COMMON_API bool IsDiversionChangesWatcherEnabled();
COMMON_API int32 GetDiversionResponseCacheSize();
