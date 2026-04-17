UCLASS(Meta=(PrioritizeCategories="Entity | Details"))
class UEntityDefinition : UDataAsset
{
    UPROPERTY(Category = "Entity | Details", EditDefaultsOnly, BlueprintReadOnly)
	FText EntityName;
	default EntityName = FText::FromString("Entity");

	UPROPERTY(Category = "Entity | GAS", Meta=(EditFixedOrder))
    TMap<TSubclassOf<UAngelscriptAttributeSet>, UDataTable> StartingData;

	UPROPERTY(Category = "Entity | GAS", Meta=(EditFixedOrder))
    TArray<TSubclassOf<UAngelscriptGameplayAbility>> StartingAbilities;

	UFUNCTION(Category = "Debug", CallInEditor, DisplayName = "Make Player Definition")
	void MakePlayerDefButton()
	{
		System::BeginTransaction("UnrealEd", FText::FromString("Create default Player Starting Data."), this);
		System::TransactObject(this);

		StartingData.Empty();

		StartingData.Add(UPlayerAttributes, nullptr);
		StartingData.Add(UGenericGunAttributes, nullptr);
		System::EndTransaction();
	}

	UFUNCTION(Category = "Debug", CallInEditor, DisplayName = "Make Enemy Definition")
	void MakeEnemyDefButton()
	{
		System::BeginTransaction("UnrealEd", FText::FromString("Create default Player Starting Data."), this);
		System::TransactObject(this);

		StartingData.Empty();
		
		StartingData.Add(UEnemyAttributes, nullptr);
		System::EndTransaction();
	}
}