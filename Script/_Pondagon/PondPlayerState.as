class AScriptPondPlayerState : APondPlayerState
{
	UPROPERTY(DefaultComponent)
	UAngelscriptAbilitySystemComponent AbilitySystem;

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
	void ConstructionScript()
	{
		InventoryComponent = UInventoryComponent::Get(this);
	}

	bool HasInitialized;

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		if (Pawn != nullptr && !HasInitialized)
		{
			Initialize();
			HasInitialized = true;
		}
	}

	void Initialize()
	{
		auto Hero = Cast<APondHero>(Pawn);
		check(Hero != nullptr);
		check(!Hero.Definition.StartingData.IsEmpty());

		InventoryComponent.Initialize();

		auto GunComponent = UGunComponent::Get(Pawn);
		TSubclassOf<UAngelscriptAttributeSet> CurrentGunAttributeSet = GunComponent.CurrentGun.WeaponDefinition.AttributeSet;

		PlayerAttributes = Cast<UPlayerAttributes>(AbilitySystem.RegisterAttributeSet(UPlayerAttributes));
		GenericGunAttributes = Cast<UGenericGunAttributes>(AbilitySystem.RegisterAttributeSet(UGenericGunAttributes));
		SpecificGunAttributes = AbilitySystem.RegisterAttributeSet(CurrentGunAttributeSet);

		AbilitySystem.InitAbilityActorInfo(this, Pawn);
		for (auto& Data : Hero.Definition.StartingData)
		{
			AbilitySystem.RegisterAttributeSet(Data.Key); // Function ensures sets aren't added twice.
			AbilitySystem.InitStats(Data.Key, Data.Value);
		}

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
	AScriptPondPlayerState GetPondPlayerStateBase()
	{
		return Cast<AScriptPondPlayerState>(Gameplay::GetPlayerState(0));
	}
}