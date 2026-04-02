namespace UPondEnemyGASAttributes
{
	const FName HealthName = n"Health";
	const FName MaxHealthName = n"MaxHealth";
	const FName ShieldName = n"Shield";
	const FName MaxShieldName = n"MaxShield";
	const FName CurrentAmmoName = n"CurrentAmmo";
	const FName MaxAmmoName = n"MaxAmmo";
}

class UPondEnemyGASAttributes : UAngelscriptAttributeSet
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

	UPondEnemyGASAttributes()
	{
		Health.Initialize(100.0f);
		MaxHealth.Initialize(100.0f);
		Shield.Initialize(100.0f);
		MaxShield.Initialize(100.0f);
	}

	UFUNCTION(BlueprintOverride)
	void PreAttributeChange(FGameplayAttribute Attribute, float32& NewValue)
	{
		if (Attribute.AttributeName == UPondPlayerGASAttributes::HealthName)
		{
			NewValue = Math::Clamp(NewValue, 0.0f, MaxHealth.CurrentValue);
		}
		else if (Attribute.AttributeName == UPondPlayerGASAttributes::ShieldName)
		{
			NewValue = Math::Clamp(NewValue, 0.0f, MaxShield.CurrentValue);
		}
	}

	UFUNCTION(BlueprintOverride)
	void PostAttributeChange(FGameplayAttribute Attribute, float OldValue, float NewValue)
	{
		if (Attribute.AttributeName == UPondPlayerGASAttributes::HealthName)
		{
			//Health.SetBaseValue(Math::Clamp(NewValue, 0.0f, MaxHealth.BaseValue));
			HealthAttributeChanged.Broadcast(NewValue, OldValue);
		}
		else if (Attribute.AttributeName == UPondPlayerGASAttributes::ShieldName)
		{
			//Shield.SetBaseValue(Math::Clamp(NewValue, 0.0f, MaxShield.BaseValue));
			ShieldAttributeChanged.Broadcast(NewValue, OldValue);
		}
	}

	/**
	 * CALLED ON THE SERVER ONLY!!
	 */
	UFUNCTION(BlueprintOverride)
	void PostGameplayEffectExecute(FGameplayEffectSpec EffectSpec,
								   FGameplayModifierEvaluatedData& EvaluatedData,
								   UAngelscriptAbilitySystemComponent AbilitySystemComponent)
	{
		if (EvaluatedData.Attribute.AttributeName == UPondPlayerGASAttributes::HealthName)
		{
			Health.SetCurrentValue(Math::Clamp(Health.CurrentValue, 0, MaxHealth.CurrentValue));

			if (EnemyBase.CurrentHealth <= 0)
			{
				EnemyBase.Death();
			}
		}
		else if (EvaluatedData.Attribute.AttributeName == UPondPlayerGASAttributes::ShieldName)
		{
			Shield.SetCurrentValue(Math::Clamp(Shield.CurrentValue, 0, MaxShield.CurrentValue));
		}
	}

	AEnemyBase GetEnemyBase() property
	{
		return Cast<AEnemyBase>(GetOwningActor());
	}
}