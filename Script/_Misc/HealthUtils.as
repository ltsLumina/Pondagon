/**
 * Set of static utility functions to easily apply damage, healing, and shielding through angelscript.
 */
namespace HealthUtils
{
	UFUNCTION(Category = "Health Utils")
	float GetCurrentHealth(UAngelscriptAbilitySystemComponent AbilitySystem)
	{
		auto CurrentHealth = AbilitySystem.GetAttributeCurrentValue(UPlayerAttributes, UPlayerAttributes::HealthName, -1.0f);
		if (CurrentHealth <= -1.0f)
		{
			PrintWarning("Invalid Attribute! - Could not find a health attribute on this AbilitySystem!");
			return -1;
		}
		return CurrentHealth;
	}

	UFUNCTION(Category = "Health Utils")
	float GetBaseHealth(UAngelscriptAbilitySystemComponent AbilitySystem)
	{
		auto BaseHealth = AbilitySystem.GetAttributeBaseValue(UPlayerAttributes, UPlayerAttributes::HealthName, -1.0f);
		if (BaseHealth <= -1.0f)
		{
			PrintWarning("Invalid Attribute! - Could not find a health attribute on this AbilitySystem!");
			return -1;
		}
		return BaseHealth;
	}

	void ApplyDamage(UAngelscriptAbilitySystemComponent AbilitySystem, float InCurrentHealth, float InCurrentShield, float Damage)
	{
		float DamageToHealth;
		float DamageToShield;
		HealthUtils::CalculateDamageTaken(Damage, InCurrentHealth, InCurrentShield, DamageToHealth, DamageToShield);

		FGameplayEffectSpecHandle HealthHandle = AbilitySystem.MakeOutgoingSpec(UGE_Damage_Health, 1, FGameplayEffectContextHandle());
		if (HealthHandle.IsValid())
		{
			HealthHandle.Spec.SetByCallerMagnitude(GameplayTags::Data_Damage_Health, -DamageToHealth);
			AbilitySystem.ApplyGameplayEffectSpecToSelf(HealthHandle);

#if EDITOR
			Print(f"Applied {Math::RoundToInt(DamageToHealth)} HEALTH damage to {AbilitySystem.Avatar.ActorNameOrLabel}", 3.0f, FLinearColor::DPink);
#endif
		}

		FGameplayEffectSpecHandle ShieldHandle = AbilitySystem.MakeOutgoingSpec(UGE_Damage_Shield, 1, FGameplayEffectContextHandle());
		if (ShieldHandle.IsValid())
		{
			ShieldHandle.Spec.SetByCallerMagnitude(GameplayTags::Data_Damage_Shield, -DamageToShield);
			AbilitySystem.ApplyGameplayEffectSpecToSelf(ShieldHandle);

#if EDITOR
			Print(f"Applied {Math::RoundToInt(DamageToShield)} Shield damage to {AbilitySystem.Avatar.ActorNameOrLabel}", 3.0f, FLinearColor::Teal);
#endif
		}
	}

	void ApplyHealing(UAngelscriptAbilitySystemComponent AbilitySystem, float HealAmount)
	{
		FGameplayEffectSpecHandle HealHandle = AbilitySystem.MakeOutgoingSpec(UGE_Restore_Health, 1, FGameplayEffectContextHandle());
		if (HealHandle.IsValid())
		{
			HealHandle.Spec.SetByCallerMagnitude(GameplayTags::Data_Damage_Health, HealAmount);
			AbilitySystem.ApplyGameplayEffectSpecToSelf(HealHandle);

#if EDITOR
			Print(f"Applied {HealAmount} health healing to {AbilitySystem.Avatar.ActorNameOrLabel}", 3.0f, FLinearColor::Green);
#endif
		}
	}

void ApplyShield(UAngelscriptAbilitySystemComponent AbilitySystem, float ShieldAmount) override
	{
		FGameplayEffectSpecHandle ShieldHandle = AbilitySystem.MakeOutgoingSpec(UGE_Override_Shield, 1, FGameplayEffectContextHandle());
		if (ShieldHandle.IsValid())
		{
			ShieldHandle.Spec.SetByCallerMagnitude(GameplayTags::Data_Damage_Shield, ShieldAmount);
			AbilitySystem.ApplyGameplayEffectSpecToSelf(ShieldHandle);

#if EDITOR
			Print(f"Applied {ShieldAmount} Shield to {AbilitySystem.Avatar.ActorNameOrLabel}", 3.0f, FLinearColor::LucBlue);
#endif
		}
	}

	/**
	 * Calculates how incoming damage is split between health and armor.
	 * @param Damage The total incoming damage.
	 * @param DamageToHealth Output parameter for damage applied to health.
	 * @param DamageToArmor Output parameter for damage applied to armor.
	 */
	UFUNCTION(Category = "Agent | Damage")
	void CalculateDamageTaken(float Damage, float InCurrentHealth, float InCurrentShield, float&out DamageToHealth, float&out DamageToArmor)
	{
		const float ABSORPTION_RATIO = 0.66f;

		float CurrHealth = InCurrentHealth;
		float CurrArmor = InCurrentShield;

		// initialize returned damage values
		DamageToHealth = 0;
		DamageToArmor = 0;

		const float HealthRatio = 1 - ABSORPTION_RATIO;

		if (CurrArmor > 0)
		{
			// How much armor (in incoming-damage units) is needed to absorb full damage
			float ArmorNeeded = Damage * ABSORPTION_RATIO;

			if (CurrArmor >= ArmorNeeded) // armor can fully absorb, no break
			{
				// armor absorbed ArmorNeeded (portion of incoming damage)
				DamageToArmor = ArmorNeeded;
				// health takes the remaining portion
				DamageToHealth = Damage * HealthRatio;

				CurrArmor -= ArmorNeeded;
				CurrHealth -= DamageToHealth;
			}
			else // armor breaks mid-hit
			{
				// amount of incoming damage that was absorbed by armor
				float AbsorbedDamage = CurrArmor / ABSORPTION_RATIO;
				// remaining incoming damage that goes straight to health
				float RemainingDamage = Damage - AbsorbedDamage;

				// health takes a portion from the absorbed damage plus the remaining damage
				float HealthFromAbsorbed = AbsorbedDamage * HealthRatio;
				DamageToHealth = HealthFromAbsorbed + RemainingDamage;
				// damage portion attributed to armor (incoming-damage units)
				DamageToArmor = AbsorbedDamage;

				// clamp to max value
				DamageToArmor = Math::Min(DamageToArmor, 999);

				CurrHealth -= DamageToHealth;
				CurrArmor = 0;
			}
		}
		else
		{
			// no armor: all damage goes to health
			DamageToArmor = 0;
			DamageToHealth = Damage;

			CurrHealth -= Damage;
		}
	}
}