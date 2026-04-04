/**
 * This class should be used as the custom calculation class on enemy target that can take precision damage.
 * If the target CANNOT take precision damage, use a scalable float modifier with a SetByCaller tag.
 */
class UGEXC_PrecisionHitCalculation : UGameplayEffectExecutionCalculation
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
        
		bool IsPrecisionHit = ExecutionParams.OwningSpec.DynamicAssetTags.HasTag(GameplayTags::Data_Precision);
		float Multiplier = Def.Stats.Advanced.Precision;
		float FinalDamage = Def.GetDamage() * (IsPrecisionHit ? Multiplier : 1.0f);

		FGameplayModifierEvaluatedData EvaluatedData;
		FGameplayAttribute Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UEnemyAttributes, UEnemyAttributes::HealthName);
		EvaluatedData.SetAttribute(Attribute);
		EvaluatedData.SetModifierOp(EGameplayModOp::Additive);
		EvaluatedData.SetMagnitude(-FinalDamage);

		PrintFromObject(Def, f"{FinalDamage=}", 1.5f, FLinearColor::Red);
		
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
		OutExecutionOutput.AddOutputModifier(EvaluatedData);
	}
}

class UGEXC_SixShooterHawkmonCalculation : UGameplayEffectExecutionCalculation
{
	UFUNCTION(BlueprintOverride)
	void Execute(FGameplayEffectCustomExecutionParameters ExecutionParams,
				 FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const
	{
        auto ASC = Cast<UAngelscriptAbilitySystemComponent>(ExecutionParams.SourceAbilitySystemComponent);
        
        float CurrentAmmo = ASC.GetAttributeCurrentValue(UGenericGunAttributes, UGenericGunAttributes::AmmoName);
        if (CurrentAmmo != 1) return;
        
        float PrecisionHits = ASC.GetAttributeCurrentValue(USixShooterAttributes, USixShooterAttributes::PrecisionHitsName);
        
        UWeaponDefinition Def;
        
        auto PS = ExecutionParams.OwningSpec.GetContext().Instigator;
        auto Char = Cast<APlayerState>(PS).Pawn;

        auto GunComponent = UGunComponent::Get(Char).CurrentGun;
        Def = GunComponent.WeaponDefinition;
        
		const float HAWKMOON_FACTOR = 0.25f;
		float HawkmoonDamage = Def.GetDamage() * (1 + (PrecisionHits * HAWKMOON_FACTOR));

		FGameplayModifierEvaluatedData EvaluatedData;
		FGameplayAttribute Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UEnemyAttributes, UEnemyAttributes::HealthName);
		EvaluatedData.SetAttribute(Attribute);
		EvaluatedData.SetModifierOp(EGameplayModOp::Additive);
		EvaluatedData.SetMagnitude(-HawkmoonDamage);

		PrintFromObject(Def, f"{HawkmoonDamage=}", 1.5f, FLinearColor::Red);

		OutExecutionOutput.AddOutputModifier(EvaluatedData);
	}
}