/**
 * Generic damage calculation that can be used for any damage type. 
 * It applies the SetByCaller.Damage magnitude to the target's health and shield, without any additional modifiers or effects.
 * @note Does not account for precision hits! - For precision hit calculation, use UGEXC_PrecisionHitCalculation instead.
 */
class UGEXC_GenericDamageCalculation : UGEXC_DamageCalculationBase
{
	default RelevantAttributesToCapture.Add(UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes::StaticClass(), UEnemyAttributes::HealthName, EGameplayEffectAttributeCaptureSource::Target, false));
	default RelevantAttributesToCapture.Add(UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes::StaticClass(), UEnemyAttributes::ShieldName, EGameplayEffectAttributeCaptureSource::Target, false));

	UFUNCTION(BlueprintOverride)
	void Execute(FGameplayEffectCustomExecutionParameters ExecutionParams,
				 FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const
	{
		float BaseDamage = ExecutionParams.OwningSpec.GetSetByCallerMagnitude(GameplayTags::SetByCaller_Damage);

        float32 CurrentHealth = GetHealthMagnitude(ExecutionParams, EGameplayEffectAttributeCaptureSource::Target);
        float32 CurrentShield = GetShieldMagnitude(ExecutionParams, EGameplayEffectAttributeCaptureSource::Target);
		FDamageResult Result = CalculateDamageDistribution(BaseDamage, false, 0, CurrentHealth, CurrentShield);

		OutExecutionOutput.ApplyGenericDamage(Result, this);
	}
}