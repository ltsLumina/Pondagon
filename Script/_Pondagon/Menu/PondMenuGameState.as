class APondMenuGameState : AGameStateBase
{
    UPROPERTY(Category = "Players", Replicated)
    TArray<FPlayerSelectionData> PlayerSelections;
}