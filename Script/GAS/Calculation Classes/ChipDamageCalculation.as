/**
 * Deals chip damage to health based on the coefficient of armor resistance (default = 0.66).
 * @note DOES NOT WORK AGAINST PLAYERS!!
 */
class UGEXC_ChipDamageCalculation : UGEXC_DamageCalculationBase
{
	UFUNCTION(BlueprintOverride)
	void Execute(FGameplayEffectCustomExecutionParameters ExecutionParams,
				 FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const
	{
		float32 RawDamage = 0.f;
		RawDamage = ExecutionParams.GetOwningSpec().GetSetByCallerMagnitude(GameplayTags::SetByCaller_Damage, true);

		bool IsPrecisionHit = ExecutionParams.OwningSpec.DynamicAssetTags.HasTag(GameplayTags::Data_IsPrecision);
		float32 PrecisionMult = 0.f;
		if (IsPrecisionHit)
		{
			FGameplayEffectAttributeCaptureDefinition PrecisionAttribute = UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UGenericGunAttributes, UGenericGunAttributes::PrecisionName, EGameplayEffectAttributeCaptureSource::Source, false);
			ExecutionParams.AttemptCalculateCapturedAttributeMagnitude(PrecisionAttribute, FGameplayEffectExecutionParameters(), PrecisionMult);
		}

		auto EnemyAttributes = ExecutionParams.TargetAbilitySystemComponent.GetAttributeSet(UEnemyAttributes);

		float CurrentHealth = EnemyAttributes.Health.CurrentValue;
		float CurrentShield = EnemyAttributes.Shield.CurrentValue;
		float HealthDamage;
		float ShieldDamage;

		HealthUtils::CalculateDamageTaken(RawDamage, CurrentHealth, CurrentShield, HealthDamage, ShieldDamage);

		float FinalHealthDamage = HealthDamage * (IsPrecisionHit ? PrecisionMult : 1.0f);
		float FinalShieldDamage = ShieldDamage * (IsPrecisionHit ? PrecisionMult : 1.0f);

		// HEALTH

		FGameplayModifierEvaluatedData HealthEvaluatedData;
		FGameplayAttribute HealthAttribute = UAngelscriptAttributeSet::GetGameplayAttribute(UEnemyAttributes, UEnemyAttributes::HealthName);
		HealthEvaluatedData = UAngelscriptGameplayEffectUtils::MakeGameplayModifierEvaluationData(HealthAttribute, EGameplayModOp::Additive, -FinalHealthDamage);
		OutExecutionOutput.AddOutputModifier(HealthEvaluatedData);

		PrintFromObject(this, f"Chip Damage Health: {FinalHealthDamage}", 1.5f, FLinearColor::Red);

		// SHIELD

		FGameplayModifierEvaluatedData ShieldEvaluatedData;
		FGameplayAttribute ShieldAttribute = UAngelscriptAttributeSet::GetGameplayAttribute(UEnemyAttributes, UEnemyAttributes::ShieldName);
		ShieldEvaluatedData.SetAttribute(ShieldAttribute);
		ShieldEvaluatedData.SetModifierOp(EGameplayModOp::Additive);
		ShieldEvaluatedData.SetMagnitude(-FinalShieldDamage);
		OutExecutionOutput.AddOutputModifier(ShieldEvaluatedData);

		PrintFromObject(this, f"Chip Damage Shield: {FinalShieldDamage}", 1.5f, FLinearColor::Blue);
	}
}