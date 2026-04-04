namespace UEnemyAttributes
{
	const FName HealthName = n"Health";
	const FName MaxHealthName = n"MaxHealth";
	const FName ShieldName = n"Shield";
	const FName MaxShieldName = n"MaxShield";
	const FName CurrentAmmoName = n"CurrentAmmo";
	const FName MaxAmmoName = n"MaxAmmo";
}

event void FOnEnemyHit(float DamageDealt, bool WasPrecision, bool Died);

class UEnemyAttributes : UAngelscriptAttributeSet
{
	UPROPERTY(BlueprintReadOnly, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData Health;

	UPROPERTY(BlueprintReadOnly, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData MaxHealth;

	UPROPERTY(BlueprintReadOnly, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData Shield;

	UPROPERTY(BlueprintReadOnly, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData MaxShield;

	UPROPERTY(BlueprintReadOnly, Category = "Events")
	FOnHealthChanged HealthAttributeChanged;

	UPROPERTY(BlueprintReadOnly, Category = "Events")
	FOnShieldChanged ShieldAttributeChanged;

	UPROPERTY(BlueprintReadOnly, Category = "Events")
	FOnEnemyHit OnEnemyHit;

	UEnemyAttributes()
	{
		Health.Initialize(100.0f);
		MaxHealth.Initialize(100.0f);
		Shield.Initialize(100.0f);
		MaxShield.Initialize(100.0f);
	}

	UFUNCTION(BlueprintOverride)
	void PreAttributeChange(FGameplayAttribute Attribute, float32& NewValue)
	{
		if (Attribute.AttributeName == UPlayerAttributes::HealthName)
		{
			NewValue = Math::Clamp(NewValue, 0.0f, MaxHealth.CurrentValue);
		}
		else if (Attribute.AttributeName == UPlayerAttributes::ShieldName)
		{
			NewValue = Math::Clamp(NewValue, 0.0f, MaxShield.CurrentValue);
		}
	}

	UFUNCTION(BlueprintOverride)
	void PostAttributeChange(FGameplayAttribute Attribute, float OldValue, float NewValue)
	{
		if (Attribute.AttributeName == UPlayerAttributes::HealthName)
		{
			// Health.SetBaseValue(Math::Clamp(NewValue, 0.0f, MaxHealth.BaseValue));
			HealthAttributeChanged.Broadcast(NewValue, OldValue);
			OldHealth = OldValue;
		}
		else if (Attribute.AttributeName == UPlayerAttributes::ShieldName)
		{
			// Shield.SetBaseValue(Math::Clamp(NewValue, 0.0f, MaxShield.BaseValue));
			ShieldAttributeChanged.Broadcast(NewValue, OldValue);
		}
	}

	float OldHealth;

	/**
	 * CALLED ON THE SERVER ONLY!!
	 */
	UFUNCTION(BlueprintOverride)
	void PostGameplayEffectExecute(FGameplayEffectSpec EffectSpec,
								   FGameplayModifierEvaluatedData& EvaluatedData,
								   UAngelscriptAbilitySystemComponent AbilitySystemComponent)
	{
		if (EvaluatedData.Attribute.AttributeName == UPlayerAttributes::HealthName)
		{
			Health.SetCurrentValue(Math::Clamp(Health.CurrentValue, 0, MaxHealth.CurrentValue));

			bool WasPrecision = EffectSpec.DynamicAssetTags.HasTag(GameplayTags::Data_Precision);
			float DamageDealt = OldHealth - Health.CurrentValue;
			bool Died = Health.CurrentValue <= 0;

			//Print(f"{WasPrecision=}");
			//Print(f"{DamageDealt=}");
			//Print(f"{Died=}");

			OnEnemyHit.Broadcast(DamageDealt, WasPrecision, Died);
			
			if (Died)
				EnemyBase.Death();

		}
		else if (EvaluatedData.Attribute.AttributeName == UPlayerAttributes::ShieldName)
		{
			Shield.SetCurrentValue(Math::Clamp(Shield.CurrentValue, 0, MaxShield.CurrentValue));
		}
	}

	AEnemyBase GetEnemyBase() property
	{
		return Cast<AEnemyBase>(GetOwningActor());
	}
}