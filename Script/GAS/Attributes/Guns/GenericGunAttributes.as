namespace UGenericGunAttributes
{
	const FName AmmoName = n"Ammo";
	const FName MaxAmmoName = n"MaxAmmo";
}

event void FOnAmmoChanged(float NewAmmo, float OldAmmo);

class UGenericGunAttributes : UAngelscriptAttributeSet
{
	UPROPERTY(BlueprintReadOnly, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData Ammo;

	UPROPERTY(BlueprintReadOnly, Category = "Gun Attributes")
	FAngelscriptGameplayAttributeData MaxAmmo;

	UPROPERTY(BlueprintReadOnly, Category = "Events")
	FOnAmmoChanged AmmoAttributeChanged;

	UGenericGunAttributes()
	{
		Ammo.Initialize(30.0f);
		MaxAmmo.Initialize(30.0f);
	}

	// ORDER OF EXECUTION AND RESPONSIBILITY
	// 1. | PRE ATTRIBUTE CHANGE: Perform clamping for ASC to use.
	// 2. | POST GAMEPLAY EFFECT EXECUTE: Update value to new clamped non-zero value, perform post-execute effects such as target death.
	// 3. | POST ATTRIBUTE CHANGE: Broadcast attribute update to listeners.

	//~
	UFUNCTION(BlueprintOverride)
	void PreAttributeChange(FGameplayAttribute Attribute, float32& NewValue)
	{
		if (Attribute.AttributeName == UGenericGunAttributes::AmmoName)
		{
			NewValue = Math::Clamp(NewValue, 0.0f, MaxAmmo.CurrentValue);
		}
	}

	UFUNCTION(BlueprintOverride)
	void PostAttributeChange(FGameplayAttribute Attribute, float OldValue, float NewValue)
	{
		if (Attribute.AttributeName == UGenericGunAttributes::AmmoName)
		{
			Print(f"Remaining Ammo: {NewValue}", 1.0f, FLinearColor::Purple);
			AmmoAttributeChanged.Broadcast(NewValue, OldValue);
		}
	}

	UFUNCTION(BlueprintOverride)
	void PostGameplayEffectExecute(FGameplayEffectSpec EffectSpec,
								   FGameplayModifierEvaluatedData& EvaluatedData,
								   UAngelscriptAbilitySystemComponent AbilitySystemComponent)
	{
		if (EvaluatedData.Attribute.AttributeName == UPlayerAttributes::AmmoName)
		{
			Ammo.SetCurrentValue(Math::Clamp(Ammo.CurrentValue, 0, MaxAmmo.CurrentValue));
		}
	}

	APondHero GetOwningHero() property
	{
		auto PS = Cast<APlayerState>(GetOwningActor());
		return Cast<APondHero>(PS.Pawn);
	}
}