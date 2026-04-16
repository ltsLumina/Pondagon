namespace URailgunAttributres
{
	const FName ChargeName = n"Charge";
}

class URailgunAttributres : UAngelscriptAttributeSet
{
	UPROPERTY(BlueprintReadOnly)
	FAngelscriptGameplayAttributeData Charge;

	URailgunAttributres()
	{
		Charge.Initialize(0);
	}

	// ORDER OF EXECUTION AND RESPONSIBILITY
	// 1. | PRE ATTRIBUTE CHANGE: Perform clamping for ASC to use.
	// 2. | POST GAMEPLAY EFFECT EXECUTE: Update value to new clamped non-zero value, perform post-execute effects such as target death.
	// 3. | POST ATTRIBUTE CHANGE: Broadcast attribute update to listeners.

	//~
	UFUNCTION(BlueprintOverride)
	void PreAttributeChange(FGameplayAttribute Attribute, float32& NewValue)
	{
	}

	UFUNCTION(BlueprintOverride)
	void PostAttributeChange(FGameplayAttribute Attribute, float OldValue, float NewValue)
	{
		//Print(f"Charge: {NewValue}", 1.0f);
	}

	UFUNCTION(BlueprintOverride)
	void PostGameplayEffectExecute(FGameplayEffectSpec EffectSpec,
								   FGameplayModifierEvaluatedData& EvaluatedData,
								   UAngelscriptAbilitySystemComponent AbilitySystemComponent)
	{
		if (EvaluatedData.Attribute.AttributeName == URailgunAttributres::ChargeName)
		{

		}
	}

	AScriptPondHero GetOwningHero() property
	{
		auto PS = Cast<APlayerState>(GetOwningActor());
		return Cast<AScriptPondHero>(PS.Pawn);
	}
}