namespace UPondPlayerGASAttributes
{
	const FName HealthName = n"Health";
	const FName MaxHealthName = n"MaxHealth";
	const FName ShieldName = n"Shield";
	const FName MaxShieldName = n"MaxShield";
	const FName AmmoName = n"Ammo";
	const FName MaxAmmoName = n"MaxAmmo";
}

event void FOnHealthChanged(float32 NewHealth, float32 OldHealth);
event void FOnShieldChanged(float32 NewShield, float32 OldShield);
event void FOnPlayerAmmoChanged(float32 NewAmmo, float32 OldAmmo);

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
	FAngelscriptGameplayAttributeData Ammo;

	UPROPERTY(BlueprintReadOnly, Category = "Hero Attributes | Gun")
	FAngelscriptGameplayAttributeData MaxAmmo;

	UPROPERTY(BlueprintReadOnly, Category = "Events")
	FOnHealthChanged HealthAttributeChanged;

	UPROPERTY(BlueprintReadOnly, Category = "Events")
	FOnShieldChanged ShieldAttributeChanged;

	UPROPERTY(BlueprintReadOnly, Category = "Events")
	FOnPlayerAmmoChanged AmmoAttributeChanged;

	UPondPlayerGASAttributes()
	{
		Health.Initialize(100.0f);
		MaxHealth.Initialize(100.0f);
		Shield.Initialize(100.0f);
		MaxShield.Initialize(100.0f);
		Ammo.Initialize(30.0f);
		MaxAmmo.Initialize(30.0f);
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
		else if (Attribute.AttributeName == UPondPlayerGASAttributes::AmmoName)
		{
			//Ammo.SetBaseValue(Math::Clamp(NewValue, 0.0f, MaxAmmo.BaseValue));
			AmmoAttributeChanged.Broadcast(NewValue, OldValue);
		}
	}

	UFUNCTION(BlueprintOverride)
	void PostGameplayEffectExecute(FGameplayEffectSpec EffectSpec,
	                               FGameplayModifierEvaluatedData& EvaluatedData,
	                               UAngelscriptAbilitySystemComponent AbilitySystemComponent)
	{
		if (EvaluatedData.Attribute.AttributeName == UPondPlayerGASAttributes::HealthName)
		{
			Health.SetCurrentValue(Math::Clamp(Health.CurrentValue, 0, MaxHealth.CurrentValue));

			if (Hero.CurrentHealth <= 0)
			{
				Hero.Death();
			}
		}
		else if (EvaluatedData.Attribute.AttributeName == UPondPlayerGASAttributes::ShieldName)
		{
			Shield.SetCurrentValue(Math::Clamp(Shield.CurrentValue, 0, MaxShield.CurrentValue));
		}
	}

	APondHero GetHero() property
	{
		auto PS = Cast<APlayerState>(GetOwningActor());
		return Cast<APondHero>(PS.Pawn);
	}
}