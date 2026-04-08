struct FDamageResult
{
	float ShieldDamage;
	float HealthDamage;
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
	
	float32 GetHealthMagnitude(FGameplayEffectCustomExecutionParameters ExecutionParams, EGameplayEffectAttributeCaptureSource Source = EGameplayEffectAttributeCaptureSource::Target) const
	{
		float32 CurrentHealth = 0.f;
		FGameplayEffectAttributeCaptureDefinition HealthAttribute = UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes, UEnemyAttributes::HealthName, Source, false);
		ExecutionParams.AttemptCalculateCapturedAttributeMagnitude(HealthAttribute, FGameplayEffectExecutionParameters(), CurrentHealth);
		return CurrentHealth;
	}

	float32 GetShieldMagnitude(FGameplayEffectCustomExecutionParameters ExecutionParams, EGameplayEffectAttributeCaptureSource Source = EGameplayEffectAttributeCaptureSource::Target) const
	{
		float32 CurrentShield = 0.f;
		FGameplayEffectAttributeCaptureDefinition HealthAttribute = UAngelscriptGameplayEffectUtils::CaptureGameplayAttribute(UEnemyAttributes, UEnemyAttributes::ShieldName, Source, false);
		ExecutionParams.AttemptCalculateCapturedAttributeMagnitude(HealthAttribute, FGameplayEffectExecutionParameters(), CurrentShield);
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
		return Result;
	}

	FWeaponStats GetWeaponStats(UAbilitySystemComponent SourceAbilitySystem) const
	{
		UWeaponDefinition Def;

		auto PS = SourceAbilitySystem.GetOwner();
		auto Char = Cast<APlayerState>(PS).Pawn;

		auto GunComponent = UGunComponent::Get(Char).CurrentGun;
		Def = GunComponent.WeaponDefinition;
		return Def.Stats;
	}
}

mixin void
ApplyGenericDamage(FGameplayEffectCustomExecutionOutput& OutExecutionOutput, FDamageResult Result, const UObject WorldContextObject = nullptr)
{
	if (Result.ShieldDamage > 0)
	{
		FGameplayAttribute ShieldAttribute = UAngelscriptAttributeSet::GetGameplayAttribute(UEnemyAttributes, UEnemyAttributes::ShieldName);
		OutExecutionOutput.AddOutputModifier(UAngelscriptGameplayEffectUtils::MakeGameplayModifierEvaluationData(ShieldAttribute, EGameplayModOp::Additive, -Result.ShieldDamage));

		if (WorldContextObject != nullptr)
			PrintFromObject(WorldContextObject, f"{Result.ShieldDamage=}", 1.5f, FLinearColor::Blue);
	}
	else if (Result.HealthDamage > 0)
	{
		FGameplayAttribute HealthAttribute = UAngelscriptAttributeSet::GetGameplayAttribute(UEnemyAttributes, UEnemyAttributes::HealthName);
		OutExecutionOutput.AddOutputModifier(UAngelscriptGameplayEffectUtils::MakeGameplayModifierEvaluationData(HealthAttribute, EGameplayModOp::Additive, -Result.HealthDamage));

		if (WorldContextObject != nullptr)
			PrintFromObject(WorldContextObject, f"{Result.HealthDamage=}", 1.5f, FLinearColor::Red);
	}
}