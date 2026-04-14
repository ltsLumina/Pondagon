class AScriptEnemyBase : AEnemyBase
{
	UPROPERTY(Category = "Enemy | Details")
	UEntityDefinition Definition;

	UPROPERTY(Category = "Enemy | GAS", EditDefaultsOnly)
	TArray<TSubclassOf<UGameplayAbility>> InitialAbilities;

	UPROPERTY(Category = "Enemy | GAS", EditConst)
	UEnemyAttributes Attributes;

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
		Attributes = Cast<UEnemyAttributes>(AbilitySystem.RegisterAttributeSet(UEnemyAttributes));
	}

	UFUNCTION(BlueprintOverride)
	void Possessed(AController NewController)
	{
		check(!Definition.StartingData.IsEmpty());

		Attributes = Cast<UEnemyAttributes>(AbilitySystem.RegisterAttributeSet(UEnemyAttributes));

		AbilitySystem.InitAbilityActorInfo(NewController, this);
		for (auto& Data : Definition.StartingData)
		{
			AbilitySystem.RegisterAttributeSet(Data.Key);
			AbilitySystem.InitStats(Data.Key, Data.Value);
		}

#if EDITOR
		float SpawnHealth = CurrentHealth;
		float SpawnShield = CurrentShield;
		Print(f"Enemy '{ActorNameOrLabel}' has spawned with {SpawnHealth} health and {SpawnShield} Shield.", 1.5f, FLinearColor::Green);
#endif
	}

	UFUNCTION(BlueprintOverride)
	void PointDamage(float Damage, const UDamageType DamageType, FVector HitLocation, FVector HitNormal,
					 UPrimitiveComponent HitComponent, FName BoneName, FVector ShotFromDirection,
					 AController InstigatedBy, AActor DamageCauser, FHitResult HitInfo)
	{
		Print("hit enemy!", 1.0f, FLinearColor::Yellow);
	}

	void Death()
	{
		if (AbilitySystem.HasGameplayTag(GameplayTags::Character_State_Dead))
			return;
		else
			AbilitySystem.AddLooseGameplayTag(GameplayTags::Character_State_Dead);

		FGameplayEffectQuery Query;
		for (FActiveGameplayEffectHandle Handle : AbilitySystem.GetActiveEffects(Query))
		{
			AbilitySystem.RemoveActiveGameplayEffect(Handle);
		}

		PrintWarning("Enemy died!");
		DestroyActor();
	}
};