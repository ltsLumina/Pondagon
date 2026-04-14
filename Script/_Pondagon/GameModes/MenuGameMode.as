class AMenuGameMode : AGameModeBase
{
    UPROPERTY(BlueprintReadOnly, EditDefaultsOnly)
    TSubclassOf<UMainMenuWidget> MainMenuWidgetClass;
    
	UPROPERTY(BlueprintReadOnly, VisibleInstanceOnly)
	UMainMenuWidget Widget;

	UFUNCTION(BlueprintOverride)
	void OnPostLogin(APlayerController NewPlayer)
	{
		Widget = Cast<UMainMenuWidget>(WidgetBlueprint::CreateWidget(MainMenuWidgetClass, NewPlayer));
		Widget.AddToViewport();

		Widget.InitSteam(NewPlayer);

		Widget::SetInputMode_UIOnlyEx(NewPlayer, Widget, EMouseLockMode::LockInFullscreen, true);
		NewPlayer.bShowMouseCursor = true;
	}
}