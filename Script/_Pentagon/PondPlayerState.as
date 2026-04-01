class APondPlayerState : APlayerState
{
	UPROPERTY(DefaultComponent)
	UAngelscriptAbilitySystemComponent AbilitySystem;

	UPROPERTY(NotVisible, BlueprintReadOnly)
	UInventoryComponent InventoryComponent;
	default InventoryComponent = UInventoryComponent::Get(this);

	UPROPERTY(Category = "Hero | GAS", EditDefaultsOnly)
	TArray<TSubclassOf<UPondAbility>> Abilities;

	UPROPERTY(Category = "Hero | GAS", EditConst)
	UPondPlayerGASAttributes Attributes;

	UPROPERTY(Category = "Hero | GAS", EditConst)
	FGameplayTagContainer GameplayTags;

	UFUNCTION(Category = "Hero | Health", BlueprintPure)
	float GetHealthAttribute() property
	{
		return Attributes.Health.CurrentValue;
	}

	UFUNCTION(Category = "Hero | Shield", BlueprintPure)
	float GetShieldAttribute() property
	{
		return Attributes.Shield.CurrentValue;
	}

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		for (auto Ability : Abilities)
			AbilitySystem.GiveAbility(FGameplayAbilitySpec(Ability, 1, -1));

		Attributes = Cast<UPondPlayerGASAttributes>(AbilitySystem.RegisterAttributeSet(UPondPlayerGASAttributes));

#if EDITOR
		float SpawnHealth = HealthAttribute;
		float SpawnShield = ShieldAttribute;
		Print(f"{ActorNameOrLabel} has spawned with {SpawnHealth} health and {SpawnShield} Shield.", 1.5f, FLinearColor::Green);
#endif
	}
	
};

namespace Pond
{
    UFUNCTION(BlueprintPure)
    APondPlayerState GetPondPlayerStateBase()
    {
        return Cast<APondPlayerState>(Gameplay::GetPlayerState(0));
    }
}