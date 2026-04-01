class UItemInstance : UObject
{
    UPROPERTY()
    UItemDefinition Definition;
    
    UPROPERTY()
    int Count;
    
	UPROPERTY(VisibleAnywhere)
	ERarity Rarity = ERarity::Standard;

    UFUNCTION(BlueprintPure)
    UTexture2D GetIcon()
    {
        return Definition.Icon;
    }

    UFUNCTION(BlueprintPure)
    int GetStackSize()
    {
        return Definition.StackSize;
    }
}