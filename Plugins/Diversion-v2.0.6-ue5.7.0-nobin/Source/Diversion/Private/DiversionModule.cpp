// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#include "DiversionModule.h"

#include "DiversionOperations.h"
#include "DiversionCredentialsManager.h"
#include "Features/IModularFeatures.h"
#include "Interfaces/IPluginManager.h"
#include "Misc/App.h"
#include "Modules/ModuleManager.h"
#include "RevisionControlStyle/RevisionControlStyle.h"
#include "DiversionStyle.h"

#include "CustomWidgets/ConfirmationDialog.h"
#include "CustomWidgets/DiversionSceneOutlinerColumn.h"

#include "AssetToolsModule.h"
#include "SourceControlOperations.h"
#include "FileHelpers.h"

// Enable plugin config
#include "ISettingsModule.h"
#include "DiversionConfig.h"
#include "DiversionAPIAccess.h"

#define LOCTEXT_NAMESPACE "Diversion"

template<typename Type>
static TSharedRef<IDiversionWorker, ESPMode::ThreadSafe> CreateWorker()
{
	return MakeShareable(new Type());
}

void FDiversionModule::StartupModule()
{
	// Skip initialization in commandlet mode (e.g., during cook/build)
	// Diversion is a UI extension that's not needed in non-interactive modes
	if (FApp::IsUnattended() || IsRunningCommandlet())
	{
		return;
	}

	// Mark as initialized - set early to preserve existing shutdown behavior
	// (if initialization fails partway, shutdown should still clean up)
	bIsInitialized = true;

	ServiceStatusLock =  MakeUnique<FRWLock>();

	// Initialize static API access - this creates and owns all API managers
	// Worker threads will access APIs through this static interface
	FDiversionAPIAccess::Initialize(OriginalAccountID);

	// Register our operations
	// Note: this provider does not uses the "CheckOut" command, which is a Perforce "lock", as Diversion has no lock command (all tracked files in the working copy are always already checked-out).
	DiversionProvider.RegisterWorker("Connect", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionConnectWorker>));
	DiversionProvider.RegisterWorker("UpdateStatus", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionUpdateStatusWorker>));
	DiversionProvider.RegisterWorker("MarkForAdd", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionMarkForAddWorker>));
	DiversionProvider.RegisterWorker("Delete", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionDeleteWorker>));
	DiversionProvider.RegisterWorker("Copy", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionCopyWorker>));
	DiversionProvider.RegisterWorker("CheckIn", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionCheckInWorker>));
	DiversionProvider.RegisterWorker("Revert", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionRevertWorker>));
	DiversionProvider.RegisterWorker("Resolve", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionResolveWorker>));
	DiversionProvider.RegisterWorker("Sync", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionSyncWorker>));
	DiversionProvider.RegisterWorker("UpdateChangelistsStatus", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionGetPendingChangelistsWorker>));
	
	// Unsupported operations (irrelevant for diversion)
	DiversionProvider.RegisterWorker("NewChangelist", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionOperationNotSupportedWorker>));
	DiversionProvider.RegisterWorker("Shelve", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionOperationNotSupportedWorker>));
	DiversionProvider.RegisterWorker("Unshelve", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionOperationNotSupportedWorker>));
	DiversionProvider.RegisterWorker("DeleteChangelist", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionOperationNotSupportedWorker>));
	DiversionProvider.RegisterWorker("EditChangelist", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionOperationNotSupportedWorker>));
	DiversionProvider.RegisterWorker("RevertUnchanged", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionOperationNotSupportedWorker>));
	DiversionProvider.RegisterWorker("MoveToChangelist", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionOperationNotSupportedWorker>));
	DiversionProvider.RegisterWorker("DeleteShelved", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionOperationNotSupportedWorker>));


	// Diversion Operations workers
	DiversionProvider.RegisterWorker("SendAnalytics", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionAnalyticsEventWorker>));
	DiversionProvider.RegisterWorker("AgentHealthCheck", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionAgentHealthCheckWorker>));
	DiversionProvider.RegisterWorker("GetWsInfo", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionWsInfoWorker>));
	DiversionProvider.RegisterWorker("InitRepo", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionInitRepoWorker>));
	DiversionProvider.RegisterWorker("FinalizeMerge", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionFinalizeMergeWorker>));
	DiversionProvider.RegisterWorker("ResolveFile", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionResolveFileWorker>));
	DiversionProvider.RegisterWorker("UpdateWorkspace", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionUpdateWorkspaceWorker>));
	DiversionProvider.RegisterWorker("GetPotentialClashes", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionGetPotentialClashes>));
	DiversionProvider.RegisterWorker("GetConflictedFiles", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionGetConflictedFiles>));
	DiversionProvider.RegisterWorker("CheckIfWorkspaceExistsInPath", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionCheckIfWorkspaceExistsInPathWorker>));
	DiversionProvider.RegisterWorker("CheckForRepoWithSameName", FGetDiversionWorker::CreateStatic(&CreateWorker<FDiversionCheckForRepoWithSameNameWorker>));
	// load our settings
	DiversionSettings.LoadSettings();

	// Bind our version control provider to the editor
	IModularFeatures::Get().RegisterModularFeature("SourceControl", &DiversionProvider);
	OpenedEditorAssets.Empty();

	if(ISettingsModule* SettingsModule = FModuleManager::GetModulePtr<ISettingsModule>("Settings"))
	{
		SettingsModule->RegisterSettings("Project", "Plugins", "Diversion",
			LOCTEXT("DiversionSettingsName", "Diversion"),
			LOCTEXT("DiversionSettingsDescription", "Configure the Diversion plugin"),
			GetMutableDefault<UDiversionConfig>());
	}
	
	GEditor->GetEditorSubsystem<UAssetEditorSubsystem>()->OnAssetEditorOpened().AddRaw(this,
		&FDiversionModule::HandleAssetOpenedInEditor);

	// Initialize Diversion style set for icons
	FDiversionStyle::Initialize();

	// Register Scene Outliner column for potential clash indicators
	FDiversionPotentialClashColumn::RegisterColumnType();
}

void FDiversionModule::ShutdownModule()
{
	// Skip cleanup if we never initialized (commandlet mode)
	if (!bIsInitialized)
	{
		return;
	}

	// Shut down the provider first - this ensures all worker threads are completed
	DiversionProvider.Close();

	// Now it's safe to clear static API access after all workers have finished
	FDiversionAPIAccess::Shutdown();

	if(ISettingsModule* SettingsModule = FModuleManager::GetModulePtr<ISettingsModule>("Settings"))
	{
		// Unregister Diversion settings
		SettingsModule->UnregisterSettings("Project", "Plugins", "Diversion");
	}
	
	// Shutdown Diversion style set
	FDiversionStyle::Shutdown();

	// Unregister Scene Outliner column
	FDiversionPotentialClashColumn::UnregisterColumnType();

	// unbind provider from editor
	IModularFeatures::Get().UnregisterModularFeature("SourceControl", &DiversionProvider);
}


void FDiversionModule::SaveSettings()
{
	if (FApp::IsUnattended() || IsRunningCommandlet())
	{
		return;
	}

	DiversionSettings.SaveSettings();
}

FDiversionModule& FDiversionModule::Get()
{
	return FModuleManager::GetModuleChecked<FDiversionModule>("Diversion");
}

bool FDiversionModule::IsLoaded()
{
	return FModuleManager::Get().IsModuleLoaded("Diversion");
}

const TSharedPtr<IPlugin> FDiversionModule::GetPlugin()
{
	return IPluginManager::Get().FindPlugin(TEXT("Diversion"));;
}

FString FDiversionModule::GetPluginVersion() {
	auto Plugin = GetPlugin();
	if (!Plugin.IsValid()) {
		return "N/a";
	}
	return Plugin->GetDescriptor().VersionName;
}

void FDiversionModule::HandleAssetOpenedInEditor(UObject* Asset)
{
	if(!IsDiversionSoftLockEnabled())
	{
		// The user disabled this feature
		// This is to aviod unnecessary API call to
		// get potential conflicts
		return;
	}
	/**
	* OnAssetEditorOpened
	* This is an event response that is fired once an asset was finished opening (but not yet presented to the screen).
	*
	* Function flow:
	* Open the asset for the first time and try to figure out if we need to show confirmation dialog
	* In case yes - show the dialog
	* If the Asset can be opened as read-only (Decided by UE), there will be a "read-only" button in the dialog
	* If the user clicked on "read-only" - open the asset as read-only and add it to the set of opened assets.
	* In order to perform "read-only" opening, the asset editor window needs to be closed first.
	* Since we don't want to show the dialog again when opening for read-only,
	* we need to filter out the re-opening of the asset editor window.
	* Which is done by the code:
	* 	OpenedEditorAssets.Add(AssetPath);
	* And filtered by:
	* 	bool IsReopeningWindowAsReadOnly = OpenedEditorAssets.Contains(AssetPath);
	*	if (IsReopeningWindowAsReadOnly) {
	*		OpenedEditorAssets.Remove(AssetPath);
	*		return;
	*	}
	* In the function beginning.
	* In all other cases, either close the window (user chose cancel or X button)
	* or open the asset for editing (user chose "Open For Edit").
	 */
	if (Asset == nullptr) {
		UE_LOG(LogSourceControl, Warning, TEXT("Editor opening event received an empty asset"));
		return;
	}

	// Understand if this is a potential conflicted asset
	if(!PotentialConflictExistForAsset(Asset))
	{
		return;
	}

	FString AssetPath = Asset->GetPathName();
	
	// Filter out the re-opening of the asset editor window
	// Since this is event response to file that already been opened (implied by the delegate call)
	// I need to know when a reopening event was triggered by the plugin code and ignore it
	// (Not the user-induced original opening of the asset editor).
	// This adds it to a set that enables me to decide if the editor was re-opened,
	// so ignoring it in the function start,
	// or was it originally opened by the user, so continue normally.
	bool IsReopeningWindowAsReadOnly = OpenedEditorAssets.Contains(AssetPath);
	if (IsReopeningWindowAsReadOnly) {
		OpenedEditorAssets.Remove(AssetPath);
		return;
	}

	ShowPotentialConflictConfirmationDialog(Asset);
}

bool FDiversionModule::PotentialConflictExistForAsset(UObject* Asset)
{
	ISourceControlProvider& SourceControlProvider = ISourceControlModule::Get().GetProvider();
	if (!(ISourceControlModule::Get().IsEnabled() && SourceControlProvider.IsAvailable())) {
		UE_LOG(LogSourceControl, Warning, TEXT("Source control is not available"));
		return false;
	}
	
	// Run update status to get the most recent file state from BE
	FString FilePath = FPaths::ConvertRelativePathToFull(DiversionUtils::GetFilePathFromAssetData(FAssetData(Asset)));
	auto& Provider = FDiversionModule::Get().GetProvider();
	Provider.Execute(ISourceControlOperation::Create<FGetPotentialClashes>(), nullptr,
		{FilePath},
		EConcurrency::Synchronous);

	// Try getting Assets Diversion state
	UPackage* CurPackage = Asset->GetOutermost();
	FSourceControlStatePtr SourceControlState = SourceControlProvider.GetState(CurPackage, EStateCacheUsage::Use);
	TSharedPtr<FDiversionState> DiversionState = StaticCastSharedPtr<FDiversionState>(SourceControlState);
	if(!DiversionUtils::DiversionValidityCheck(DiversionState.IsValid(),
		"Failed converting SourceControlState to DiversionState",
		GetOriginalAccountID()))
	{
		return false;
	}
	
	if(!DiversionState->IsCheckedOutOther()) {
		// Asset is not checked out by another user
		return false;
	}

	return true;
}

void FDiversionModule::ShowPotentialConflictConfirmationDialog(UObject* Asset)
{
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 4
	bool AssetCanBeReadOnly = GEditor->GetEditorSubsystem<UAssetEditorSubsystem>()->CanOpenEditorForAsset(Asset,
			EAssetTypeActivationOpenedMethod::View, nullptr);
#else
	// The function CanOpenEditorForAsset is not available in UE 5.3 and below - default to false
	bool AssetCanBeReadOnly = false;
#endif

	FString AssetName = Asset->GetName();
	FString AssetPath = Asset->GetOutermost()->GetPathName();
	// Making sure to show a value
	AssetPath = !AssetPath.IsEmpty() ? AssetPath : AssetName;
		
	EAppMsgType::Type MessageType = AssetCanBeReadOnly ? EAppMsgType::YesNoCancel : EAppMsgType::OkCancel;
	FText Title = LOCTEXT("DiversionPotentialClashTitle", "Diversion - Auto Soft-Locked Asset");
	FText Message = FText::Format(LOCTEXT("AutoSoftLockMessage",
		"Trying to open: “{0}”\n\nA newer version of this asset exists in another workspace and it was automatically soft-locked. The file can be opened for viewing and editing, but if changes are saved a conflict might be created - proceed with caution.\n\nTo see who is editing this file, close this dialog and hover the file in the Content Drawer."),
		 FText::FromString(AssetPath));

	TSharedRef<SWindow> DialogWindow = SNew(SWindow)
		.Title(Title)
		.SizingRule(ESizingRule::Autosized)
		.AutoCenter(EAutoCenter::PreferredWorkArea)
		.SupportsMinimize(false).SupportsMaximize(false);

	const int X_BUTTON_IDENTIFIER = -1;
	const int READ_ONLY_BUTTON_IDENTIFIER = 0;
	TArray<TSharedRef<FConfirmationOption>> Buttons;
	if (AssetCanBeReadOnly) {
		Buttons.Add(
			MakeShared<FConfirmationOption>(FText::FromString("Read Only"), READ_ONLY_BUTTON_IDENTIFIER,
				&FAppStyle::Get().GetWidgetStyle<FButtonStyle>("PrimaryButton"),
				false)
		);
	}

	const int CLOSE_BUTTON_IDENTIFIER = 1;
	const int OPEN_FOR_EDIT_BUTTON_IDENTIFIER = 2;
	Buttons.Append({
		MakeShared<FConfirmationOption>(FText::FromString("Close"), CLOSE_BUTTON_IDENTIFIER,
			nullptr, false),
		MakeShared<FConfirmationOption>(FText::FromString("Open For Edit"), OPEN_FOR_EDIT_BUTTON_IDENTIFIER,
			&FAppStyle::Get().GetWidgetStyle<FButtonStyle>("FlatButton.Danger"),
			true)
	});
	
	TArray<TSharedRef<FConfirmationAdditionalLink>> AdditionalLinks = {
		MakeShared<FConfirmationAdditionalLink>(
		LOCTEXT("Feedback_Text", "Feedback"),
		LOCTEXT("Feedback_Tooltip","This is an experimental feature. Your feedback is valuable to us! If you are having issues please let us know."),
		[]()
		{
			FPlatformProcess::LaunchURL(TEXT("https://www.diversion.dev/plugin-support"), nullptr, nullptr);
			
			auto SendAnalyticsOperation = ISourceControlOperation::Create<FSendAnalytics>();
			SendAnalyticsOperation->SetEventName(FText::FromString("UE Feedback"));
			SendAnalyticsOperation->SetEventProperties({{"feedback_source", "soft_lock_confirmation"}});
			auto& Provider = FDiversionModule::Get().GetProvider();
			Provider.Execute(SendAnalyticsOperation, nullptr, TArray<FString>(), EConcurrency::Asynchronous);
		}
		),
		MakeShared<FConfirmationAdditionalLink>(
		LOCTEXT("Disabled_Text", "Disable"),
		LOCTEXT("Feedback_Tooltip", "To disable this feature, click here to open the settings dialog and uncheck “Enable Diversion Auto Soft Lock Confirmations”"),
		[DialogWindow](){
				// Close the current dialog to enable the settings dialog opening
				DialogWindow->RequestDestroyWindow();
			
				auto SendAnalyticsOperation = ISourceControlOperation::Create<FSendAnalytics>();
				SendAnalyticsOperation->SetEventName(FText::FromString("UE Disable SoftLock Clicked"));
				auto& Provider = FDiversionModule::Get().GetProvider();
				Provider.Execute(SendAnalyticsOperation, nullptr, TArray<FString>(), EConcurrency::Asynchronous);
			
				// Open the settings dialog
				ISettingsModule* SettingsModule = FModuleManager::GetModulePtr<ISettingsModule>("Settings");
				if (SettingsModule)
				{
					SettingsModule->ShowViewer("Project", "Plugins", "Diversion");
				}
			}
		)
	};

	TSharedRef<SConfirmationDialog> ConfirmationDialog = SNew(SConfirmationDialog)
		.ParentWindow(DialogWindow)
		.Message(Message)
		.Buttons(Buttons)
		.AdditionalLinks(AdditionalLinks)
		.ExtraConfirmationText(FText::FromString("I understand editing this file might create a conflict, let me in"))
		.DefaultExtraConfirmState(&bConflictedFileOpenConfirmCheckboxState);
	
	// Open ConfirmationDialog
	DialogWindow->SetContent(
		ConfirmationDialog
	);

	FSlateApplication::Get().AddModalWindow(DialogWindow, nullptr);
	auto SelectedActionText = "";
	switch (ConfirmationDialog->GetResult()) {
	case X_BUTTON_IDENTIFIER:
	case CLOSE_BUTTON_IDENTIFIER:
		// Clicked on "Close"
		if (Asset->IsA<UWorld>())
		{
			// Schedule reloading the previously opened level
			FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateLambda([this](float DeltaTime)
			{
				FEditorFileUtils::LoadDefaultMapAtStartup();
				return false; // Don't repeat
			}), 0.0f); // Delay in seconds
		}
		else
		{
			// For other assets, close any open editors
			GEditor->GetEditorSubsystem<UAssetEditorSubsystem>()->CloseAllEditorsForAsset(Asset);
		}
		SelectedActionText = "Close";
		break;
	case READ_ONLY_BUTTON_IDENTIFIER:
		// Clicked on "Read Only"
		// This adds the path to the list that in the second trigger of this handler
		// Will know to ignore it since it's the reopening as a read-only
		OpenedEditorAssets.Add(Asset->GetPathName());
		GEditor->GetEditorSubsystem<UAssetEditorSubsystem>()->CloseAllEditorsForAsset(Asset);
		GEditor->GetEditorSubsystem<UAssetEditorSubsystem>()->OpenEditorForAsset(Asset,
			EToolkitMode::Standalone, nullptr, true, EAssetTypeActivationOpenedMethod::View);
		SelectedActionText = "Read Only";
		break;
	case OPEN_FOR_EDIT_BUTTON_IDENTIFIER:
		// Clicked on "Open For Edit"
		SelectedActionText = "Open For Edit";
		break;
	default:
		GEditor->GetEditorSubsystem<UAssetEditorSubsystem>()->CloseAllEditorsForAsset(Asset);
		UE_LOG(LogSourceControl, Warning, TEXT("Invalid result from confirmation dialog"));
		SelectedActionText = "Invalid";
		break;
	}
	auto SendAnalyticsOperation = ISourceControlOperation::Create<FSendAnalytics>();
	SendAnalyticsOperation->SetEventName(FText::FromString("UE SoftLock Dialog Interacted"));
	SendAnalyticsOperation->SetEventProperties({{"chosen_action", SelectedActionText},
		{"save_checkbox_state", bConflictedFileOpenConfirmCheckboxState == ECheckBoxState::Checked ? "checked" : "unchecked"}});
	auto& Provider = FDiversionModule::Get().GetProvider();
	Provider.Execute(SendAnalyticsOperation, nullptr, TArray<FString>(), EConcurrency::Asynchronous);
	
	DialogWindow->RequestDestroyWindow();
}

IMPLEMENT_MODULE(FDiversionModule, Diversion);

#undef LOCTEXT_NAMESPACE
