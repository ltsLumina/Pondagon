class UEntityDefinition : UDataAsset
{
    UPROPERTY(Category = "Entity | Details", EditDefaultsOnly, BlueprintReadOnly)
	FText EntityName;
	default EntityName = FText::FromString("Entity");

	UPROPERTY(Category = "Entity | GAS")
	UDataTable AttributeSetDefaultStartingData;
}