UCLASS(Abstract)
class UPondAbility : UGameplayAbility
{
	UPROPERTY(Category = "Ability | Info")
	UTexture2D Icon;

    UPROPERTY(Category = "Ability | Audio", ToolTip = "Sound to play when the ability is cast (used)")
    USoundBase UseSound;
};