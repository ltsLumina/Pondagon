class UGEXC_SixShooterHawkmonCalculation : UGEXC_DamageCalculationBase
{
	UFUNCTION(BlueprintOverride)
	void Execute(FGameplayEffectCustomExecutionParameters ExecutionParams,
				 FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const
	{
		// Might seem wrong to check if we're out of bullets, but this calculation runs after the final bullet is shot.
		// Therefore, this technically means we're applying this damage on top of the last bullet.
        //if (CurrentAmmo > 0) return;
		if (!ExecutionParams.OwningSpec.DynamicAssetTags.HasTag(GameplayTags::Data_IsLastBullet)) return;
        
        //float PrecisionHits = ASC.GetAttributeCurrentValue(USixShooterAttributes, USixShooterAttributes::PrecisionHitsName);
		float PrecisionHits = ExecutionParams.OwningSpec.GetSetByCallerMagnitude(GameplayTags::SetByCaller_PrecisionHits, true, 0);
        
        UWeaponDefinition Def;
        
        auto PS = ExecutionParams.OwningSpec.GetContext().Instigator;
        auto Char = Cast<APlayerState>(PS).Pawn;

        auto GunComponent = UGunComponent::Get(Char).CurrentGun;
        Def = GunComponent.WeaponDefinition;
        
		const float HAWKMOON_FACTOR = 0.25f;
		float HawkmoonDamage = Def.GetDamage() * (1 + (PrecisionHits * HAWKMOON_FACTOR));

		FGameplayAttribute Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UEnemyAttributes, UEnemyAttributes::HealthName);
        FGameplayModifierEvaluatedData EvaluatedData;
        CalculationUtils::MakeOutputModifier(Attribute, -HawkmoonDamage, EvaluatedData);

		PrintFromObject(Def, f"{HawkmoonDamage=}", 1.5f, FLinearColor::Red);

		OutExecutionOutput.AddOutputModifier(EvaluatedData);
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