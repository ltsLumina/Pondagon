class APondPlayerState : APlayerState
{
	UPROPERTY(DefaultComponent)
	UAngelscriptAbilitySystemComponent AbilitySystem;

	UPROPERTY(NotVisible, BlueprintReadOnly)
	UInventoryComponent InventoryComponent;
	default InventoryComponent = UInventoryComponent::Get(this);
	//~Components

	UPROPERTY(Category = "Hero | GAS", EditDefaultsOnly)
	TArray<TSubclassOf<UPondAbility>> InitialAbilities;

	UPROPERTY(Category = "Hero | GAS", EditConst)
	UPondPlayerGASAttributes Attributes;

	UPROPERTY(Category = "Team", BlueprintReadOnly)
    int RespawnTokens = 1;

	// #region Attribute Getters
	UFUNCTION(BlueprintPure)
	float GetCurrentHealth() property
	{
		return Attributes.Health.CurrentValue;
	}

	UFUNCTION(BlueprintPure)
	float GetBaseHealth() property
	{
		return Attributes.Health.BaseValue;
	}

	UFUNCTION(BlueprintPure)
	float GetCurrentShield() property
	{
		return Attributes.Shield.CurrentValue;
	}

	UFUNCTION(BlueprintPure)
	float GetBaseShield() property
	{
		return Attributes.Shield.BaseValue;
	}
	// #endregion

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		for (auto Ability : InitialAbilities)
			AbilitySystem.GiveAbility(FGameplayAbilitySpec(Ability, 1, -1));

		Attributes = Cast<UPondPlayerGASAttributes>(AbilitySystem.RegisterAttributeSet(UPondPlayerGASAttributes));

		AbilitySystem.InitAbilityActorInfo(this, Pawn);

		AbilitySystem.InitStats(UPondPlayerGASAttributes, Cast<APondHero>(Pawn).Definition.AttributeSetDefaultStartingData)

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