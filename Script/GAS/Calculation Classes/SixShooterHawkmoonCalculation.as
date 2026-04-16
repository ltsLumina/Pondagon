class UGEXC_SixShooterHawkmonCalculation : UGEXC_DamageCalculationBase
{
	default RelevantAttributesToCapture.Add(UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UGenericGunAttributes, UGenericGunAttributes::PrecisionName, EGameplayEffectAttributeCaptureSource::Source, false));
	
	UFUNCTION(BlueprintOverride)
	void Execute(FGameplayEffectCustomExecutionParameters ExecutionParams,
				 FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const
	{
		// Might seem wrong to check if we're out of bullets, but this calculation runs after the final bullet is shot.
		// Therefore, this technically means we're applying this damage on top of the last bullet.
		// if (CurrentAmmo > 0) return;
		if (!ExecutionParams.OwningSpec.DynamicAssetTags.HasTag(GameplayTags::Data_IsLastBullet))
			return;

		float32 RawDamage = 0.f;
		RawDamage = ExecutionParams.GetOwningSpec().GetSetByCallerMagnitude(GameplayTags::SetByCaller_Damage, true);

		bool IsPrecisionHit = ExecutionParams.OwningSpec.DynamicAssetTags.HasTag(GameplayTags::Data_IsPrecision);
		float32 PrecisionMult = 0.f;
		if (IsPrecisionHit)
		{
			FGameplayEffectAttributeCaptureDefinition PrecisionAttribute = UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UGenericGunAttributes, UGenericGunAttributes::PrecisionName, EGameplayEffectAttributeCaptureSource::Source, false);
			ExecutionParams.AttemptCalculateCapturedAttributeMagnitude(PrecisionAttribute, FGameplayEffectExecutionParameters(), PrecisionMult);
		}

		float PrecisionHits = ExecutionParams.OwningSpec.GetSetByCallerMagnitude(GameplayTags::SetByCaller_PrecisionHits, true, 0);
		const float HAWKMOON_FACTOR = 0.25f;

		float Damage = IsPrecisionHit ? RawDamage * PrecisionMult : RawDamage; 

		float HawkmoonExpression = (1 + (PrecisionHits * HAWKMOON_FACTOR));
		float HawkmoonDamage = Damage * HawkmoonExpression;

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