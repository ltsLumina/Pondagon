/**
 * Generic damage calculation that can be used for any damage type AGAINST players.
 * It applies the SetByCaller.Damage magnitude to the target's health and shield, without any additional modifiers or effects.
 * @note Does not account for precision hits! - For precision hit calculation, use UGEXC_PrecisionHitCalculation instead.
 */
class UGEXC_EnemyDamageCalculation : UGEXC_DamageCalculationBase
{
	default RelevantAttributesToCapture.Add(UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UPlayerAttributes, UPlayerAttributes::HealthName, EGameplayEffectAttributeCaptureSource::Target, false));
	default RelevantAttributesToCapture.Add(UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UPlayerAttributes, UPlayerAttributes::ShieldName, EGameplayEffectAttributeCaptureSource::Target, false));

	UFUNCTION(BlueprintOverride)
	void Execute(FGameplayEffectCustomExecutionParameters ExecutionParams,
				 FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const
	{
		float RawDamage = ExecutionParams.OwningSpec.GetSetByCallerMagnitude(GameplayTags::SetByCaller_Damage);

        float32 CurrentHealth = GetHealthMagnitude(ExecutionParams, EGameplayEffectTargetType::Player, EGameplayEffectAttributeCaptureSource::Target);
        float32 CurrentShield = GetShieldMagnitude(ExecutionParams, EGameplayEffectTargetType::Player, EGameplayEffectAttributeCaptureSource::Target);
		FDamageResult Result = CalculateDamageDistribution(RawDamage, false, 0, CurrentHealth, CurrentShield);

		OutExecutionOutput.ApplyGenericDamage(EGameplayEffectTargetType::Player, Result, this);
	}
}