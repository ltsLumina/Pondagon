UCLASS(Abstract)
class UPondAbility : UGameplayAbility
{
    /**
     * The hero that owns this ability
     */
    UPROPERTY(Category = "Ability | Info")
    FName OwningHero;

	UPROPERTY(Category = "Ability | Info")
	UTexture2D Icon;

    UPROPERTY(Category = "Ability | Audio", ToolTip = "Sound to play when the ability is cast (used)")
    USoundBase UseSound;

    UPROPERTY(Category = "Ability | Audio", ToolTip = "Sound to play when the ability is equipped")
    USoundBase EquipSound;
};