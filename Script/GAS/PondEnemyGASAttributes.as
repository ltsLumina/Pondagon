namespace UPondEnemyGASAttributes
{
	const FName HealthName = n"Health";
	const FName MaxHealthName = n"MaxHealth";
	const FName ShieldName = n"Shield";
	const FName MaxShieldName = n"MaxShield";
	const FName CurrentAmmoName = n"CurrentAmmo";
	const FName MaxAmmoName = n"MaxAmmo";
}

//event void FOnHealthChangedEvent(float32 NewHealth, float32 OldHealth);

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
		if (Attribute.AttributeName == UPondEnemyGASAttributes::HealthName)
		{
			NewValue = Math::Clamp(NewValue, 0.0f, MaxHealth.BaseValue);
		}
		else if (Attribute.AttributeName == UPondEnemyGASAttributes::ShieldName)
		{
			NewValue = Math::Clamp(NewValue, 0.0f, MaxShield.BaseValue);
		}
	}

	UFUNCTION(BlueprintOverride)
	void PostAttributeChange(FGameplayAttribute Attribute, float OldValue, float NewValue)
	{
		if (Attribute.AttributeName == UPondEnemyGASAttributes::HealthName)
		{
			Health.SetBaseValue(Math::Clamp(NewValue, 0.0f, MaxHealth.BaseValue));
		}
		else if (Attribute.AttributeName == UPondEnemyGASAttributes::ShieldName)
		{
			Shield.SetBaseValue(Math::Clamp(NewValue, 0.0f, MaxShield.BaseValue));
		}
	}

	UFUNCTION(BlueprintOverride)
	void PostGameplayEffectExecute(FGameplayEffectSpec EffectSpec,
								   FGameplayModifierEvaluatedData& EvaluatedData,
								   UAngelscriptAbilitySystemComponent AbilitySystemComponent)
	{
		if (EvaluatedData.Attribute.AttributeName == UPondEnemyGASAttributes::HealthName)
		{
			Health.SetCurrentValue(Health.GetCurrentValue());

			if (EnemyBase.HealthAttribute <= 0)
			{
				EnemyBase.Death();
			}
		}
		else if (EvaluatedData.Attribute.AttributeName == UPondEnemyGASAttributes::ShieldName)
		{
			Shield.SetCurrentValue(Shield.GetCurrentValue());
		}
	}

	AEnemyBase GetEnemyBase() property
	{
		return Cast<AEnemyBase>(GetOwningActor());
	}
}