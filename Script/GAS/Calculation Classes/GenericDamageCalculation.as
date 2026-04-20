/**
 * Generic damage calculation that can be used for any damage type. 
 * It applies the SetByCaller.Damage magnitude to the target's health and shield, without any additional modifiers or effects.
 * @note Does not account for precision hits! - For precision hit calculation, use UGEXC_PrecisionHitCalculation instead.
 */
class UGEXC_GenericDamageCalculation : UGEXC_DamageCalculationBase
{
	default RelevantAttributesToCapture.Add(UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes, UEnemyAttributes::HealthName, EGameplayEffectAttributeCaptureSource::Target, false));
	default RelevantAttributesToCapture.Add(UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes, UEnemyAttributes::ShieldName, EGameplayEffectAttributeCaptureSource::Target, false));

	UFUNCTION(BlueprintOverride)
	void Execute(FGameplayEffectCustomExecutionParameters ExecutionParams,
				 FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const
	{
		float RawDamage = ExecutionParams.OwningSpec.GetSetByCallerMagnitude(GameplayTags::SetByCaller_Damage);

        float32 CurrentHealth = GetHealthMagnitude(ExecutionParams, EGameplayEffectTargetType::Enemy, EGameplayEffectAttributeCaptureSource::Target);
        float32 CurrentShield = GetShieldMagnitude(ExecutionParams, EGameplayEffectTargetType::Enemy, EGameplayEffectAttributeCaptureSource::Target);
		FDamageResult Result = CalculateDamageDistribution(RawDamage, false, 0, CurrentHealth, CurrentShield);

		OutExecutionOutput.ApplyGenericDamage(ExecutionParams, EGameplayEffectTargetType::Enemy, Result, this);
	}
}