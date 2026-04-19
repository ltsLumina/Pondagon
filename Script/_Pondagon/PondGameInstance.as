enum EHostSessionResult
{
	Failed = 0,
	Success = 1,
};

enum EFindSessionResult
{
	NotFound = 0,
	Failed = 1,
	Success = 2,
};

event void FOnHostSession(EHostSessionResult Result);
event void FOnFindSessionsStart();
event void FOnFindSessionsComplete(EFindSessionResult Result);

class UPondGameInstance : UAdvancedFriendsGameInstance
{
	UPROPERTY(Category = "Main Menu")
	TSubclassOf<UUserWidget> MainMenuWidgetClass;

	UPROPERTY(EditDefaultsOnly)
	USoundBase MainMenuMusic;

	UPROPERTY(Category = "Events")
	FOnHostSession OnHostSession;

	UPROPERTY(Category = "Events")
	FOnFindSessionsStart OnFindSessionsStart;

	UPROPERTY(Category = "Events")
	FOnFindSessionsComplete OnFindSessionsComplete;

	UFUNCTION(BlueprintOverride)
	void Init()
	{
		InitializeMainMenu();
	}

	void InitializeMainMenu()
	{
		auto PC = GetFirstLocalPlayerController();
		if (IsValid(PC))
		{
			auto Widget = WidgetBlueprint::CreateWidget(MainMenuWidgetClass, PC);
			Widget.AddToViewport();

			PC.bShowMouseCursor = true;
			Widget::SetInputMode_UIOnlyEx(PC, Widget);
		}
	}

	UFUNCTION(BlueprintEvent)
	void HostSession()
	{}

	UFUNCTION()
	void CallHostSession()
	{
		HostSession();
	}

	UFUNCTION(BlueprintEvent)
	void FindSessions()
	{}

	UFUNCTION()
	void CallFindSessions()
	{
		
	}

/* TODO: REPLACE EXISTING FUNCTIONS WITH THESE!
	UFUNCTION(BlueprintEvent, BlueprintCallable)
	void HostSession()
	{}

	UFUNCTION(BlueprintEvent, BlueprintCallable)
	void FindSessions()
	{}
*/
};