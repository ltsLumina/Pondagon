class UEntityDefinition : UDataAsset
{
    UPROPERTY(Category = "Entity | Details", EditDefaultsOnly, BlueprintReadOnly)
	FText EntityName;
	default EntityName = FText::FromString("Entity");

	UPROPERTY(Category = "Entity | Details", Meta=(EditFixedOrder))
    TMap<TSubclassOf<UAngelscriptAttributeSet>, UDataTable> StartingData;

	UPROPERTY(Category = "Entity | Details", Meta=(EditFixedOrder))
    TArray<TSubclassOf<UAngelscriptGameplayAbility>> StartingAbilities;

	UFUNCTION(Category = "Debug", CallInEditor, DisplayName = "Make Player Definition")
	void MakePlayerDefButton()
	{
		StartingData.Empty();

		StartingData.Add(UPlayerAttributes, nullptr);
		StartingData.Add(UGenericGunAttributes, nullptr);
	}

	UFUNCTION(Category = "Debug", CallInEditor, DisplayName = "Make Enemy Definition")
	void MakeEnemyDefButton()
	{
		StartingData.Empty();
		
		StartingData.Add(UEnemyAttributes, nullptr);
	}
}