// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#include "DiversionUtils.h"
#include "DiversionCommand.h"
#include "DiversionModule.h"
#include "DiversionOperations.h"
#include "DiversionAPIAccess.h"
#include "RepositoryCommitManipulationApi.h"


#define LOCTEXT_NAMESPACE "Diversion"


using namespace Diversion::CoreAPI;


bool DiversionUtils::RunCommit(FDiversionCommand& InCommand, TArray<FString>& OutInfoMessages, TArray<FString>& OutErrorMessages, const FString& InDescription, bool WaitForSync)
{
	const auto ErrorResponse = RepositoryCommitManipulationApi::Fsrc_handlersv2_workspace_commitWorkspaceDelegate::Bind(
		[&](const TVariant<TSharedPtr<NewCommit>, void*, TSharedPtr<Src_handlersv2_workspace_commit_workspace_400_response>, TSharedPtr<Diversion::CoreAPI::Error>>&, int StatusCode) {
			const FText COMMIT_CONFLICT_ERROR_NOTIFICATION_MESSAGE = FText::FromString(
				"Unable to commit due to existing conflicts, "
				"please run update using the button below or the Diversion "
				"desktop app and resolve the conflicts to continue.");

			FNotificationButtonInfo UpdateButton(LOCTEXT("DiversionPopup_UpdateButton", "Update"),
				LOCTEXT("DiversionPopup_UpdateButton_Tooltip", "Update the workspace to show pull current changes and conflicts"),
				FSimpleDelegate::CreateLambda([]()
					{
						FDiversionModule::Get().GetProvider().Execute(ISourceControlOperation::Create<FUpdateWorkspaceOperation>(),
							nullptr, {}, EConcurrency::Asynchronous);
					}),
				SNotificationItem::CS_Fail);
			
			if (StatusCode == 409) {
				InCommand.PopupNotification = MakeUnique<FDiversionNotification>(
					COMMIT_CONFLICT_ERROR_NOTIFICATION_MESSAGE,
					TArray<FNotificationButtonInfo>({ UpdateButton }),SNotificationItem::CS_Fail);
			}
			return false;
		}
	);

	const auto VariantResponse = RepositoryCommitManipulationApi::Fsrc_handlersv2_workspace_commitWorkspaceDelegate::Bind(
		[&](const TVariant<TSharedPtr<NewCommit>, void*, TSharedPtr<Src_handlersv2_workspace_commit_workspace_400_response>, TSharedPtr<Diversion::CoreAPI::Error>>& Variant) {
			if (Variant.IsType<TSharedPtr<NewCommit>>()) {
				const auto Response = Variant.Get<TSharedPtr<NewCommit>>();
				InCommand.InfoMessages.Add(FString::Printf(TEXT("Commit %s was added successfully"), *Response->mId));
				return true;
			}

			return true;
		}
	);

	if (WaitForSync && !WaitForAgentSync(InCommand, OutInfoMessages, OutErrorMessages))
	{
		return false;
	}

	TOptional<TArray<FString>> CommitPaths;
	if (InCommand.Files.Num() > 0) {
		// Note! zero files means commit all!
		// This is for internal use as using UE UI its not possible to send 0 files
		CommitPaths = TArray<FString>();
	}
	for (auto& FilePath : InCommand.Files) {
		// TODO: Convert all file paths in the command to relative paths upon command creation
		auto RelativeFilePath = FilePath.Replace(*InCommand.WsInfo.GetPath(), TEXT(""));
		CommitPaths->Add(RelativeFilePath);
	}

	const TSharedPtr<CommitRequest> Request = MakeShared<CommitRequest>();
	Request->mCommit_message = InDescription;
	Request->mInclude_paths = CommitPaths;

	if (!FDiversionAPIAccess::RepositoryCommitManipulationAPI)
	{
		UE_LOG(LogSourceControl, Error, TEXT("RunCommit: API not initialized"));
		return false;
	}

	return FDiversionAPIAccess::RepositoryCommitManipulationAPI->SrcHandlersv2WorkspaceCommitWorkspace(InCommand.WsInfo.RepoID, InCommand.WsInfo.WorkspaceID, Request,
		FDiversionAPIAccess::GetAccessToken(InCommand.WsInfo.AccountID), {}, 5, 120).HandleApiResponse(ErrorResponse, VariantResponse, OutErrorMessages);
}

#undef LOCTEXT_NAMESPACE