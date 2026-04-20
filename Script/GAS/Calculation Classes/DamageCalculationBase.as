struct FDamageResult
{
	float ShieldDamage;
	float HealthDamage;
	bool IsPrecisionHit;
}

enum EGameplayEffectTargetType
{
	Player,
	Enemy,
	/**
	 * Not used anywhere yet.
	 */
	Other,
}

/**
 * Base class for damage calculation. Provides useful helper functions for damage calculation and boilerplate.
 */
UCLASS(Abstract, NotBlueprintable)
class UGEXC_DamageCalculationBase : UGameplayEffectExecutionCalculation
{
	/**
	 * Returns the damage magnitude from the SetByCaller.Damage tag.
	 * Remember to set it in the ability's event graph!
	 */
	float32 GetDamageMagnitude(FGameplayEffectCustomExecutionParameters ExecutionParams)
	{
		return ExecutionParams.OwningSpec.GetSetByCallerMagnitude(GameplayTags::SetByCaller_Damage);
	}
	
	float32 GetHealthMagnitude(FGameplayEffectCustomExecutionParameters ExecutionParams, EGameplayEffectTargetType Target, EGameplayEffectAttributeCaptureSource Source = EGameplayEffectAttributeCaptureSource::Target) const
	{
		float32 CurrentHealth = 0.f;
		
		FGameplayEffectAttributeCaptureDefinition HealthAttribute;
		if (Target == EGameplayEffectTargetType::Player) HealthAttribute = UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UPlayerAttributes, UPlayerAttributes::ShieldName, Source, false);
		if (Target == EGameplayEffectTargetType::Enemy) HealthAttribute = UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes, UEnemyAttributes::ShieldName, Source, false);

		ExecutionParams.AttemptCalculateCapturedAttributeMagnitude(HealthAttribute, FGameplayEffectExecutionParameters(), CurrentHealth);
		return CurrentHealth;
	}

	float32 GetShieldMagnitude(FGameplayEffectCustomExecutionParameters ExecutionParams, EGameplayEffectTargetType Target, EGameplayEffectAttributeCaptureSource Source = EGameplayEffectAttributeCaptureSource::Target) const
	{
		float32 CurrentShield = 0.f;
		
		FGameplayEffectAttributeCaptureDefinition ShieldAttribute;
		if (Target == EGameplayEffectTargetType::Player) ShieldAttribute = UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UPlayerAttributes, UPlayerAttributes::ShieldName, Source, false);
		if (Target == EGameplayEffectTargetType::Enemy) ShieldAttribute = UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes, UEnemyAttributes::ShieldName, Source, false);
		
		
		ExecutionParams.AttemptCalculateCapturedAttributeMagnitude(ShieldAttribute, FGameplayEffectExecutionParameters(), CurrentShield);
		return CurrentShield;
	}

	/**
	 * Calculate the distribution of damage across shield and health.
	 * @note Must be called in order to deal damage to shield!! Failure to call this will result in damage being dealt directly to the specified attribute.
	 */
	FDamageResult CalculateDamageDistribution(float RawDamage, bool IsPrecisionHit, float PrecisionMultiplier, float CurrentHealth, float CurrentShield) const
	{
		FDamageResult Result;

		float HealthDamage;
		float ShieldDamage;

		HealthUtils::CalculateDamageTaken(RawDamage, CurrentHealth, CurrentShield, HealthDamage, ShieldDamage);

		Result.HealthDamage = HealthDamage * (IsPrecisionHit ? PrecisionMultiplier : 1.0f);
		Result.ShieldDamage = ShieldDamage;
		Result.IsPrecisionHit = IsPrecisionHit;
		return Result;
	}
}

mixin void
ApplyGenericDamage(FGameplayEffectCustomExecutionOutput& OutExecutionOutput, FGameplayEffectCustomExecutionParameters ExecutionParams, EGameplayEffectTargetType Target, FDamageResult& Result, const UObject WorldContextObject = nullptr)
{
	auto TargetASC = Cast<UAngelscriptAbilitySystemComponent>(ExecutionParams.TargetAbilitySystemComponent);
	if (IsValid(TargetASC) && TargetASC.HasGameplayTag(GameplayTags::Character_Buffs_Invulnerable)) return;
	
	if (Result.ShieldDamage > 0)
	{
		FGameplayAttribute ShieldAttribute;
		if (Target == EGameplayEffectTargetType::Player) ShieldAttribute = UAngelscriptAttributeSet::GetGameplayAttribute(UPlayerAttributes, UPlayerAttributes::HealthName);
		if (Target == EGameplayEffectTargetType::Enemy) ShieldAttribute = UAngelscriptAttributeSet::GetGameplayAttribute(UEnemyAttributes, UEnemyAttributes::ShieldName);
		
		OutExecutionOutput.AddOutputModifier(UAngelscriptGameplayEffectUtils::MakeGameplayModifierEvaluationData(ShieldAttribute, EGameplayModOp::Additive, -Result.ShieldDamage));

		if (WorldContextObject != nullptr)
			PrintFromObject(WorldContextObject, f"{Result.ShieldDamage=}", 1.5f, FLinearColor::Blue);
	}
	else if (Result.HealthDamage > 0)
	{
		FGameplayAttribute HealthAttribute;
		if (Target == EGameplayEffectTargetType::Player) HealthAttribute = UAngelscriptAttributeSet::GetGameplayAttribute(UPlayerAttributes, UPlayerAttributes::HealthName);
		if (Target == EGameplayEffectTargetType::Enemy) HealthAttribute = UAngelscriptAttributeSet::GetGameplayAttribute(UEnemyAttributes, UEnemyAttributes::HealthName);

		OutExecutionOutput.AddOutputModifier(UAngelscriptGameplayEffectUtils::MakeGameplayModifierEvaluationData(HealthAttribute, EGameplayModOp::Additive, -Result.HealthDamage));

		if (WorldContextObject != nullptr)
			PrintFromObject(WorldContextObject, f"{Result.HealthDamage=} (Precision: {Result.IsPrecisionHit})", 1.5f, FLinearColor::Red);
	}
}