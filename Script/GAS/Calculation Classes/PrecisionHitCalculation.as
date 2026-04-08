/**
 * This class should be used as the custom calculation class on enemy target that can take precision damage.
 * If the target CANNOT take precision damage, use a scalable float modifier with a SetByCaller tag.
 */
class UGEXC_PrecisionHitCalculation : UGEXC_DamageCalculationBase
{
	default RelevantAttributesToCapture.Add(UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes, UEnemyAttributes::HealthName, EGameplayEffectAttributeCaptureSource::Target, false));
	default RelevantAttributesToCapture.Add(UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes, UEnemyAttributes::ShieldName, EGameplayEffectAttributeCaptureSource::Target, false));

	UFUNCTION(BlueprintOverride)
	void Execute(FGameplayEffectCustomExecutionParameters ExecutionParams,
				 FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const
	{
		float32 RawDamage = 0.f;
		RawDamage = ExecutionParams.GetOwningSpec().GetSetByCallerMagnitude(GameplayTags::SetByCaller_Damage, true, RawDamage);

		FWeaponStats Stats = GetWeaponStats(ExecutionParams.SourceAbilitySystemComponent);

		float BaseDamage = Stats.GetDamage();
		bool IsPrecisionHit = ExecutionParams.OwningSpec.DynamicAssetTags.HasTag(GameplayTags::Data_IsPrecision);
		float Multiplier = Stats.GetPrecision();

		float32 CurrentHealth = 0.f;
		FGameplayEffectAttributeCaptureDefinition HealthAttribute = UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes, n"Health", EGameplayEffectAttributeCaptureSource::Target, false);
		ExecutionParams.AttemptCalculateCapturedAttributeMagnitude(HealthAttribute, FGameplayEffectExecutionParameters(), CurrentHealth);

		// TODO: Update source plugin UAngelscriptGameplayEffectUtils.cpp
		float32 CurrentShield = 0.f;
		auto AttributeDef = UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes, n"Shield", EGameplayEffectAttributeCaptureSource::Target, false);
		ExecutionParams.AttemptCalculateCapturedAttributeMagnitude(AttributeDef, FGameplayEffectExecutionParameters(), CurrentShield);
		
		FDamageResult Result = CalculateDamageDistribution(BaseDamage, IsPrecisionHit, Multiplier, CurrentHealth, CurrentShield);
		OutExecutionOutput.ApplyGenericDamage(Result, this);

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

class UGEC_StandardDamageCalculation : UGameplayModMagnitudeCalculation
{

	UFUNCTION(BlueprintOverride)
	float32 CalculateBaseMagnitude(FGameplayEffectSpec Spec) const
	{
		float FinalDamage = Spec.GetModifierMagnitude(0, false);
		PrintFromObject(this, f"{FinalDamage=}", 11.5f, FLinearColor::Green);

		return float32(FinalDamage);
	}
}