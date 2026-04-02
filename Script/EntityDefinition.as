class UEntityDefinition : UDataAsset
{
    UPROPERTY(Category = "Entity | Info", EditDefaultsOnly)
	FText EntityName;
	default EntityName = FText::FromString("Entity");
}