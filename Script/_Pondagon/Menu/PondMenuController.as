class APondMenuController : APondPlayerController
{
	UPROPERTY(BlueprintReadOnly, EditDefaultsOnly)
	TSubclassOf<UMainMenuWidget> MainMenuWidgetClass;

	UPROPERTY(BlueprintReadOnly, VisibleInstanceOnly)
	UMainMenuWidget Widget;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		if (IsLocalController())
		{
			Widget = Cast<UMainMenuWidget>(WidgetBlueprint::CreateWidget(MainMenuWidgetClass, this));
			Widget.AddToViewport();

			Widget::SetInputMode_UIOnlyEx(this, Widget, EMouseLockMode::LockInFullscreen, true);
			bShowMouseCursor = true;
		}

		if (HasAuthority())
		{
			InitPlayerSelections();
		}
	}

	UFUNCTION(BlueprintOverride)
	void OnRep_PlayerState()
	{
		if (!HasAuthority())
		{
			InitPlayerSelections();
		}
	}

	UFUNCTION(Server)
	void InitPlayerSelections()
	{
		auto GS = Cast<APondMenuGameState>(Gameplay::GameState);
		for (int i = 0; i < GS.PlayerArray.Num(); i++)
		{
			GS.PlayerSelections.Add(FPlayerSelectionData());
		}
	}

	UFUNCTION(Server)
	void SetHero(FString HeroName)
	{
		auto GS = Cast<APondMenuGameState>(Gameplay::GameState);

		FPlayerSelectionData Data;
		Data.PlayerState = PlayerState;
		Data.SelectedHero = HeroName;

		int i = GS.PlayerArray.FindIndex(PlayerState);
		GS.PlayerSelections[i] = Data;
	}
}