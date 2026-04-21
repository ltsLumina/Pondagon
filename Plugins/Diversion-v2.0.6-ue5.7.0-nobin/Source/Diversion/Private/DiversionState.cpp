// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#include "DiversionState.h"
#include "RevisionControlStyle/RevisionControlStyle.h"
#include "Textures/SlateIcon.h"
#include "HAL/PlatformFileManager.h"

#include "DiversionModule.h"
#include "DiversionConfig.h"
#include "Conflict.h"

using namespace Diversion::CoreAPI::Model;

#define LOCTEXT_NAMESPACE "Diversion.State"

PRAGMA_DISABLE_DEPRECATION_WARNINGS

void PotentialClashesList::ResetPotentialClashes()
{
	FWriteScopeLock Lock(*PotentialClashesRWLock);
	PotentialClashes.Empty();
}

void PotentialClashesList::SetPotentialClashes(const TArray<EDiversionPotentialClashInfo>& InPotentialClashes)
{
	FWriteScopeLock Lock(*PotentialClashesRWLock);
	PotentialClashes = InPotentialClashes;
}

void PotentialClashesList::AddPotentialClash(const EDiversionPotentialClashInfo& ClashInfo)
{
	FWriteScopeLock Lock(*PotentialClashesRWLock);
	PotentialClashes.Add(ClashInfo);
}

int PotentialClashesList::GetPotentialClashesCount() const
{
	FReadScopeLock Lock(*PotentialClashesRWLock);
	return PotentialClashes.Num();
}

TArray<EDiversionPotentialClashInfo> PotentialClashesList::GetPotentialClashes() const
{
	FReadScopeLock Lock(*PotentialClashesRWLock);
	return PotentialClashes;
}

FDiversionState::FDiversionState(const FDiversionState& Other) = default;
FDiversionState::FDiversionState(FDiversionState&& Other) noexcept = default;
FDiversionState& FDiversionState::operator=(const FDiversionState& Other) = default;
FDiversionState& FDiversionState::operator=(FDiversionState&& Other) noexcept = default;
PRAGMA_ENABLE_DEPRECATION_WARNINGS

int32 FDiversionState::GetHistorySize() const
{
	return History.Num();
}

TSharedPtr<class ISourceControlRevision, ESPMode::ThreadSafe> FDiversionState::GetHistoryItem(int32 HistoryIndex) const
{
	if (!History.IsValidIndex(HistoryIndex))
	{
		DiversionUtils::DiversionValidityCheck(false,
			"HistoryIndex is out of range", FDiversionModule::Get().GetOriginalAccountID());
		return nullptr;
	}

	return History[HistoryIndex];
}

TSharedPtr<class ISourceControlRevision, ESPMode::ThreadSafe> FDiversionState::FindHistoryRevision(int32 RevisionNumber) const
{
	for (const auto& Revision : History)
	{
		if (Revision->GetRevisionNumber() == RevisionNumber)
		{
			return Revision;
		}
	}

	return nullptr;
}

TSharedPtr<class ISourceControlRevision, ESPMode::ThreadSafe> FDiversionState::FindHistoryRevision(const FString& InRevision) const
{
	for (const auto& Revision : History)
	{
		if (Revision->GetRevision() == InRevision)
		{
			return Revision;
		}
	}

	return nullptr;
}

TSharedPtr<class ISourceControlRevision, ESPMode::ThreadSafe> FDiversionState::GetCurrentRevision() const
{
	if (LocalRevNumber == INVALID_REVISION)
	{
		return nullptr;
	}

	return FindHistoryRevision(LocalRevNumber);
}

ISourceControlState::FResolveInfo FDiversionState::GetResolveInfo() const
{
	return PendingResolveInfo;
}

FSlateIcon FDiversionState::GetIcon() const
{
	if(IsSyncing)
	{
		return FSlateIcon(FRevisionControlStyleManager::GetStyleSetName(), "RevisionControl.Actions.Refresh");
	}
	if(IsConflicted())
	{
		if(PendingResolveInfo.ResolutionSide.IsSet())
		{
			return FSlateIcon(FRevisionControlStyleManager::GetStyleSetName(), "RevisionControl.ConflictResolution.Clear");
		}
		return FSlateIcon(FRevisionControlStyleManager::GetStyleSetName(), "RevisionControl.Conflicted");
	}

	switch (WorkingCopyState)
	{
	case EWorkingCopyState::Modified:
		return FSlateIcon(FRevisionControlStyleManager::GetStyleSetName(), "RevisionControl.CheckedOut");
	case EWorkingCopyState::Added:
		return FSlateIcon(FRevisionControlStyleManager::GetStyleSetName(), "RevisionControl.OpenForAdd");
	case EWorkingCopyState::Renamed:
	case EWorkingCopyState::Copied:
		return FSlateIcon(FRevisionControlStyleManager::GetStyleSetName(), "RevisionControl.Branched");
	case EWorkingCopyState::Deleted: // Deleted & Missing files does not show in Content Browser
	case EWorkingCopyState::Missing:
		return FSlateIcon(FRevisionControlStyleManager::GetStyleSetName(), "RevisionControl.MarkedForDelete");
	case EWorkingCopyState::NotControlled:
		return FSlateIcon(FRevisionControlStyleManager::GetStyleSetName(), "RevisionControl.NotInDepot");
	case EWorkingCopyState::Unknown:
	case EWorkingCopyState::Unchanged: // Unchanged is the same as "Pristine" (not checked out) for Perforce, ie no icon
	case EWorkingCopyState::Ignored:
	default:
		return FSlateIcon();
	}
}


FText FDiversionState::GetDisplayName() const
{
	if (IsSyncing)
	{
		return LOCTEXT("Syncing", "Syncing");
	}
	if(IsConflicted())
	{
		return LOCTEXT("ContentsConflict", "Contents Conflict");
	}

	switch(WorkingCopyState)
	{
	case EWorkingCopyState::Unknown:
		return LOCTEXT("Unknown", "Unknown");
	case EWorkingCopyState::Unchanged:
		return LOCTEXT("Unchanged", "Unchanged");
	case EWorkingCopyState::Added:
		return LOCTEXT("Added", "Added");
	case EWorkingCopyState::Deleted:
		return LOCTEXT("Deleted", "Deleted");
	case EWorkingCopyState::Modified:
		return LOCTEXT("Modified", "Modified");
	case EWorkingCopyState::Renamed:
		return LOCTEXT("Renamed", "Renamed");
	case EWorkingCopyState::Copied:
		return LOCTEXT("Copied", "Copied");
	case EWorkingCopyState::Ignored:
		return LOCTEXT("Ignored", "Ignored");
	case EWorkingCopyState::NotControlled:
		return LOCTEXT("NotControlled", "Not Under Revision Control");
	case EWorkingCopyState::Missing:
		return LOCTEXT("Missing", "Missing");
	}

	return FText();
}

FText FDiversionState::GetDisplayTooltip() const
{
	if(IsSyncing)
	{
		return LOCTEXT("Syncing_Tooltip", "Syncing item state with the server");
	}
	if(IsConflicted())
	{
		if(PendingResolveInfo.ResolutionSide.IsSet())
		{
			switch (PendingResolveInfo.ResolutionSide.GetValue())
			{
				case Conflict::Resolved_sideEnum::BASE:
					return LOCTEXT("ContentsConflict_Tooltip_AcceptCurrent", "File conflict resolved to 'Current'.");
				case Conflict::Resolved_sideEnum::OTHER:
					return LOCTEXT("ContentsConflict_Tooltip_AcceptIncoming", "File conflict resolved to 'Incoming'.");
				case Conflict::Resolved_sideEnum::RESULT:
					return LOCTEXT("ContentsConflict_Tooltip_AcceptCombined", "File conflict resolved to 'Combined'.");
			}
		}
		return LOCTEXT("ContentsConflict_Tooltip", "The contents of the item conflict with updates received from the repository.");
	}

	switch(WorkingCopyState)
	{
	case EWorkingCopyState::Unknown:
		return LOCTEXT("Unknown_Tooltip", "Unknown revision control state");
	case EWorkingCopyState::Unchanged:
		return LOCTEXT("Pristine_Tooltip", "There are no modifications");
	case EWorkingCopyState::Added:
		return LOCTEXT("Added_Tooltip", "Item is scheduled for addition");
	case EWorkingCopyState::Deleted:
		return LOCTEXT("Deleted_Tooltip", "Item is scheduled for deletion");
	case EWorkingCopyState::Modified:
		return LOCTEXT("Modified_Tooltip", "Item has been modified");
	case EWorkingCopyState::Renamed:
		return LOCTEXT("Renamed_Tooltip", "Item has been renamed");
	case EWorkingCopyState::Copied:
		return LOCTEXT("Copied_Tooltip", "Item has been copied");
	case EWorkingCopyState::Ignored:
		return LOCTEXT("Ignored_Tooltip", "Item is being ignored.");
	case EWorkingCopyState::NotControlled:
		return LOCTEXT("NotControlled_Tooltip", "Item is not under version control.");
	case EWorkingCopyState::Missing:
		return LOCTEXT("Missing_Tooltip", "Item is missing (e.g., you moved or deleted it without using Diversion). This also indicates that a directory is incomplete (a checkout or update was interrupted).");
	}

	return FText();
}

const FString& FDiversionState::GetFilename() const
{
	return LocalFilename;
}

const FDateTime& FDiversionState::GetTimeStamp() const
{
	return TimeStamp;
}

// Deleted and Missing assets cannot appear in the Content Browser, but the do in the Submit files to Version Control window!
bool FDiversionState::CanCheckIn() const
{
	return !IsAutoSoftLocked() && (
		WorkingCopyState == EWorkingCopyState::Added
		|| WorkingCopyState == EWorkingCopyState::Deleted
		|| WorkingCopyState == EWorkingCopyState::Missing
		|| WorkingCopyState == EWorkingCopyState::Modified
		|| WorkingCopyState == EWorkingCopyState::Renamed);
}

bool FDiversionState::CanCheckout() const
{
	return false; // With Diversion all tracked files in the working copy are always already checked-out (as opposed to Perforce)
}

bool FDiversionState::IsCheckedOut() const
{
	// Override feature to set an object to be unchecked-out
	// This is used to overcome perforce specific code of the Changelist validation
	// See PreChangelistValidationDelegateWrapper in DiversionSourceControlProvider.cpp
	if (bOverrideDefaultCheckout) {
		return false;
	}

	// By default all files are checked out in Diversion, if a file is being edited by someone else we would like
	// to "unchecked-out" it.
	return (IsSourceControlled() && !IsAutoSoftLocked());
}

bool FDiversionState::IsCheckedOutOther(FString* Who) const
{
	return
		IsDiversionSoftLockEnabled() && // Disable this feature if the user wants to
		(PotentialClashes.GetPotentialClashesCount() > 0) &&
		!IsConflicted(); // If the file is already conflicted, we don't want to auto lock it
}

bool FDiversionState::IsCurrent() const
{
	return true; // @todo check the state of the HEAD versus the state of tracked branch on remote
}

bool FDiversionState::IsSourceControlled() const
{
	return WorkingCopyState != EWorkingCopyState::NotControlled && WorkingCopyState != EWorkingCopyState::Ignored && WorkingCopyState != EWorkingCopyState::Unknown;
}

bool FDiversionState::IsAdded() const
{
	return WorkingCopyState == EWorkingCopyState::Added;
}

bool FDiversionState::IsDeleted() const
{
	return WorkingCopyState == EWorkingCopyState::Deleted || WorkingCopyState == EWorkingCopyState::Missing;
}

bool FDiversionState::IsIgnored() const
{
	return WorkingCopyState == EWorkingCopyState::Ignored;
}

bool FDiversionState::CanEdit() const
{
	return true; // With Diversion all files in the working copy are always editable (as opposed to Perforce)
}

bool FDiversionState::CanDelete() const
{
	return IsSourceControlled() && IsCurrent();
}

bool FDiversionState::IsUnknown() const
{
	return WorkingCopyState == EWorkingCopyState::Unknown;
}

bool FDiversionState::IsModified() const
{
	// @todo
	// Warning: for Perforce, a checked-out file is locked for modification (whereas with Diversion all tracked files are checked-out),
	// so for a clean "check-in" (commit) checked-out files unmodified should be removed from the changeset (the index)
	// http://stackoverflow.com/questions/12357971/what-does-revert-unchanged-files-mean-in-perforce
	//
	// Thus, before check-in UE Editor call RevertUnchangedFiles() in PromptForCheckin() and CheckinFiles().
	//
	// So here we must take care to enumerate all states that need to be commited,
	// all other will be discarded :
	//  - Unknown
	//  - Unchanged
	//  - NotControlled
	//  - Ignored
	return WorkingCopyState == EWorkingCopyState::Added
		|| WorkingCopyState == EWorkingCopyState::Deleted
		|| WorkingCopyState == EWorkingCopyState::Modified
		|| WorkingCopyState == EWorkingCopyState::Renamed
		|| WorkingCopyState == EWorkingCopyState::Copied
		|| WorkingCopyState == EWorkingCopyState::Missing;
}


bool FDiversionState::CanAdd() const
{
	return WorkingCopyState == EWorkingCopyState::NotControlled;
}

bool FDiversionState::IsConflicted() const
{
	return PendingResolveInfo;
}

bool FDiversionState::CanRevert() const
{
	return CanCheckIn();
}

bool FDiversionState::IsAutoSoftLocked() const
{
	return
		IsDiversionSoftLockEnabled() && // Disable this feature if the user wants to
		(IsCheckedOutOther() && !IsModified());
}

void FDiversionState::SetStateFromDiskPresence()
{
	if (FPaths::FileExists(LocalFilename) || FPaths::DirectoryExists(LocalFilename))
	{
		WorkingCopyState = EWorkingCopyState::Unchanged;
		TimeStamp = FPlatformFileManager::Get().GetPlatformFile().GetTimeStamp(*LocalFilename);
	}
}

void FDiversionState::ResetState()
{
	WorkingCopyState = EWorkingCopyState::Unchanged;
	PotentialClashes.ResetPotentialClashes();
	TimeStamp = FDateTime::MinValue();
	IsSyncing = false;
}

FString FDiversionState::GetOtherEditorsList() const {
	// Generate a local copy of the potential clashes array
	// Used since this array might get changed in the background by the worker thread
	TArray<EDiversionPotentialClashInfo> PotentialClashesCopy = PotentialClashes.GetPotentialClashes();
	
	FString OtherEditors = "Potential Conflict!\nFile is also edited by:";
	for (int i = 0; i < PotentialClashesCopy.Num(); i++) {
		const auto& Clash = PotentialClashesCopy[i];
		FString Name = !Clash.FullName.IsEmpty() ? Clash.FullName : Clash.Email;
		OtherEditors += FString::Printf(TEXT("\n%s at %s on branch %s (%s)"), *Name, 
			*FDateTime::FromUnixTimestamp(Clash.Mtime).ToString(), *Clash.BranchName, !Clash.WorkspaceID.IsEmpty() ? TEXT("not-committed") : TEXT("committed"));
		constexpr int MAX_OTHER_EDITORS = 4;
		if (i > MAX_OTHER_EDITORS) {
			OtherEditors += FString::Printf(TEXT("\n... and %d more"), PotentialClashesCopy.Num() - i);
			break;
		}
	}
	return OtherEditors;
}

void FDiversionState::ClearResolveInfo()
{
	PendingResolveInfo.RemoteRevision.Empty();
	PendingResolveInfo.RemoteFile.Empty();
}

const FDiversionResolveInfo& FDiversionState::GetPendingResolveInfo() const
{
	return PendingResolveInfo;
}

void FDiversionState::AddPendingResolveInfo(const FDiversionResolveInfo& InResolveInfo)
{
	PendingResolveInfo = InResolveInfo;
}

#undef LOCTEXT_NAMESPACE
