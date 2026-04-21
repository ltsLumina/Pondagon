class AMenuGameMode : AGameModeBase
{
	default GameSessionClass = AAdvancedGameSession;
	default HUDClass = nullptr;
	default DefaultPawnClass = nullptr;

	UFUNCTION(BlueprintOverride)
	void OnPostLogin(APlayerController NewPlayer)
	{
		ThrowIf(!ValidateGameModeClasses(), f"Invalid classes in {GetName()}!");

		auto PS = NewPlayer.PlayerState;
		auto GS = Gameplay::GetGameState();

		int Index = GS.PlayerArray.FindIndex(PS);
		AdvancedSessions::SetPlayerName(NewPlayer, f"Player {Index}");
	}

	bool ValidateGameModeClasses()
	{
		return GameStateClass != nullptr && PlayerControllerClass != nullptr && PlayerStateClass != nullptr;
	}
}