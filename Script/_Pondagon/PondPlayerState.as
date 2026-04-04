class APondPlayerState : APlayerState
{
	UPROPERTY(DefaultComponent)
	UAngelscriptAbilitySystemComponent AbilitySystem;
	//default AbilitySystem = UAngelscriptAbilitySystemComponent::Create(this, n"AbilitySystem");

	UPROPERTY(NotVisible, BlueprintReadOnly)
	UInventoryComponent InventoryComponent;
	default InventoryComponent = UInventoryComponent::Get(this);
	//~Components

	UPROPERTY(Category = "Hero | GAS", EditConst)
	UPlayerAttributes PlayerAttributes;

	UPROPERTY(Category = "Hero | GAS", EditConst)
	UGenericGunAttributes GenericGunAttributes;

	UPROPERTY(Category = "Hero | GAS", EditConst)
	UAngelscriptAttributeSet SpecificGunAttributes;

	UPROPERTY(Category = "Team", BlueprintReadOnly)
    int RespawnTokens = 1;

	// #region Attribute Getters
	UFUNCTION(BlueprintPure)
	float GetCurrentHealth() property
	{
		return PlayerAttributes.Health.CurrentValue;
	}

	UFUNCTION(BlueprintPure)
	float GetBaseHealth() property
	{
		return PlayerAttributes.Health.BaseValue;
	}

	UFUNCTION(BlueprintPure)
	float GetCurrentShield() property
	{
		return PlayerAttributes.Shield.CurrentValue;
	}

	UFUNCTION(BlueprintPure)
	float GetBaseShield() property
	{
		return PlayerAttributes.Shield.BaseValue;
	}
	// #endregion

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		auto GunComponent = UGunComponent::Get(Pawn);
		TSubclassOf<UAngelscriptAttributeSet> CurrentGunAttributeSet = GunComponent.CurrentGun.WeaponDefinition.AttributeSet;

		PlayerAttributes = Cast<UPlayerAttributes>(AbilitySystem.RegisterAttributeSet(UPlayerAttributes));
		GenericGunAttributes = Cast<UGenericGunAttributes>(AbilitySystem.RegisterAttributeSet(UGenericGunAttributes));
		SpecificGunAttributes = AbilitySystem.RegisterAttributeSet(CurrentGunAttributeSet);

		AbilitySystem.InitAbilityActorInfo(this, Pawn);
		AbilitySystem.InitStats(UPlayerAttributes, Cast<APondHero>(Pawn).Definition.AttributeSetDefaultStartingData);

#if EDITOR
		float SpawnHealth = CurrentHealth;
		float SpawnShield = CurrentShield;
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