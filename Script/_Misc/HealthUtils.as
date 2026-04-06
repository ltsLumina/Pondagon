/**
 * Set of static utility functions to easily apply damage, healing, and shielding through angelscript.
 */
namespace HealthUtils
{/*
	void ApplyDamage(UAngelscriptAbilitySystemComponent AbilitySystem, float Damage, float InCurrentHealth, float InCurrentShield)
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
*/

	/**
	 * Calculates how incoming damage is split between health and armor.
	 * @param Damage The total incoming damage.
	 * @param DamageToHealth Output parameter for damage applied to health.
	 * @param DamageToArmor Output parameter for damage applied to armor.
	 * @return bShouldKill - Returns true if the DamageToHealth >= InCurrentHealth.
	 * @note Although the function returns if the result *should kill*, it doesn't necessarilly mean it **will**. Use return value with caution.
	 */
	UFUNCTION(Category = "Agent | Damage")
	bool CalculateDamageTaken(float Damage, float InCurrentHealth, float InCurrentShield, float&out DamageToHealth, float&out DamageToShield, float AbsorptionRatio = 0.66f)
	{
		float CurrHealth = InCurrentHealth;
		float CurrShield = InCurrentShield;

		// initialize returned damage values
		DamageToHealth = 0;
		DamageToShield = 0;

		const float HealthRatio = 1 - AbsorptionRatio;

		if (CurrShield > 0)
		{
			// How much armor (in incoming-damage units) is needed to absorb full damage
			float ArmorNeeded = Damage * AbsorptionRatio;

			if (CurrShield >= ArmorNeeded) // armor can fully absorb, no break
			{
				// armor absorbed ArmorNeeded (portion of incoming damage)
				DamageToShield = ArmorNeeded;
				// health takes the remaining portion
				DamageToHealth = Damage * HealthRatio;

				CurrShield -= ArmorNeeded;
				CurrHealth -= DamageToHealth;
			}
			else // armor breaks mid-hit
			{
				// amount of incoming damage that was absorbed by armor
				float AbsorbedDamage = CurrShield / AbsorptionRatio;
				// remaining incoming damage that goes straight to health
				float RemainingDamage = Damage - AbsorbedDamage;

				// health takes a portion from the absorbed damage plus the remaining damage
				float HealthFromAbsorbed = AbsorbedDamage * HealthRatio;
				DamageToHealth = HealthFromAbsorbed + RemainingDamage;
				// damage portion attributed to armor (incoming-damage units)
				DamageToShield = AbsorbedDamage;

				// clamp to max value
				DamageToShield = Math::Min(DamageToShield, 999);

				CurrHealth -= DamageToHealth;
				CurrShield = 0;
			}
		}
		else
		{
			// no armor: all damage goes to health
			DamageToShield = 0;
			DamageToHealth = Damage;

			CurrHealth -= Damage;
		}

		return DamageToHealth >= InCurrentHealth;
	}
}