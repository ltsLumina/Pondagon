event void FOnShieldDepleted();
event void FOnKillEvent(FDeathInfo DeathInfo);
event void FOnDeathEvent(FDeathInfo DeathInfo);

struct FDeathInfo
{
	UPROPERTY(BlueprintReadOnly)
	APondCharacter Attacker;

	/**
	 * May be null.
	 */
	UPROPERTY(BlueprintReadOnly)
	UWeaponInstance WeaponUsed;

	/**
	 * May be null.
	 */
	UPROPERTY(BlueprintReadOnly)
	UPondAbility AbilityUsed;

	FDeathInfo(APondCharacter InAttacker, UWeaponInstance InWeaponUsed = nullptr, UPondAbility InAbilityUsed = nullptr)
	{
		Attacker = InAttacker;
		WeaponUsed = InWeaponUsed;
		AbilityUsed = InAbilityUsed;
	}
}

UCLASS(Abstract)
class APondCharacter : ACharacter
{
	/**
	 * The avatar icon for the character.
	 */
	UPROPERTY(Category = "Hero | Info", VisibleAnywhere)
	UTexture2D Avatar;

	UPROPERTY(Category = "Hero | Health", VisibleAnywhere)
	FDeathInfo DeathInfo;

	UPROPERTY()
	FGameplayTagContainer GameplayTags;

	UPROPERTY(Category = "Events")
	FOnShieldDepleted OnShieldDepleted;

	UFUNCTION(Category = "Enemy | Health", BlueprintPure)
	protected float GetHealthAttribute() property
	{
		return -1;
	}

	UFUNCTION(Category = "Enemy | Shield", BlueprintPure)
	protected float GetShieldAttribute() property
	{
		return -1;
	}

	// Events

	UPROPERTY(Category = "Hero | Events", VisibleAnywhere)
	FOnDeathEvent OnDeath;

	UFUNCTION(BlueprintOverride, Category = "Hero | Damage")
	void PointDamage(float Damage, const UDamageType DamageType, FVector HitLocation, FVector HitNormal,
					 UPrimitiveComponent HitComponent, FName BoneName, FVector ShotFromDirection,
					 AController InstigatedBy, AActor DamageCauser, FHitResult HitInfo)
	{
		DeathInfo.Attacker = Cast<APondCharacter>(InstigatedBy.ControlledPawn);
		DeathInfo.WeaponUsed = UGunComponent::Get(DamageCauser).CurrentGun;
		DeathInfo.AbilityUsed = Cast<UPondAbility>(DamageCauser);

		ApplyDamage(Damage);
	}

	// - Abstract Functions
	UFUNCTION(Category = "Hero | Damage")
	protected void ApplyDamage(float Damage)
	{}

	UFUNCTION(Category = "Hero | Health")
	protected void ApplyHealing(float HealAmount)
	{}

	UFUNCTION(Category = "Hero | Shield")
	protected void ApplyShield(float NewAmount)
	{}

	UFUNCTION(Category = "Hero | Health")
	protected void Death()
	{}

	/**
	 * Calculates how incoming damage is split between health and Shield.
	 * @param Damage The total incoming damage.
	 * @param DamageToHealth Output parameter for damage applied to health.
	 * @param DamageToShield Output parameter for damage applied to Shield.
	 */
	UFUNCTION(Category = "Hero | Damage")
	protected void CalculateDamageTaken(float CurrentHealth, float CurrentShield, float Damage, float&out DamageToHealth, float&out DamageToShield)
	{
		float CurrHealth = CurrentHealth;
		float CurrShield = CurrentShield;

		// initialize returned damage values
		DamageToHealth = 0;
		DamageToShield = 0;

		const float ABSORPTION_RATIO = 0.66f;

		const float HealthRatio = 1 - ABSORPTION_RATIO;

		if (CurrShield > 0)
		{
			// How much Shield (in incoming-damage units) is needed to absorb full damage
			float ShieldNeeded = Damage * ABSORPTION_RATIO;

			if (CurrShield >= ShieldNeeded) // Shield can fully absorb, no break
			{
				// Shield absorbed ShieldNeeded (portion of incoming damage)
				DamageToShield = ShieldNeeded;
				// health takes the remaining portion
				DamageToHealth = Damage * HealthRatio;

				CurrShield -= ShieldNeeded;
				CurrHealth -= DamageToHealth;
			}
			else // Shield breaks mid-hit
			{
				// amount of incoming damage that was absorbed by Shield
				float AbsorbedDamage = CurrShield / ABSORPTION_RATIO;
				// remaining incoming damage that goes straight to health
				float RemainingDamage = Damage - AbsorbedDamage;

				// health takes a portion from the absorbed damage plus the remaining damage
				float HealthFromAbsorbed = AbsorbedDamage * HealthRatio;
				DamageToHealth = HealthFromAbsorbed + RemainingDamage;
				// damage portion attributed to Shield (incoming-damage units)
				DamageToShield = AbsorbedDamage;

				// clamp to max value
				DamageToShield = Math::Min(DamageToShield, 100);

				CurrHealth -= DamageToHealth;
				CurrShield = 0;
			}
		}
		else
		{
			// no Shield: all damage goes to health
			DamageToShield = 0;
			DamageToHealth = Damage;

			CurrHealth -= Damage;
		}
	}
}

namespace Pond
{
	UFUNCTION(BlueprintPure)
	APondCharacter GetPondCharacterBase(AActor Actor)
	{
		return Cast<APondCharacter>(Actor);
	}
}