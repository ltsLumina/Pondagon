class UGEXC_SixShooterHawkmonCalculation : UGEXC_DamageCalculationBase
{
	UFUNCTION(BlueprintOverride)
	void Execute(FGameplayEffectCustomExecutionParameters ExecutionParams,
				 FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const
	{
		// Might seem wrong to check if we're out of bullets, but this calculation runs after the final bullet is shot.
		// Therefore, this technically means we're applying this damage on top of the last bullet.
        //if (CurrentAmmo > 0) return;
		if (!ExecutionParams.OwningSpec.DynamicAssetTags.HasTag(GameplayTags::Data_IsLastBullet)) return;
        
		float BaseWeaponDamage = GetWeaponStats(ExecutionParams.SourceAbilitySystemComponent).GetDamage();

		bool IsPrecisionHit = ExecutionParams.OwningSpec.DynamicAssetTags.HasTag(GameplayTags::Data_IsPrecision);
		float Multiplier = GetWeaponStats(ExecutionParams.SourceAbilitySystemComponent).GetPrecision();
		float PrecisionDamage = BaseWeaponDamage * (IsPrecisionHit ? Multiplier : 1.0f);

		float PrecisionHits = ExecutionParams.OwningSpec.GetSetByCallerMagnitude(GameplayTags::SetByCaller_PrecisionHits, true, 0);
		const float HAWKMOON_FACTOR = 0.25f;
		
		float HawkmoonExpression = (1 + (PrecisionHits * HAWKMOON_FACTOR));
		float HawkmoonDamage = PrecisionDamage * HawkmoonExpression;

		PrintFromObject(this, f"{HawkmoonDamage=}", 2.5f, FLinearColor::Red);

		FDamageResult Result = CalculateDamageDistribution(HawkmoonDamage, false, 0, GetHealthMagnitude(ExecutionParams), GetShieldMagnitude(ExecutionParams));
		OutExecutionOutput.ApplyGenericDamage(Result, this);
	}
}

namespace CalculationUtils
{
    FGameplayModifierEvaluatedData MakeOutputModifier(FGameplayAttribute Attribute, float Magnitude, FGameplayModifierEvaluatedData&out EvaluatedData)
    {
		EvaluatedData.SetAttribute(Attribute);
		EvaluatedData.SetModifierOp(EGameplayModOp::Additive);
		EvaluatedData.SetMagnitude(Magnitude);

        return EvaluatedData;
    }
}