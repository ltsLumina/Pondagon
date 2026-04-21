class UCharSelectWidget : UPondWidgetBase
{
	UPROPERTY(BindWidget)
	UHorizontalBox PlayersBox;

	APondMenuGameState GameState;

	UFUNCTION(BlueprintOverride)
	void Construct()
	{
		GameState = Cast<APondMenuGameState>(Gameplay::GameState);
	}

	UFUNCTION(BlueprintOverride)
	void Tick(FGeometry MyGeometry, float InDeltaTime)
	{
		for (int i = 0; i < GameState.PlayerArray.Num(); i++)
		{
			auto PlayerState = GameState.PlayerArray[i].Get();
			auto ChildWidget = PlayersBox.GetChildAt(i);
			auto Nametag = Cast<UCharSelectNametagWidget>(ChildWidget);

			FString PlayerName = PlayerState.PlayerName;
			Nametag.PlayerName = PlayerName;

			int Index = GameState.PlayerArray.FindIndex(PlayerState);
			if (GameState.PlayerSelections.IsValidIndex(Index))
			{
				FPlayerSelectionData SelectionData = GameState.PlayerSelections[Index];
				if (SelectionData.PlayerState == PlayerState)
				{
					Nametag.HeroName = SelectionData.SelectedHero;
				}
			}
			else
			{
				Nametag.HeroName = "None";
			}
		}
	}
};