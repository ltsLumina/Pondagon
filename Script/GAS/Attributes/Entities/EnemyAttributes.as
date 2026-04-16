namespace UEnemyAttributes
{
	const FName HealthName = n"Health";
	const FName MaxHealthName = n"MaxHealth";
	const FName ShieldName = n"Shield";
	const FName MaxShieldName = n"MaxShield";
	const FName AmmoName = n"Ammo";
	const FName MaxAmmoName = n"MaxAmmo";
}

class UEnemyAttributes : UAngelscriptAttributeSet
{
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_Health, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData Health;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_MaxHealth, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData MaxHealth;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_Shield, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData Shield;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_MaxShield, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData MaxShield;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_MoveSpeed, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData MoveSpeed;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_MaxMoveSpeed, Category = "Hero Attributes")
	FAngelscriptGameplayAttributeData MaxMoveSpeed;

	UEnemyAttributes()
	{
		Health.Initialize(100.0f);
		MaxHealth.Initialize(100.0f);
		Shield.Initialize(100.0f);
		MaxShield.Initialize(100.0f);
		MoveSpeed.Initialize(600.0f);
		MaxMoveSpeed.Initialize(600.0f);
	}

	// #region On_Rep
	UFUNCTION(NotBlueprintCallable)
	void OnRep_Health(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}

	UFUNCTION(NotBlueprintCallable)
	void OnRep_MaxHealth(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}

	UFUNCTION(NotBlueprintCallable)
	void OnRep_Shield(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}

	UFUNCTION(NotBlueprintCallable)
	void OnRep_MaxShield(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}

	UFUNCTION(NotBlueprintCallable)
	void OnRep_MoveSpeed(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}

	UFUNCTION(NotBlueprintCallable)
	void OnRep_MaxMoveSpeed(FAngelscriptGameplayAttributeData& OldAttributeData)
	{
		OnRep_Attribute(OldAttributeData);
	}
	// #endregion

	// ORDER OF EXECUTION AND RESPONSIBILITY
	// 1. | PRE ATTRIBUTE CHANGE: Perform clamping for ASC to use.
	// 2. | POST GAMEPLAY EFFECT EXECUTE: Update value to new clamped non-zero value, perform post-execute effects such as target death.
	// 3. | POST ATTRIBUTE CHANGE: Broadcast attribute update to listeners.

	UFUNCTION(BlueprintOverride)
	void PreAttributeChange(FGameplayAttribute Attribute, float32& NewValue)
	{
		if (Attribute.AttributeName == UEnemyAttributes::HealthName)
		{
			// Value gets rounded to nearest whole value. Prevents enemy from having 0.5hp.
			// This treatment is not done to players.
			NewValue = Math::RoundToInt(NewValue);

			NewValue = Math::Clamp(NewValue, 0.0f, MaxHealth.CurrentValue);
		}
		else if (Attribute.AttributeName == UEnemyAttributes::ShieldName)
		{
			NewValue = Math::Clamp(NewValue, 0.0f, MaxShield.CurrentValue);
		}
	}

	UFUNCTION(BlueprintOverride)
	void PostAttributeChange(FGameplayAttribute Attribute, float OldValue, float NewValue)
	{
		if (Attribute.AttributeName == UEnemyAttributes::HealthName)
		{
			// Health.SetBaseValue(Math::Clamp(NewValue, 0.0f, MaxHealth.BaseValue));
		}
		else if (Attribute.AttributeName == UEnemyAttributes::ShieldName)
		{
			// Shield.SetBaseValue(Math::Clamp(NewValue, 0.0f, MaxShield.BaseValue));
			bool WasShieldBreak = NewValue <= OldValue;
			// if (WasShieldBreak) AbilitySystem::SendGameplayEventToActor()
		}
	}

	/**
	 * CALLED ON THE SERVER ONLY!!
	 * ALSO ONLY CALLED ON BASE VALUE CHANGES, NOT CURRENT VALUE!
	 */
	UFUNCTION(BlueprintOverride)
	void PostGameplayEffectExecute(FGameplayEffectSpec EffectSpec,
								   FGameplayModifierEvaluatedData& EvaluatedData,
								   UAngelscriptAbilitySystemComponent AbilitySystemComponent)
	{
		if (EvaluatedData.Attribute.AttributeName == UEnemyAttributes::HealthName)
		{
			Health.SetCurrentValue(Math::Clamp(Health.CurrentValue, 0, MaxHealth.CurrentValue));

			bool WasPrecision = EffectSpec.DynamicAssetTags.HasTag(GameplayTags::Data_IsPrecision);
			float DamageDealt = EvaluatedData.Magnitude;
			bool WasKill = Health.CurrentValue <= 0;

			FGameplayEventData Payload;
			FHitResult Hit;
			EffectSpec.Context.GetHitResult(Hit);

			Payload.Instigator = EffectSpec.Context.Instigator;
			Payload.Target = Hit.Actor;
			Payload.EventMagnitude = EvaluatedData.Magnitude;
			Payload.TargetData = AbilitySystem::AbilityTargetDataFromHitResult(Hit);

			auto InstigatorASC = AbilitySystem::GetAngelscriptAbilitySystemComponent(EffectSpec.Context.Instigator);
			InstigatorASC.SendGameplayEvent(GetResultingTrigger(true, WasPrecision, WasKill), Payload);
			// AbilitySystem::SendGameplayEventToActor(Hit.Actor, GetResultingTrigger(true, WasPrecision, WasKill), Payload);

			if (WasKill)
				EnemyBase.Death();
		}
		else if (EvaluatedData.Attribute.AttributeName == UEnemyAttributes::ShieldName)
		{
			Shield.SetCurrentValue(Math::Clamp(Shield.CurrentValue, 0, MaxShield.CurrentValue));
		}
	}

	AScriptEnemyBase GetEnemyBase() property
	{
		return Cast<AScriptEnemyBase>(GetOwningActor());
	}

	FGameplayTag GetResultingTrigger(bool WasHit, bool WasPrecision, bool WasKill)
	{
		FGameplayTag ResultTag;

		if (WasHit)
			ResultTag = GameplayTags::Enchantment_Trigger_OnHit;
		if (WasHit && WasPrecision)
			ResultTag = GameplayTags::Enchantment_Trigger_OnPrecisionHit;
		if (WasHit && WasKill)
			ResultTag = GameplayTags::Enchantment_Trigger_OnKill;
		if (WasHit && WasPrecision && WasKill)
			ResultTag = GameplayTags::Enchantment_Trigger_OnPrecisionKill;

		return ResultTag;
	}
}