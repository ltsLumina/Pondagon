/**
 * Deals chip damage to health based on the coefficient of armor resistance (default = 0.66).
 */
class UGEXC_ChipDamageCalculation : UGEXC_DamageCalculationBase
{
	UFUNCTION(BlueprintOverride)
	void Execute(FGameplayEffectCustomExecutionParameters ExecutionParams,
	             FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const
	{
        UWeaponDefinition Def;
        
        auto PS = ExecutionParams.SourceAbilitySystemComponent.GetOwner();
        auto Char = Cast<APlayerState>(PS).Pawn;

        auto GunComponent = UGunComponent::Get(Char).CurrentGun;
        Def = GunComponent.WeaponDefinition;
        
		bool IsPrecisionHit = ExecutionParams.OwningSpec.DynamicAssetTags.HasTag(GameplayTags::Data_IsPrecision);
		float Multiplier = Def.Stats.Advanced.Precision;

		auto EnemyAttributes = ExecutionParams.TargetAbilitySystemComponent.GetAttributeSet(UEnemyAttributes);

		float BaseDamage = Def.GetDamage();
		float CurrentHealth = EnemyAttributes.Health.CurrentValue;
		float CurrentShield = EnemyAttributes.Shield.CurrentValue;
		float HealthDamage;
		float ShieldDamage;
		
		HealthUtils::CalculateDamageTaken(BaseDamage, CurrentHealth, CurrentShield, HealthDamage, ShieldDamage);

		float FinalHealthDamage = HealthDamage * (IsPrecisionHit ? Multiplier : 1.0f);
		float FinalShieldDamage = ShieldDamage * (IsPrecisionHit ? Multiplier : 1.0f);

		// HEALTH

		FGameplayModifierEvaluatedData HealthEvaluatedData;
		FGameplayAttribute HealthAttribute = UAngelscriptAttributeSet::GetGameplayAttribute(UEnemyAttributes, UEnemyAttributes::HealthName);
		HealthEvaluatedData = UAngelscriptGameplayEffectUtils::MakeGameplayModifierEvaluationData(HealthAttribute, EGameplayModOp::Additive, -FinalHealthDamage);
		OutExecutionOutput.AddOutputModifier(HealthEvaluatedData);

		PrintFromObject(Def, f"{FinalHealthDamage=}", 1.5f, FLinearColor::Red);
		
		// SHIELD

		FGameplayModifierEvaluatedData ShieldEvaluatedData;
		FGameplayAttribute ShieldAttribute = UAngelscriptAttributeSet::GetGameplayAttribute(UEnemyAttributes, UEnemyAttributes::ShieldName);
		ShieldEvaluatedData.SetAttribute(ShieldAttribute);
		ShieldEvaluatedData.SetModifierOp(EGameplayModOp::Additive);
		ShieldEvaluatedData.SetMagnitude(-FinalShieldDamage);
		OutExecutionOutput.AddOutputModifier(ShieldEvaluatedData);

		PrintFromObject(Def, f"{FinalShieldDamage=}", 1.5f, FLinearColor::Blue);
	}
}