namespace UPlayerAttributes
{
	const FName HealthName = n"Health";
	const FName MaxHealthName = n"MaxHealth";
	const FName ShieldName = n"Shield";
	const FName MaxShieldName = n"MaxShield";
	const FName AmmoName = n"Ammo";
	const FName MaxAmmoName = n"MaxAmmo";
}

event void FOnHealthChanged(float NewHealth, float OldHealth);
event void FOnShieldChanged(float NewShield, float OldShield);

class UPlayerAttributes : UAngelscriptAttributeSet
{
	UPROPERTY(BlueprintReadOnly, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData Health;

	UPROPERTY(BlueprintReadOnly, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData MaxHealth;

	UPROPERTY(BlueprintReadOnly, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData Shield;

	UPROPERTY(BlueprintReadOnly, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData MaxShield;

	UPROPERTY(BlueprintReadOnly, Category = "Hero Attributes | Gun")
	FAngelscriptGameplayAttributeData Ammo;

	UPROPERTY(BlueprintReadOnly, Category = "Hero Attributes | Gun")
	FAngelscriptGameplayAttributeData MaxAmmo;

	UPROPERTY(BlueprintReadOnly, Category = "Events")
	FOnHealthChanged HealthAttributeChanged;

	UPROPERTY(BlueprintReadOnly, Category = "Events")
	FOnShieldChanged ShieldAttributeChanged;

	UPlayerAttributes()
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
			//Health.SetBaseValue(Math::Clamp(NewValue, 0.0f, MaxHealth.BaseValue));
			HealthAttributeChanged.Broadcast(NewValue, OldValue);
		}
		else if (Attribute.AttributeName == UPlayerAttributes::ShieldName)
		{
			//Shield.SetBaseValue(Math::Clamp(NewValue, 0.0f, MaxShield.BaseValue));
			ShieldAttributeChanged.Broadcast(NewValue, OldValue);
		}
	}

	UFUNCTION(BlueprintOverride)
	void PostGameplayEffectExecute(FGameplayEffectSpec EffectSpec,
	                               FGameplayModifierEvaluatedData& EvaluatedData,
	                               UAngelscriptAbilitySystemComponent AbilitySystemComponent)
	{
		if (EvaluatedData.Attribute.AttributeName == UPlayerAttributes::HealthName)
		{
			Health.SetCurrentValue(Math::Clamp(Health.CurrentValue, 0, MaxHealth.CurrentValue));

			if (Health.CurrentValue <= 0)
			{
				OwningHero.Death();
			}
		}
		else if (EvaluatedData.Attribute.AttributeName == UPlayerAttributes::ShieldName)
		{
			Shield.SetCurrentValue(Math::Clamp(Shield.CurrentValue, 0, MaxShield.CurrentValue));
		}
	}

	APondHero GetOwningHero() property
	{
		auto PS = Cast<APlayerState>(GetOwningActor());
		return Cast<APondHero>(PS.Pawn);
	}
}