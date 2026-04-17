namespace UBaptoadAttributes
{
	const FName DamageRoundsName = n"DamageRounds";
	const FName HealingRoundsName = n"HealingRounds";
}

class UBaptoadAttributes : UAngelscriptAttributeSet
{
	UPROPERTY(BlueprintReadOnly)
	FAngelscriptGameplayAttributeData DamageRounds;

    UPROPERTY(BlueprintReadOnly)
	FAngelscriptGameplayAttributeData HealingRounds;

	UBaptoadAttributes()
	{
		DamageRounds.Initialize(6);
		HealingRounds.Initialize(6);
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
		//Print(f"Precision Hits: {NewValue}", 1.0f);
	}

	UFUNCTION(BlueprintOverride)
	void PostGameplayEffectExecute(FGameplayEffectSpec EffectSpec,
								   FGameplayModifierEvaluatedData& EvaluatedData,
								   UAngelscriptAbilitySystemComponent AbilitySystemComponent)
	{
		if (EvaluatedData.Attribute.AttributeName == UBaptoadAttributes::DamageRoundsName)
		{

		}
	}

	AScriptPondHero GetOwningHero() property
	{
		auto PS = Cast<APlayerState>(GetOwningActor());
		return Cast<AScriptPondHero>(PS.Pawn);
	}
}