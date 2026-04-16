namespace UGenericGunAttributes
{
	const FName AmmoName = n"Ammo";
	const FName MaxAmmoName = n"MaxAmmo";
	const FName MagazineName = n"Magazine";
	const FName ZoomName = n"Zoom";
	const FName FireRateName = n"FireRate";
	const FName ReloadSpeedName = n"ReloadSpeed";
	const FName AimAssistName = n"AimAssist";
	const FName RecoilName = n"Recoil";
	const FName PrecisionName = n"Precision";
	const FName DamageName = n"Damage";
}

event void FOnAmmoChanged(float NewAmmo, float OldAmmo);

class UGenericGunAttributes : UAngelscriptAttributeSet
{
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing=OnRep_Ammo, Category = "Gun Attributes")
	FAngelscriptGameplayAttributeData Ammo;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing=OnRep_MaxAmmo, Category = "Gun Attributes")
	FAngelscriptGameplayAttributeData MaxAmmo;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing=OnRep_Zoom, Category = "Gun Attributes")
	FAngelscriptGameplayAttributeData Zoom;

	/**
	 * Fire-rate in rounds/sec
	 */
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing=OnRep_FireRate, Category = "Gun Attributes")
	FAngelscriptGameplayAttributeData FireRate;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing=OnRep_ReloadSpeed, Category = "Gun Attributes")
	FAngelscriptGameplayAttributeData ReloadSpeed;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing=OnRep_AimAssist, Category = "Gun Attributes")
	FAngelscriptGameplayAttributeData AimAssist;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing=OnRep_Recoil, Category = "Gun Attributes")
	FAngelscriptGameplayAttributeData Recoil;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing=OnRep_Precision, Category = "Gun Attributes")
	FAngelscriptGameplayAttributeData Precision;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing=OnRep_Damage, Category = "Gun Attributes")
	FAngelscriptGameplayAttributeData Damage;

	UGenericGunAttributes()
	{
		Ammo.Initialize(30.0f);
		MaxAmmo.Initialize(30.0f);
		Zoom.Initialize(1.25f);
		FireRate.Initialize(30.0f);
		ReloadSpeed.Initialize(1.0f);
		AimAssist.Initialize(1.5f);
		Recoil.Initialize(1.0f);
		Precision.Initialize(1.5f);
		Damage.Initialize(10.0f);
	}

	/* #region OnRep */
	UFUNCTION(NotBlueprintCallable)
	void OnRep_Ammo(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}

	UFUNCTION(NotBlueprintCallable)
	void OnRep_MaxAmmo(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}

	UFUNCTION(NotBlueprintCallable)
	void OnRep_Zoom(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}

	UFUNCTION(NotBlueprintCallable)
	void OnRep_FireRate(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}

	UFUNCTION(NotBlueprintCallable)
	void OnRep_ReloadSpeed(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}

	UFUNCTION(NotBlueprintCallable)
	void OnRep_AimAssist(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}

	UFUNCTION(NotBlueprintCallable)
	void OnRep_Recoil(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}

	UFUNCTION(NotBlueprintCallable)
	void OnRep_Precision(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}

	UFUNCTION(NotBlueprintCallable)
	void OnRep_Damage(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}
	/* #endregion */

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
			//Print(f"Remaining Ammo: {NewValue}", 1.0f, FLinearColor::Purple);
		}
	}

	UFUNCTION(BlueprintOverride)
	void PostGameplayEffectExecute(FGameplayEffectSpec EffectSpec,
								   FGameplayModifierEvaluatedData& EvaluatedData,
								   UAngelscriptAbilitySystemComponent AbilitySystemComponent)
	{
		if (EvaluatedData.Attribute.AttributeName == UGenericGunAttributes::AmmoName)
		{
			Ammo.SetCurrentValue(Math::Clamp(Ammo.CurrentValue, 0, MaxAmmo.CurrentValue));
		}
	}

	AScriptPondHero GetOwningHero() property
	{
		auto PS = Cast<APlayerState>(GetOwningActor());
		return Cast<AScriptPondHero>(PS.Pawn);
	}
}