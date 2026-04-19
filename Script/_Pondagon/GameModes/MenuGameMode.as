class AMenuGameMode : AGameModeBase
{
	default GameSessionClass = AAdvancedGameSession;
	default HUDClass = nullptr;
	default DefaultPawnClass = nullptr;
	
	UPROPERTY(BlueprintReadOnly, EditDefaultsOnly)
	TSubclassOf<UMainMenuWidget> MainMenuWidgetClass;

	UPROPERTY(BlueprintReadOnly, VisibleInstanceOnly)
	UMainMenuWidget Widget;

	UFUNCTION(BlueprintOverride)
	void OnPostLogin(APlayerController NewPlayer)
	{
		ThrowIf(!ValidateGameModeClasses(), f"Invalid classes in {GetName()}!");

		auto PS = NewPlayer.PlayerState;
		auto GS = Pond::GetPondGameStateBase();

		int Index = GS.PlayerArray.FindIndex(PS);
		AdvancedSessions::SetPlayerName(NewPlayer, f"Player {Index}");

		Widget = Cast<UMainMenuWidget>(WidgetBlueprint::CreateWidget(MainMenuWidgetClass, NewPlayer));
		Widget.AddToViewport();
		Widget.InitSteam(NewPlayer);

		Widget::SetInputMode_UIOnlyEx(NewPlayer, Widget, EMouseLockMode::LockInFullscreen, true);
		NewPlayer.bShowMouseCursor = true;
	}

	bool ValidateGameModeClasses()
	{
		return GameStateClass != nullptr && PlayerControllerClass != nullptr && PlayerStateClass != nullptr;
	}
}