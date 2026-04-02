class UGE_Damage_Health : UPondGameplayEffect
{
	default DurationPolicy = EGameplayEffectDurationType::Instant;
	default StackingType = EGameplayEffectStackingType::None;

	FGameplayModifierInfo Modifier;
	default Modifier.Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UPondPlayerGASAttributes, UPondPlayerGASAttributes::HealthName);
	default Modifier.ModifierOp = EGameplayModOp::Additive;
	default Modifier.ModifierMagnitude.MagnitudeCalculationType = EGameplayEffectMagnitudeCalculation::SetByCaller;
	default Modifier.ModifierMagnitude.SetByCallerMagnitude.DataTag = GameplayTags::Data_Damage_Health;

	default Modifiers.Add(Modifier);
};

class UGE_Damage_Shield : UPondGameplayEffect
{
	default DurationPolicy = EGameplayEffectDurationType::Instant;
	default StackingType = EGameplayEffectStackingType::None;

	FGameplayModifierInfo Modifier;
	default Modifier.Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UPondPlayerGASAttributes, UPondPlayerGASAttributes::ShieldName);
	default Modifier.ModifierOp = EGameplayModOp::Additive;
	default Modifier.ModifierMagnitude.MagnitudeCalculationType = EGameplayEffectMagnitudeCalculation::SetByCaller;
	default Modifier.ModifierMagnitude.SetByCallerMagnitude.DataTag = GameplayTags::Data_Damage_Shield;

	default Modifiers.Add(Modifier);
};

class UGE_Restore_Health : UPondGameplayEffect
{
	default DurationPolicy = EGameplayEffectDurationType::Instant;
	default StackingType = EGameplayEffectStackingType::None;

	FGameplayModifierInfo Modifier;
	default Modifier.Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UPondPlayerGASAttributes, UPondPlayerGASAttributes::HealthName);
	default Modifier.ModifierOp = EGameplayModOp::Additive;
	default Modifier.ModifierMagnitude.MagnitudeCalculationType = EGameplayEffectMagnitudeCalculation::SetByCaller;
	default Modifier.ModifierMagnitude.SetByCallerMagnitude.DataTag = GameplayTags::Data_Damage_Health;

	default Modifiers.Add(Modifier);
};

class UGE_Override_Shield : UPondGameplayEffect
{
	default DurationPolicy = EGameplayEffectDurationType::Instant;
	default StackingType = EGameplayEffectStackingType::None;

	FGameplayModifierInfo Modifier;
	default Modifier.Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UPondPlayerGASAttributes, UPondPlayerGASAttributes::ShieldName);
	default Modifier.ModifierOp = EGameplayModOp::Override;
	default Modifier.ModifierMagnitude.MagnitudeCalculationType = EGameplayEffectMagnitudeCalculation::SetByCaller;
	default Modifier.ModifierMagnitude.SetByCallerMagnitude.DataTag = GameplayTags::Data_Damage_Shield;

	default Modifiers.Add(Modifier);
};

class UGE_Additive_CurrentAmmo : UPondGameplayEffect
{
	default DurationPolicy = EGameplayEffectDurationType::Instant;
	default StackingType = EGameplayEffectStackingType::None;

	FGameplayModifierInfo Modifier;
	default Modifier.Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UPondPlayerGASAttributes, UPondPlayerGASAttributes::AmmoName);
	default Modifier.ModifierOp = EGameplayModOp::Additive;
	default Modifier.ModifierMagnitude.MagnitudeCalculationType = EGameplayEffectMagnitudeCalculation::SetByCaller;
	default Modifier.ModifierMagnitude.SetByCallerMagnitude.DataTag = GameplayTags::Data_Guns_Ammo;

	default Modifiers.Add(Modifier);
};

class UGE_Additive_MaxAmmo : UPondGameplayEffect
{
	default DurationPolicy = EGameplayEffectDurationType::Instant;
	default StackingType = EGameplayEffectStackingType::None;

	FGameplayModifierInfo Modifier;
	default Modifier.Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UPondPlayerGASAttributes, UPondPlayerGASAttributes::MaxAmmoName);
	default Modifier.ModifierOp = EGameplayModOp::Additive;
	default Modifier.ModifierMagnitude.MagnitudeCalculationType = EGameplayEffectMagnitudeCalculation::SetByCaller;
	default Modifier.ModifierMagnitude.SetByCallerMagnitude.DataTag = GameplayTags::Data_Guns_MaxAmmo;

	default Modifiers.Add(Modifier);
};

class UGE_Override_CurrentAmmo : UPondGameplayEffect
{
	default DurationPolicy = EGameplayEffectDurationType::Instant;
	default StackingType = EGameplayEffectStackingType::None;

	FGameplayModifierInfo Modifier;
	default Modifier.Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UPondPlayerGASAttributes, UPondPlayerGASAttributes::AmmoName);
	default Modifier.ModifierOp = EGameplayModOp::Override;
	default Modifier.ModifierMagnitude.MagnitudeCalculationType = EGameplayEffectMagnitudeCalculation::SetByCaller;
	default Modifier.ModifierMagnitude.SetByCallerMagnitude.DataTag = GameplayTags::Data_Guns_Ammo;

	default Modifiers.Add(Modifier);
};

class UGE_Override_MaxAmmo : UPondGameplayEffect
{
	default DurationPolicy = EGameplayEffectDurationType::Instant;
	default StackingType = EGameplayEffectStackingType::None;

	FGameplayModifierInfo Modifier;
	default Modifier.Attribute = UAngelscriptAttributeSet::GetGameplayAttribute(UPondPlayerGASAttributes, UPondPlayerGASAttributes::MaxAmmoName);
	default Modifier.ModifierOp = EGameplayModOp::Override;
	default Modifier.ModifierMagnitude.MagnitudeCalculationType = EGameplayEffectMagnitudeCalculation::SetByCaller;
	default Modifier.ModifierMagnitude.SetByCallerMagnitude.DataTag = GameplayTags::Data_Guns_MaxAmmo;

	default Modifiers.Add(Modifier);
};
