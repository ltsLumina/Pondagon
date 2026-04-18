class APondGameState : AGameState
{
    UPROPERTY(Category = "Players", Replicated)
    TArray<FPlayerSelectionData> PlayerSelections;
    
    UPROPERTY(Category = "Run")
    UDataTable EnchantmentsPool;

    UPROPERTY(Category = "Run")
    FSeededRunData CurrentRun;

    /**
     * Initializes the current run's data.
     * @param Stream Stream to use for randomized seeding.
     * @param UpgradesPool Optional parameter to override the pool of potential upgrades. If nullptr, uses the default set in the GameState.
     */
    UFUNCTION(Category = "Run")
    void InitRun(FRandomStream Stream, UDataTable UpgradesPool = nullptr)
    {
        TArray<UEnchantment> PossibleEnchantments;
        // TODO: Iterate through DataTable to get all upgrades from it, and populate PossibleEnchantments.

        CurrentRun = FSeededRunData(Stream, Stream.CurrentSeed, PossibleEnchantments);
    }

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        InitRun(FRandomStream(-1));
    }
};

struct FSeededRunData
{
    UPROPERTY(Category = "Run", BlueprintReadOnly)
    FRandomStream Stream;

    UPROPERTY(Category = "Run", BlueprintReadOnly)
    int32 Seed;

    UPROPERTY(Category = "Run", BlueprintReadOnly)
    TArray<UEnchantment> PossibleEnchantments;

    FSeededRunData(FRandomStream InStream, int32 InSeed, TArray<UEnchantment> InEnchantments)
    {
        Stream = InStream;
        Seed = InSeed;
        PossibleEnchantments = InEnchantments;
    }
}

struct FPlayerSelectionData
{
    UPROPERTY(BlueprintReadOnly)
    APlayerState PlayerState;

    UPROPERTY(BlueprintReadOnly)
    FString SelectedHero;
}

namespace Pond
{
    UFUNCTION(BlueprintPure)
    APondGameState GetPondGameStateBase()
    {
        return Cast<APondGameState>(Gameplay::GetGameState());
    }
}