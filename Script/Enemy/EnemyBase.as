class AEnemyBase : APondCharacter
{
	UPROPERTY(DefaultComponent)
	UAngelscriptAbilitySystemComponent AbilitySystem;

	UPROPERTY(Category = "Enemy | GAS", EditDefaultsOnly)
	TArray<TSubclassOf<UPondAbility>> Abilities;

	UPROPERTY(Category = "Enemy | GAS", EditConst)
	UPondEnemyGASAttributes Attributes;

	UPROPERTY(Category = "Enemy | Details")
	FText EnemyName;

	float GetHealthAttribute() override property
	{
		return Attributes.Health.GetCurrentValue();
	}

	float GetShieldAttribute() override property
	{
		return Attributes.Shield.GetCurrentValue();
	}

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		for (auto Ability : Abilities)
			AbilitySystem.GiveAbility(FGameplayAbilitySpec(Ability, 1, -1));

		Attributes = Cast<UPondEnemyGASAttributes>(AbilitySystem.RegisterAttributeSet(UPondEnemyGASAttributes));

#if EDITOR
		float SpawnHealth = HealthAttribute;
		float SpawnShield = ShieldAttribute;
		Print(f"Enemy '{ActorNameOrLabel}' has spawned with {SpawnHealth} health and {SpawnShield} Shield.", 1.5f, FLinearColor::Green);
#endif
	}

	void ApplyDamage(float Damage) override
	{
		float HealthDamage;
		float ShieldDamage;
		CalculateDamageTaken(HealthAttribute, ShieldAttribute, Damage, HealthDamage, ShieldDamage);

		FGameplayEffectSpecHandle HealthHandle = AbilitySystem.MakeOutgoingSpec(UGE_Damage_Health, 1, FGameplayEffectContextHandle());
		if (HealthHandle.IsValid() && GetHealthAttribute() > 0)
		{
			HealthHandle.Spec.SetByCallerMagnitude(GameplayTags::Data_Damage_Health, -HealthDamage);
			AbilitySystem.ApplyGameplayEffectSpecToSelf(HealthHandle);

			Print(f"Applied {Math::RoundToInt(HealthDamage)} HEALTH damage to {EnemyName}", 1, FLinearColor::DPink);
		}

		FGameplayEffectSpecHandle ShieldHandle = AbilitySystem.MakeOutgoingSpec(UGE_Damage_Shield, 1, FGameplayEffectContextHandle());
		if (ShieldHandle.IsValid() && GetShieldAttribute() > 0)
		{
			ShieldHandle.Spec.SetByCallerMagnitude(GameplayTags::Data_Damage_Shield, -ShieldDamage);
			AbilitySystem.ApplyGameplayEffectSpecToSelf(ShieldHandle);

			Print(f"Applied {Math::RoundToInt(ShieldDamage)} Shield damage to {EnemyName}", 1, FLinearColor::Teal);
		}
	}

	void ApplyHealing(float HealAmount) override
	{
		if (HealthAttribute >= Attributes.MaxHealth.BaseValue)
			return;

		FGameplayEffectSpecHandle HealHandle = AbilitySystem.MakeOutgoingSpec(UGE_Restore_Health, 1, FGameplayEffectContextHandle());
		if (HealHandle.IsValid())
		{
			HealHandle.Spec.SetByCallerMagnitude(GameplayTags::Data_Damage_Health, HealAmount);
			AbilitySystem.ApplyGameplayEffectSpecToSelf(HealHandle);

			Print(f"Applied {HealAmount} health healing to {EnemyName}", 5.0f, FLinearColor::Green);
		}
	}

	void ApplyShield(float NewAmount) override
	{
		float ShieldAmount = NewAmount;

		FGameplayEffectSpecHandle ShieldHandle = AbilitySystem.MakeOutgoingSpec(UGE_Override_Shield, 1, FGameplayEffectContextHandle());
		if (ShieldHandle.IsValid())
		{
			ShieldHandle.Spec.SetByCallerMagnitude(GameplayTags::Data_Damage_Shield, ShieldAmount);
			AbilitySystem.ApplyGameplayEffectSpecToSelf(ShieldHandle);

			Print(f"Applied {ShieldAmount} Shield to {EnemyName}", 1.0f, FLinearColor::LucBlue);
		}
	}

	void Death() override
	{
		if (GameplayTags.HasTag(GameplayTags::Character_State_Dead))
			return;
		else
			GameplayTags.AddTag(GameplayTags::Character_State_Dead);

		FGameplayEffectQuery Query;
		for (FActiveGameplayEffectHandle Handle : AbilitySystem.GetActiveEffects(Query))
		{
			AbilitySystem.RemoveActiveGameplayEffect(Handle);
		}

		OnDeath.Broadcast(DeathInfo);

		DestroyActor();
	}
};