enum EEquipSpeed
{
	Normal,
	Fast,
	Instant
}

UCLASS(Meta = (PrioritizeCategories = "Gun | GAS"))
class UWeaponDefinition : UPrimaryDataAsset
{
	UPROPERTY(Category = "Definition", EditDefaultsOnly, BlueprintReadOnly)
	UItemDefinition ItemDefinition;

	UPROPERTY(Category = "Gun | Stats", EditDefaultsOnly, BlueprintReadOnly)
	FWeaponStats Stats;

	// - movement
	UPROPERTY(Category = "Gun | Movement", EditDefaultsOnly, BlueprintReadOnly, Meta = (ClampMin = "0.1", UIMin = "0.1", UIMax = "6.75", Units = "m/s"))
	float RunSpeed = 5.4f;

	UPROPERTY(Category = "Gun | Movement", VisibleAnywhere, BlueprintReadOnly, BlueprintGetter = "GetWalkSpeed", Meta = (Units = "m/s"))
	float WalkSpeed;
	default WalkSpeed = RunSpeed * WalkSpeedRatio;

	UPROPERTY(Category = "Gun | Movement", VisibleAnywhere, BlueprintReadOnly, BlueprintGetter = "GetCrouchSpeed", Meta = (Units = "m/s"))
	float CrouchSpeed;
	default CrouchSpeed = RunSpeed * CrouchSpeedRatio;

	UPROPERTY(Category = "Gun | Movement", EditDefaultsOnly, BlueprintReadOnly, Meta = (ClampMin = "0.1", UIMin = "0.1", UIMax = "1", Units = ("x")))
	float WalkSpeedRatio = 0.80f;

	UPROPERTY(Category = "Gun | Movement", EditDefaultsOnly, BlueprintReadOnly, Meta = (ClampMin = "0.1", UIMin = "0.1", UIMax = "1", Units = ("x")))
	float CrouchSpeedRatio = 0.40f;

	// - movement helpers

	UFUNCTION(BlueprintPure, Category = "Gun | Movement")
	float GetMovementSpeed(EPondMovementState State, bool IsAltMode)
	{
		switch (State)
		{
			case EPondMovementState::Still:
			case EPondMovementState::Run:
				return RunSpeed * (IsAltMode ? AltMoveSpeedRatio : 1.0f);

			case EPondMovementState::Walk:
				return GetWalkSpeed() * (IsAltMode ? AltMoveSpeedRatio : 1.0f);

			case EPondMovementState::Crouch:
			case EPondMovementState::CrouchWalk:
				return GetCrouchSpeed() * (IsAltMode ? AltMoveSpeedRatio : 1.0f);

			default:
				return RunSpeed;
		}
	}

	UFUNCTION(BlueprintPure, Category = "Gun | Movement")
	float GetWalkSpeed()
	{
		return RunSpeed * WalkSpeedRatio;
	}

	UFUNCTION(BlueprintPure, Category = "Gun | Movement")
	float GetCrouchSpeed()
	{
		return RunSpeed * CrouchSpeedRatio;
	}

	// - equip
	UPROPERTY(Category = "Gun | Equip", EditDefaultsOnly, BlueprintReadOnly, Meta = (Units = "Seconds"))
	TMap<EEquipSpeed, float> EquipTimes;
	default EquipTimes.Add(EEquipSpeed::Normal, 1.0f);
	default EquipTimes.Add(EEquipSpeed::Fast, 0.6f);
	default EquipTimes.Add(EEquipSpeed::Instant, 0.2f);

	// - equip helpers

	UFUNCTION(BlueprintPure, Category = "Gun | Equip")
	float GetEquipTime(EEquipSpeed Speed)
	{
		return EquipTimes[Speed];
	}

	// - shooting

	UPROPERTY(Category = "Gun | Shooting", EditDefaultsOnly)
	EFireMode FireMode = EFireMode::Auto;

	/**
	 * The attribute set that contains all attributes for this gun specifically.
	 * For example, the Six Shooter gun uses the USixShooterAttributes attribute set.
	 * @note Do not input the generic attributes here. That set is automatically added by default.
	 */
	UPROPERTY(Category = "Gun | GAS", EditDefaultsOnly, BlueprintReadOnly)
	TSubclassOf<UAngelscriptAttributeSet> AttributeSet;

	UPROPERTY(Category = "Gun | GAS", EditDefaultsOnly, BlueprintReadOnly)
	UDataTable AttributeSetDefaultStartingData;

	/**
	 * The GameplayEffect that gets invoked when the gun is fired.
	 * @note MUST UPDATE AMMO!
	 */
	UPROPERTY(Category = "Gun | GAS", EditDefaultsOnly, BlueprintReadOnly)
	TSubclassOf<UGameplayAbility> FireGameplayAbility;

	UPROPERTY(Category = "Gun | GAS", EditDefaultsOnly, BlueprintReadOnly)
	TSubclassOf<UGameplayAbility> ReloadGameplayAbility;

	// - Accuracy

	/**
	 * The number of bullets that are guaranteed to be perfectly accurate (no spread).
	 */
	UPROPERTY(Category = "Gun | Accuracy | Bullets", EditDefaultsOnly, Meta = (UIMin = "0", ClampMax = "30", UIMax = "30"))
	int ProtectedBullets;

	/**
	 * The number of bullets after which the spread reaches its maximum value.
	 */
	UPROPERTY(Category = "Gun | Accuracy | Bullets", EditDefaultsOnly, BlueprintReadOnly, Meta = (ClampMin = "1", UIMin = "1", ClampMax = "30", UIMax = "30"))
	int MaxSpreadBullet = 6;

	/**
	 * Curve for the rate of change (delta) in spread intensity.
	 * Easing early results in less spread at the start of the spread, and vice versa toward the end.
	 * Reaches the maximum spread by 'MaxSpreadBullet'.
	 */
	UPROPERTY(Category = "Gun | Accuracy | Spread", EditDefaultsOnly, Meta = (DisplayThumbnail = true))
	UCurveFloat SpreadCurve;
	UPROPERTY(Category = "Gun | Accuracy | 1st Shot Spread", EditDefaultsOnly, Meta = (Units = "Degrees"))
	float StandingSpread = 0.25f;
	UPROPERTY(Category = "Gun | Accuracy | 1st Shot Spread", EditDefaultsOnly, Meta = (Units = "Degrees"))
	float CrouchSpread = 0.21f;

	UPROPERTY(Category = "Gun | Accuracy | Max Spread", EditDefaultsOnly, Meta = (Units = "Degrees"))
	float StandingMaxSpread = 1.0f;
	UPROPERTY(Category = "Gun | Accuracy | Max Spread", EditDefaultsOnly, Meta = (Units = "Degrees"))
	float CrouchMaxSpread = 0.85f;

	UPROPERTY(Category = "Gun | Accuracy | Penalties", EditDefaultsOnly, Meta = (Units = "Degrees"))
	float AirbornePenalty = 10;
	UPROPERTY(Category = "Gun | Accuracy | Penalties", EditDefaultsOnly, Meta = (Units = "Degrees"))
	float RunPenalty = 6;
	UPROPERTY(Category = "Gun | Accuracy | Penalties", EditDefaultsOnly, Meta = (Units = "Degrees"))
	float WalkPenalty = 3;
	UPROPERTY(Category = "Gun | Accuracy | Penalties", EditDefaultsOnly, Meta = (Units = "Degrees"))
	float CrouchPenalty = 1.5f;

	// - recoil

	UPROPERTY(Category = "Gun | Recoil", EditDefaultsOnly, Meta = (ClampMin = "1.0", UIMin = "1.0", ClampMax = "3.0", UIMax = "3.0"))
	float VerticalRecoilRunningMultiplier = 2.0f;

	float Zoom = 1.25;

	/**
	 * The fire rate when using alternate fire mode, in rounds per second.
	 */
	float AltFireRate;
	default AltFireRate = Stats.Advanced.FireRate * 0.9f;

	float AltMoveSpeedRatio = 0.76f;

	// - reload

	UPROPERTY(Category = "Gun | Reload | Magazine", Instanced)
	UReloadStrategyBase ReloadStrategy;

	// - audio

	UPROPERTY(Category = "Gun | Audio | Weapon Sounds", EditDefaultsOnly)
	USoundCue ShootSound;

	UPROPERTY(Category = "Gun | Audio | Weapon Sounds", EditDefaultsOnly)
	USoundWave DryFireSound;

	UPROPERTY(Category = "Gun | Audio | Weapon Sounds", EditDefaultsOnly, ToolTip = "Map of equip sounds. Key is the sound, value is the equip speed (Normal, Fast, Instant).")
	TMap<USoundWave, EEquipSpeed> EquipSounds;

	UPROPERTY(Category = "Gun | Audio | Weapon Sounds", EditDefaultsOnly, ToolTip = "Map of reload sounds. Key is the sound, value is whether it is for an empty magazine (true) or not (false).")
	USoundBase ReloadSound;

	/**
	 * Returns the appropriate equip sound based on the equip speed.
	 */
	UFUNCTION(BlueprintPure)
	USoundWave GetEquipSound(EEquipSpeed Speed)
	{
		// Try to find exact match first
		for (auto& Elem : EquipSounds)
		{
			if (Elem.Value == Speed)
				return Elem.Key;
		}

		// Fallback order: Fast, then Normal
		if (Speed == EEquipSpeed::Instant)
		{
			for (auto& Elem : EquipSounds)
			{
				if (Elem.Value == EEquipSpeed::Fast)
					return Elem.Key;
			}
		}
		// Always fallback to Normal if nothing else
		for (auto& Elem : EquipSounds)
		{
			if (Elem.Value == EEquipSpeed::Normal)
				return Elem.Key;
		}

		return nullptr;
	}

	// - hit sounds

	UPROPERTY(Category = "Gun | Audio | Headshots", EditDefaultsOnly)
	USoundWave HeadshotSound;

	UPROPERTY(Category = "Gun | Audio | Headshots", EditDefaultsOnly)
	USoundWave HeadshotWithArmorSound;

	UPROPERTY(Category = "Gun | Audio | Headshots", EditDefaultsOnly)
	USoundWave HeadshotBrokeArmorSound;

	UPROPERTY(Category = "Gun | Audio | Body", EditDefaultsOnly)
	USoundCue BodyshotSound;

	UPROPERTY(Category = "Gun | Audio | Ground", EditDefaultsOnly)
	USoundWave GroundHitSound;

	UPROPERTY(Category = "Gun | Audio | Multikill", EditDefaultsOnly)
	TArray<USoundWave> MultikillSounds;

	UPROPERTY(Category = "Gun | Audio | Multikill", EditDefaultsOnly)
	USoundWave MultikillAceSound;

	UPROPERTY(Category = "Gun | Audio | Attenuation", EditDefaultsOnly)
	USoundAttenuation DefaultAttenuation;

	// - visual
	UPROPERTY(Category = "Gun | Visual | Decals", EditDefaultsOnly)
	UMaterialInterface BulletHitDecal;

	UPROPERTY(Category = "Gun | Visual | Decals", EditDefaultsOnly)
	UMaterialInterface BulletPenetrationDecal;

	// Helper Functions
	UFUNCTION(BlueprintPure)
	FText GetDisplayName() const
	{
		return ItemDefinition.DisplayName;
	}

	UFUNCTION(BlueprintPure)
	float GetDamage() const
	{
		return Stats.Advanced.Damage;
	}
	//~Helper Functions
}

struct FBulletSpreadData
{
	float ConeWidth;
	float ConeHeight;
	float ErrorAngle;
	bool IsAccurate;
}

struct FWeaponStats
{
	UPROPERTY()
	FWeaponCoreStats Core;

	UPROPERTY()
	FWeaponAdvancedStats Advanced;

	UPROPERTY()
	FWeaponHandling Handling;
}

struct FWeaponCoreStats
{
	UPROPERTY(BlueprintReadOnly, VisibleAnywhere)
	float Firepower = 20.7f;

	UPROPERTY(BlueprintReadOnly, VisibleAnywhere)
	float Accuracy = 61.2f;

	UPROPERTY(BlueprintReadOnly, VisibleAnywhere)
	float Handling = 41.0f;

	UPROPERTY(BlueprintReadOnly, Meta = (Units = "m"))
	float Range = 48.0f;

	UPROPERTY(BlueprintReadOnly)
	int Magazine = 27;

	UPROPERTY(BlueprintReadOnly, Meta = (Units = "%"))
	float Zoom = 1.4f;
}

struct FWeaponAdvancedStats
{
	/**
	 * The fire rate of the gun, in rounds per second.
	 * This is used to calculate the shoot cooldown.
	 */
	UPROPERTY(BlueprintReadOnly, DisplayName = "Rate of Fire (RPM)", Meta = (UIMin = "0.1", UIMax = "900.0", ClampMin = "0.1", ClampMax = "900"))
	float FireRate = 900;

	UPROPERTY(BlueprintReadOnly, Meta = (Units = "s"))
	float ReloadSpeed = 3;

	UPROPERTY(BlueprintReadOnly, DisplayName = "Aim Assist", Meta = (Units = "degrees"))
	float BulletMagnetization = 1.61f;

	UPROPERTY(BlueprintReadOnly, Meta = (Units = "%"))
	float Recoil = 87.3f;

	UPROPERTY(BlueprintReadOnly, Meta = (Units = "x"))
	float Precision = 1.4f;

	UPROPERTY(BlueprintReadOnly)
	float Damage = 14.8f;

	UPROPERTY(BlueprintReadOnly, Meta = (Units = "%"))
	float Weight = 28.0f;
}

struct FWeaponHandling
{
	UPROPERTY(Meta = (Units = "degrees"))
	float HipfireSpread = 2.2f;

	UPROPERTY(DisplayName = "ADS Spread", Meta = (Units = "degrees"))
	float AimDownSightSpread = 0.96f;

	UPROPERTY(Meta = (Units = "%"))
	float CrouchSpread = 80.0f;

	UPROPERTY(Meta = (Units = "%"))
	float MovingInaccuracy = 16.4f;

	UPROPERTY(Meta = (Units = "s"))
	float EquipSpeed = 0.94f;

	UPROPERTY(DisplayName = "ADS Speed", Meta = (Units = "s"))
	float AimDownSightSpeed = 0.4f;
}

UFUNCTION(BlueprintPure)
mixin float GetFireRate(FWeaponStats Stats)
{
	return Stats.Advanced.FireRate;
}

UFUNCTION(BlueprintPure)
mixin float GetReloadSpeed(FWeaponStats Stats)
{
	return Stats.Advanced.ReloadSpeed;
}

UFUNCTION(BlueprintPure)
mixin float GetBulletMagnetization(FWeaponStats Stats)
{
	return Stats.Advanced.BulletMagnetization;
}

UFUNCTION(BlueprintPure)
mixin float GetRecoil(FWeaponStats Stats)
{
	return Stats.Advanced.Recoil;
}

UFUNCTION(BlueprintPure)
mixin float GetPrecision(FWeaponStats Stats)
{
	return Stats.Advanced.Precision;
}

UFUNCTION(BlueprintPure)
mixin float GetDamage(FWeaponStats Stats)
{
	return Stats.Advanced.Damage;
}

UFUNCTION(BlueprintPure)
mixin float GetWeight(FWeaponStats Stats)
{
	return Stats.Advanced.Weight;
}
