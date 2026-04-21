// Copyright 2024 Diversion Company, Inc. All Rights Reserved.
#include "IDiversionWorker.h"

#include "DiversionModule.h"
#include "DiversionProvider.h"
#include "PackageTools.h"
#include "ISourceControlModule.h"

#define LOCTEXT_NAMESPACE "Diversion"

bool IDiversionWorker::UpdateStates() const {
	ReleaseLockedPackages();
	return UpdateSyncStatus();
}

bool IDiversionWorker::UpdateSyncStatus() const {
	if (SyncStatus.IsSet()) {
		FDiversionProvider& Provider = FDiversionModule::Get().GetProvider();
		Provider.SetSyncStatus(SyncStatus.GetValue());
	}
	return true;
}

void IDiversionWorker::ReleaseLockedPackages() const
{
	bool RequiresReload = false;
	auto& Provider = FDiversionModule::Get().GetProvider();
	for (auto& LockdedPackagePath : OpenedPackagePaths) {
		RequiresReload |= Provider.TryUnloadingOpenedPackage(LockdedPackagePath);
	}
	if (RequiresReload) {
		FDiversionModule::Get().GetProvider().SetReloadStatus();
	}
}

#undef LOCTEXT_NAMESPACE