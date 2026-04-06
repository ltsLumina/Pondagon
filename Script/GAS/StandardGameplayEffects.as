class UGE_Damage_Health : UGameplayEffect
{
	default DurationPolicy = EGameplayEffectDurationType::Instant;
	default StackingType = EGameplayEffectStackingType::None;

	FGameplayModifierInfo Modifier;
	default Modifier.Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UPlayerAttributes, UPlayerAttributes::HealthName);
	default Modifier.ModifierOp = EGameplayModOp::Additive;
	default Modifier.ModifierMagnitude.MagnitudeCalculationType = EGameplayEffectMagnitudeCalculation::SetByCaller;
	default Modifier.ModifierMagnitude.SetByCallerMagnitude.DataTag = GameplayTags::SetByCaller_Damage;

	default Modifiers.Add(Modifier);
};

class UGE_Damage_Shield : UGameplayEffect
{
	default DurationPolicy = EGameplayEffectDurationType::Instant;
	default StackingType = EGameplayEffectStackingType::None;

	FGameplayModifierInfo Modifier;
	default Modifier.Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UPlayerAttributes, UPlayerAttributes::ShieldName);
	default Modifier.ModifierOp = EGameplayModOp::Additive;
	default Modifier.ModifierMagnitude.MagnitudeCalculationType = EGameplayEffectMagnitudeCalculation::SetByCaller;
	default Modifier.ModifierMagnitude.SetByCallerMagnitude.DataTag = GameplayTags::SetByCaller_Damage;

	default Modifiers.Add(Modifier);
};

class UGE_Restore_Health : UGameplayEffect
{
	default DurationPolicy = EGameplayEffectDurationType::Instant;
	default StackingType = EGameplayEffectStackingType::None;

	FGameplayModifierInfo Modifier;
	default Modifier.Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UPlayerAttributes, UPlayerAttributes::HealthName);
	default Modifier.ModifierOp = EGameplayModOp::Additive;
	default Modifier.ModifierMagnitude.MagnitudeCalculationType = EGameplayEffectMagnitudeCalculation::SetByCaller;
	default Modifier.ModifierMagnitude.SetByCallerMagnitude.DataTag = GameplayTags::SetByCaller_Damage;

	default Modifiers.Add(Modifier);
};

class UGE_Override_Shield : UGameplayEffect
{
	default DurationPolicy = EGameplayEffectDurationType::Instant;
	default StackingType = EGameplayEffectStackingType::None;

	FGameplayModifierInfo Modifier;
	default Modifier.Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UPlayerAttributes, UPlayerAttributes::ShieldName);
	default Modifier.ModifierOp = EGameplayModOp::Override;
	default Modifier.ModifierMagnitude.MagnitudeCalculationType = EGameplayEffectMagnitudeCalculation::SetByCaller;
	default Modifier.ModifierMagnitude.SetByCallerMagnitude.DataTag = GameplayTags::SetByCaller_Damage;

	default Modifiers.Add(Modifier);
};