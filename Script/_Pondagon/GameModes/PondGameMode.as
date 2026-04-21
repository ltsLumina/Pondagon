class APondGameMode : AGameModeBase
{
	default bUseSeamlessTravel = true;
	default bPauseable = true;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		auto GS = Gameplay::GetGameState();
		bPauseable = System::IsServer() && GS.PlayerArray.Num() == 1; // Only pausable in single-player.
	}

	UFUNCTION(BlueprintOverride)
	void OnPostLogin(APlayerController NewPlayer)
	{
		Widget::SetInputMode_GameOnly(NewPlayer, false);
		NewPlayer.bShowMouseCursor = false;
	}
};