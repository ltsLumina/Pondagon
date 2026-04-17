/**
 * This class should be used as the custom calculation class on enemy target that can take precision damage.
 * If the target CANNOT take precision damage, use a scalable float modifier with a SetByCaller tag.
 */
class UGEXC_PrecisionHitCalculation : UGEXC_DamageCalculationBase
{
	default RelevantAttributesToCapture.Add(UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes, UEnemyAttributes::HealthName, EGameplayEffectAttributeCaptureSource::Target, false));
	default RelevantAttributesToCapture.Add(UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes, UEnemyAttributes::ShieldName, EGameplayEffectAttributeCaptureSource::Target, false));
	default RelevantAttributesToCapture.Add(UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UGenericGunAttributes, UGenericGunAttributes::PrecisionName, EGameplayEffectAttributeCaptureSource::Source, false));

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

		float32 CurrentHealth = 0.f;
		FGameplayEffectAttributeCaptureDefinition HealthAttribute = UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes, UEnemyAttributes
		::HealthName, EGameplayEffectAttributeCaptureSource::Target, false);
		ExecutionParams.AttemptCalculateCapturedAttributeMagnitude(HealthAttribute, FGameplayEffectExecutionParameters(), CurrentHealth);

		float32 CurrentShield = 0.f;
		auto AttributeDef = UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes, UEnemyAttributes::ShieldName, EGameplayEffectAttributeCaptureSource::Target, false);
		ExecutionParams.AttemptCalculateCapturedAttributeMagnitude(AttributeDef, FGameplayEffectExecutionParameters(), CurrentShield);

		FDamageResult Result = CalculateDamageDistribution(RawDamage, IsPrecisionHit, PrecisionMult, CurrentHealth, CurrentShield);
		OutExecutionOutput.ApplyGenericDamage(EGameplayEffectTargetType::Enemy, Result, this);

		/*
				auto EnemyASC = ExecutionParams.TargetAbilitySystemComponent;
				auto EnemyAttributes = Cast<UEnemyAttributes>(EnemyASC.GetAttributeSet(UEnemyAttributes));
				bool Died = EnemyAttributes.Health.CurrentValue - PrecisionHitDamage <= 0;
				PrintFromObject(this, f"{EnemyAttributes.Health.CurrentValue - PrecisionHitDamage}", 10, FLinearColor::Red);

				auto SourceASC = Cast<UAngelscriptAbilitySystemComponent>(ExecutionParams.SourceAbilitySystemComponent);
				auto SourceActor = SourceASC.Avatar;
				if (SourceActor != nullptr)
				{
					auto _GunComponent = UGunComponent::Get(SourceActor);
					if (_GunComponent != nullptr)
					{
						_GunComponent.OnShotResult(PrecisionHitDamage, IsHeadshot, Died);
					}
				}
		*/
	}
}

/**
 * DO NOT USE THIS!!
 * ONLY FOR DEBUG/TESTING!
 */
UCLASS(Deprecated)
class UGEC_StandardDamageCalculation : UGameplayModMagnitudeCalculation
{

	UFUNCTION(BlueprintOverride)
	float32 CalculateBaseMagnitude(FGameplayEffectSpec Spec) const
	{
		float FinalDamage = Spec.GetModifierMagnitude(0);
		PrintFromObject(this, f"{FinalDamage=}", 11.5f, FLinearColor::Green);

		return float32(FinalDamage);
	}
}