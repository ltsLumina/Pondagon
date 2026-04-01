namespace UPondPlayerGASAttributes
{
	const FName HealthName = n"Health";
	const FName MaxHealthName = n"MaxHealth";
	const FName ShieldName = n"Shield";
	const FName MaxShieldName = n"MaxShield";
	const FName CurrentAmmoName = n"CurrentAmmo";
	const FName MaxAmmoName = n"MaxAmmo";
}

event void FOnHealthChangedEvent(float32 NewHealth, float32 OldHealth);

class UPondPlayerGASAttributes : UAngelscriptAttributeSet
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
	FAngelscriptGameplayAttributeData CurrentAmmo;

	UPROPERTY(BlueprintReadOnly, Category = "Hero Attributes | Gun")
	FAngelscriptGameplayAttributeData MaxAmmo;

	UPondPlayerGASAttributes()
	{
		Health.Initialize(100.0f);
		MaxHealth.Initialize(100.0f);
		Shield.Initialize(100.0f);
		MaxShield.Initialize(100.0f);
		CurrentAmmo.Initialize(30.0f);
		MaxAmmo.Initialize(30.0f);
	}

	UFUNCTION(BlueprintOverride)
	void PreAttributeChange(FGameplayAttribute Attribute, float32& NewValue)
	{
		if (Attribute.AttributeName == UPondPlayerGASAttributes::HealthName)
		{
			NewValue = Math::Clamp(NewValue, 0.0f, MaxHealth.BaseValue);
		}
		else if (Attribute.AttributeName == UPondPlayerGASAttributes::ShieldName)
		{
			NewValue = Math::Clamp(NewValue, 0.0f, MaxShield.BaseValue);
		}
	}

	UFUNCTION(BlueprintOverride)
	void PostAttributeChange(FGameplayAttribute Attribute, float OldValue, float NewValue)
	{
		if (Attribute.AttributeName == UPondPlayerGASAttributes::HealthName)
		{
			Health.SetBaseValue(Math::Clamp(NewValue, 0.0f, MaxHealth.BaseValue));
		}
		else if (Attribute.AttributeName == UPondPlayerGASAttributes::ShieldName)
		{
			Shield.SetBaseValue(Math::Clamp(NewValue, 0.0f, MaxShield.BaseValue));
		}
	}

	UFUNCTION(BlueprintOverride)
	void PostGameplayEffectExecute(FGameplayEffectSpec EffectSpec,
	                               FGameplayModifierEvaluatedData& EvaluatedData,
	                               UAngelscriptAbilitySystemComponent AbilitySystemComponent)
	{
		if (EvaluatedData.Attribute.AttributeName == UPondPlayerGASAttributes::HealthName)
		{
			Health.SetCurrentValue(Health.GetCurrentValue());

			if (Hero.GetHealthAttribute() <= 0)
			{
				Hero.Death();
			}
		}
		else if (EvaluatedData.Attribute.AttributeName == UPondPlayerGASAttributes::ShieldName)
		{
			Shield.SetCurrentValue(Shield.GetCurrentValue());
		}
	}

	APondHero GetHero() property
	{
		auto PS = Cast<APlayerState>(GetOwningActor());
		return Cast<APondHero>(PS.Pawn);
	}
}