event void FOnFire(FBulletHit Hit);
event void FOnHit(FBulletHit Hit);
event void FOnKill(FBulletHit Hit);
event void FOnPrecisionHit(FBulletHit Hit);
event void FOnPrecisionKill(FBulletHit Hit);
event void FOnLastBullet(FMagazineState State);
event void FOnReload(FMagazineState State);
event void FOnMagazineEmpty(FMagazineState State);

enum EFireMode
{
	Semi,
	Burst,
	Auto
}

struct FBulletHit
{
	UPROPERTY(BlueprintReadOnly)
	AController Instigator;

	UPROPERTY(BlueprintReadOnly)
	APondCharacter HitCharacter;

	UPROPERTY(BlueprintReadOnly)
	bool WasHeroHit;

	UPROPERTY(BlueprintReadOnly)
	float Damage;

	UPROPERTY(BlueprintReadOnly)
	bool IsShieldBreak; // only when player affected

	UPROPERTY(BlueprintReadOnly)
	bool IsPrecisionHit;

	UPROPERTY(BlueprintReadOnly)
	bool IsKill;

	UPROPERTY(BlueprintReadOnly)
	FHitResult Hit;

	FBulletHit(AController InInstigator, APondCharacter InHitCharacter, bool InWasHeroHit, float InDamage, bool InIsShieldBreak, bool InIsPrecisionKill, bool InIsKill, FHitResult InHitResult)
	{
		Instigator = InInstigator;
		HitCharacter = InHitCharacter;
		WasHeroHit = InWasHeroHit;
		Damage = InDamage;
		IsShieldBreak = InIsShieldBreak;
		IsPrecisionHit = InIsPrecisionKill;
		IsKill = InIsKill;
		Hit = InHitResult;
	}
};

//#region Mixin
UFUNCTION(BlueprintPure, Meta = (ReturnDisplayName = "Hit Result"))
mixin FHitResult GetHitResult(FBulletHit BulletHit)
{
	return BulletHit.Hit;
}
//#endregion

struct FMagazineState
{
	UPROPERTY(BlueprintReadOnly)
	int CurrentAmmo;

	UPROPERTY(BlueprintReadOnly)
	int MaxAmmo;

	UPROPERTY(BlueprintReadOnly)
	bool IsEmpty;

	FMagazineState(int InCurrentAmmo, int InMaxAmmo, bool InIsEmpty)
	{
		CurrentAmmo = InCurrentAmmo;
		MaxAmmo = InMaxAmmo;
		IsEmpty = InIsEmpty;
	}
}

class UGunComponent : UActorComponent
{
	UPROPERTY(Category = "Gun", EditDefaultsOnly)
	UWeaponDefinition DefaultGun;

	UPROPERTY(Category = "Gun", VisibleInstanceOnly)
	UWeaponInstance CurrentGun;

	UFUNCTION(BlueprintPure)
	UWeaponDefinition GetWeaponDefinition() property
	{
		return CurrentGun.WeaponDefinition;
	}

	UPROPERTY(NotVisible, BlueprintReadOnly)
	APondHero OwningHero;

	UPROPERTY(Category = "Gun | Scope", VisibleInstanceOnly)
	bool IsScoped;

	UPROPERTY(NotEditable, BlueprintReadOnly)
	UPondPlayerGASAttributes PlayerAttributes;

	UFUNCTION(Category = "Gun | Ammo", BlueprintPure)
	int GetAmmoAttribute() property
	{
		return int(PlayerAttributes.Ammo.CurrentValue);
	}

	UFUNCTION(Category = "Gun | Ammo", BlueprintPure)
	int GetMaxAmmoAttribute() property
	{
		return int(PlayerAttributes.MaxAmmo.CurrentValue);
	}

	/**
	 * The rounds per minute (RPM) of the gun, calculated from the fire rate.
	 * This is a derived property and is read-only.
	 */
	UPROPERTY(Category = "Gun | Shooting", VisibleAnywhere, BlueprintReadOnly)
	float RPM;
	// default RPM = WeaponDefinition != nullptr ? WeaponDefinition.FireRate * 60 : 0;

	/**
	 * The cooldown time between shots, in seconds.
	 * This is calculated as the inverse of the fire rate.
	 */
	UPROPERTY(Category = "Gun | Shooting", VisibleAnywhere, BlueprintReadOnly, Meta = (Units = "Seconds"))
	float ShootCooldown = 0.1f;
	// default ShootCooldown = WeaponDefinition != nullptr ? (1.0 / WeaponDefinition.FireRate) : -1;

	/**
	 * The time elapsed since the last shot was fired, in seconds.
	 */
	UPROPERTY(Category = "Gun | Shooting", VisibleInstanceOnly, BlueprintReadOnly, Meta = (Units = "Seconds"))
	float TimeSinceLastShot = 0.0f;

	// - shooting helpers

	// Whether the gun is ready to fire. This is set to true when the gun is ready to shoot, and false when it has no ammo or is jammed.
	UPROPERTY(Category = "Gun | Shooting", VisibleInstanceOnly, BlueprintReadOnly, BlueprintGetter = "GetIsReady")
	protected bool IsReady;

	UFUNCTION(Category = "Gun | Shooting", BlueprintPure)
	bool GetIsReady()
	{
		return WeaponDefinition.ReloadStrategy.GunState == EGunState::Ready;
	}

	UPROPERTY(Category = "Gun | Shooting", VisibleInstanceOnly, BlueprintReadOnly, BlueprintGetter = "GetIsFiring")
	protected bool IsFiring;

	UFUNCTION(Category = "Gun | Shooting", BlueprintPure)
	bool GetIsFiring()
	{
		return TriggeredTime > ShootCooldown;
	}

	UPROPERTY(Category = "Gun | Shooting", VisibleInstanceOnly, BlueprintReadOnly, BlueprintGetter = "GetIsOnShootCooldown")
	bool IsOnShootCooldown;

	UFUNCTION(Category = "Gun | Shooting", BlueprintPure)
	bool GetIsOnShootCooldown()
	{
		return TimeSinceLastShot < ShootCooldown;
	}

	/**
	 * Whether the first shot after a pause is perfectly accurate (no recoil).
	 */
	UPROPERTY(Category = "Gun | Shooting", VisibleInstanceOnly, BlueprintReadOnly, BlueprintGetter = "GetIsFirstShotAccurate")
	protected bool IsFirstShotAccurate;

	UFUNCTION(Category = "Gun | Shooting", BlueprintPure)
	bool GetIsFirstShotAccurate()
	{
		return TimeSinceLastShot > 1.0 && RecoilIndex == 0;
	}

	/**
	 * The current index in the recoil pattern. This increments with each shot fired.
	 * It is used to determine the recoil offset applied to the gun.
	 */
	UPROPERTY(Category = "Gun | Recoil", VisibleInstanceOnly, BlueprintReadOnly)
	int RecoilIndex;

	UFUNCTION(BlueprintPure, Category = "Gun | Accuracy")
	bool IsBulletProtected()
	{
		return RecoilIndex <= WeaponDefinition.ProtectedBullets;
	}

	UPROPERTY(Category = "Gun | Accuracy", VisibleInstanceOnly)
	FBulletSpreadData SpreadData;

	// - alt fire

	bool IsAltMode = false;

	UPROPERTY(Category = "State", BlueprintReadOnly)
	FBulletHit BulletHit;

	UPROPERTY(Category = "State", BlueprintReadOnly)
	FMagazineState MagazineState;

	// - Events

	UPROPERTY(Category = "Events")
	FOnFire OnFire;

	UPROPERTY(Category = "Events")
	FOnHit OnHit;

	UPROPERTY(Category = "Events")
	FOnKill OnKill;

	UPROPERTY(Category = "Events")
	FOnPrecisionHit OnPrecisionHit;

	UPROPERTY(Category = "Events")
	FOnPrecisionKill OnPrecisionKill;

	UPROPERTY(Category = "Events")
	FOnLastBullet OnLastBullet;

	UPROPERTY(Category = "Events")
	FOnReload OnReload;

	UPROPERTY(Category = "Events")
	FOnMagazineEmpty OnMagazineEmpty;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		OwningHero = Cast<APondHero>(GetOwner());

		PlayerAttributes = Pond::GetPondPlayerStateBase().Attributes;
		PlayerAttributes.Ammo.Initialize(WeaponDefinition.MagazineSize);
		PlayerAttributes.MaxAmmo.Initialize(WeaponDefinition.MagazineSize);

		ShootCooldown = 1.0 / WeaponDefinition.FireRate;
		RPM = WeaponDefinition.FireRate * 60;

		// GetAngelGameState().OnHeroDeath.AddUFunction(this, n"HeroKilled");

		Ready();
	}

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		TimeSinceLastShot += DeltaSeconds;

		// Assumes player has not fired for a while, reset recoil index
		if (TimeSinceLastShot > ShootCooldown * 2)
			RecoilIndex = 0;

		if (RecoilIndex == 0)
			StopHorizontalRecoil();

		BP_Tick(DeltaSeconds);
	}

	UFUNCTION(BlueprintEvent)
	void StopHorizontalRecoil()
	{}

	UFUNCTION(BlueprintEvent, DisplayName = "Tick")
	void BP_Tick(float DeltaSeconds)
	{}

	UFUNCTION(BlueprintPure, Category = "Gun | Accuracy", Meta = (AdvancedDisplay = "ConeWidth,ConeHeight,ErrorAngle,IsAccurate"))
	FVector ApplySpread(FVector AimDirection, float SpreadDeg, FBulletSpreadData&out OutSpreadData = FBulletSpreadData())
	{
		float SpreadRad = Math::DegreesToRadians(SpreadDeg);

		// Random yaw angle around the aim direction
		float Yaw = Math::RandRange(0.0f, PI * 2.0f);

		// Random radius (sqrt for even distribution)
		float Radius = Math::Sqrt(Math::RandRange(0.0f, 1.0f)) * Math::Tan(SpreadRad);

		float OffsetX = Math::Cos(Yaw) * Radius;
		float OffsetY = Math::Sin(Yaw) * Radius;

		// Build an orthonormal basis around AimDirection
		FVector Right = FVector::UpVector.CrossProduct(AimDirection).GetSafeNormal();
		FVector Up = AimDirection.CrossProduct(Right).GetSafeNormal();

		// Apply spread offset
		FVector FinalDir = (AimDirection + Right * OffsetX + Up * OffsetY).GetSafeNormal();

		OutSpreadData.ConeWidth = Math::Atan2(Math::Abs(OffsetX), 1.0f);
		OutSpreadData.ConeHeight = Math::Atan2(Math::Abs(OffsetY), 1.0f);
		OutSpreadData.ErrorAngle = Math::RadiansToDegrees(Math::Acos(FinalDir.DotProduct(AimDirection)));
		OutSpreadData.IsAccurate = SpreadData.ErrorAngle <= 0.01f;

		return FinalDir;
	}

	FVector TraceStart;
	FVector TraceEnd;

	// for debug only.
	EDrawDebugTrace DebugTrace = EDrawDebugTrace::ForDuration;
	float DebugTraceDuration = 1.0f;

	FVector GetTargetPoint(float MaxDistance = 10000.0f)
	{
		auto CameraManager = Gameplay::GetPlayerCameraManager(0);
		FVector CameraLocation = CameraManager.CameraLocation;
		FVector CameraForward = CameraManager.ActorForwardVector;

		TraceStart = CameraLocation;
		TraceEnd = CameraLocation + CameraForward * MaxDistance;

		FHitResult Hit;
		System::LineTraceSingle(TraceStart, TraceEnd, ETraceTypeQuery::TraceTypeQuery3, false, TArray<AActor>(), DebugTrace, Hit, true, FLinearColor::Red, FLinearColor::Green, DebugTraceDuration);

		FVector TargetPoint = Hit.bBlockingHit ? Hit.Location : TraceEnd;
		return TargetPoint;
	}

	TArray<FHitResult> Hits;
	bool BlockingHit;

	TArray<FHitResult> Trace(float MaxDistance = 10000.0f)
	{
		FVector AimDirection = (GetTargetPoint(MaxDistance) - TraceStart).GetSafeNormal();

		FVector BulletDirection = ApplySpread(AimDirection, CurrentGun.GetSpread(OwningHero.MovementState), SpreadData);

		FVector End = TraceStart + BulletDirection * MaxDistance;

		TArray<AActor> ActorsToIgnore;
		ActorsToIgnore.Add(GetOwner()); // guncomponent is attached to character

		BlockingHit = System::LineTraceMulti(TraceStart,
											 End,
											 ETraceTypeQuery::TraceTypeQuery3,
											 false,
											 ActorsToIgnore,
											 DebugTrace,
											 Hits,
											 true,
											 FLinearColor::Yellow,
											 FLinearColor::Green,
											 DebugTraceDuration);

		if (!BlockingHit)
		{
			Print("Trace did not hit anything!", 2, FLinearColor(1.0, 0.5, 0.0));
			ShootSFX();

			BulletHit = FBulletHit();
			return TArray<FHitResult>();
		}

		FHitResult LastHit = Hits.Last();

		auto Instigator = OwningHero.Controller;
		auto HitCharacter = Cast<APondCharacter>(LastHit.Actor);
		auto WasHeroHit = Cast<APondHero>(LastHit.Actor) != nullptr;
		float Damage = WeaponDefinition.GetDamage();

		BulletHit = FBulletHit();
		BulletHit.Instigator = Instigator;
		BulletHit.HitCharacter = HitCharacter;
		BulletHit.WasHeroHit = WasHeroHit;
		if (HitCharacter != nullptr)
			BulletHit.IsShieldBreak = Pond::GetPondPlayerStateBase().ShieldAttribute - Damage <= 0 && HitCharacter.GameplayTags.HasTag(GameplayTags::Character_State_HasArmor);
		BulletHit.IsPrecisionHit = LastHit.BoneName == n"Weakpoint";
		if (HitCharacter != nullptr)
			BulletHit.IsKill = Pond::GetPondPlayerStateBase().HealthAttribute - Damage <= 0 && !HitCharacter.GameplayTags.HasTag(GameplayTags::Character_State_Dead);
		BulletHit.Damage = Damage;
		BulletHit.Hit = LastHit;

		if (BulletHit.WasHeroHit)
		{
			// Instead of subscribing to each enemy's death, we'll check if they died
			// and broadcast to the global death event in the damage application
		}

		ShootSFX();
		HitSFX();

		bool Penetrated = false;
		CreateImpactDecal(Penetrated);

		if (BulletHit.WasHeroHit)
		{
			float DamageAmount = BulletHit.Damage;

			Gameplay::ApplyPointDamage(
				BulletHit.HitCharacter,
				DamageAmount,
				BulletDirection,
				LastHit,
				OwningHero.Controller,
				OwningHero,
				TSubclassOf<UDamageType>(UDamageType));
		}

		return Hits;
	}

	void ShootSFX()
	{
		if (AmmoAttribute > 0)
			Gameplay::PlaySoundAtLocation(WeaponDefinition.ShootSound, GetOwner().ActorLocation, FRotator::ZeroRotator, 1.0f, 1.0f, 0.0f, WeaponDefinition.DefaultAttenuation);
		// else
		// Gameplay::PlaySoundAtLocation(DryFireSound, GetActorLocation(), FRotator::ZeroRotator, 0.6f, 0.8f, 0.0f, DefaultAttenuation);
	}

	void HitSFX()
	{
		if (BulletHit.WasHeroHit && BulletHit.IsPrecisionHit)
		{ /*
			 if (Cast<AEnemyBase>(BulletHit.HitCharacter).Attributes.ShieldAttribute.CurrentValue > 0)
			 {
				 Gameplay::PlaySound2D(WeaponDefinition.HeadshotWithArmorSound);
			 else
			 }*/
			{
				Gameplay::PlaySound2D(WeaponDefinition.HeadshotSound);
			}
		}
		else if (BulletHit.WasHeroHit && !BulletHit.IsPrecisionHit)
		{
			Gameplay::PlaySound2D(WeaponDefinition.BodyshotSound);
		}
		else if (!BulletHit.WasHeroHit)
		{
			float PitchMultiplier = Math::Clamp(1.0f - (BulletHit.Hit.Distance / 10000.0f), 0.75f, 1.0f); // Closer impacts sound higher pitched
			Gameplay::PlaySoundAtLocation(WeaponDefinition.GroundHitSound, BulletHit.Hit.Location, FRotator::ZeroRotator, 1.0f, PitchMultiplier, 0.0f, WeaponDefinition.DefaultAttenuation);
		}
	}

	void CreateImpactDecal(bool&out Penetrated)
	{
		for (FHitResult Hit : Hits)
		{
			if (Hit.Actor.IsA(APondCharacter) || Hit.Actor.IsA(APondHero))
				continue;

			int i = Hits.FindIndex(Hit);

			if (i < Hits.Num() - 1) // Not the last hit
			{
				Penetrated = true;
			}

			UMaterialInterface DecalMaterial = Penetrated ? WeaponDefinition.BulletPenetrationDecal : WeaponDefinition.BulletHitDecal;
			FRotator DecalRotation = Penetrated ? Pond::GetPondCharacterBase(GetOwner()).ControlRotation : Hit.ImpactNormal.Rotation();

			UDecalComponent Decal = Gameplay::SpawnDecalAtLocation(DecalMaterial, FVector(8.0f, 8.0f, 8.0f), Hit.Location, DecalRotation, 15.0f);
			if (IsValid(Decal))
			{
				Decal.SetFadeScreenSize(0);
				Decal.SetFadeIn(0, 0);
			}
		}
	}

	float ElapsedTime;
	float TriggeredTime;

	UFUNCTION(NotBlueprintCallable)
	private void Interim_Shoot(FInputActionValue ActionValue, float32 InElapsedTime,
					   float32 InTriggeredTime, const UInputAction SourceAction)
	{
		this.ElapsedTime = InElapsedTime;
		this.TriggeredTime = InTriggeredTime;
		Shoot();
	}

	/**
	 * CALLED ON THE SERVER
	 */
	UFUNCTION(Category = "Gun", Server)
	bool Shoot()
	{
		if (!GetOwner().HasAuthority())
			return false;

		switch (WeaponDefinition.FireMode)
		{
			case EFireMode::Semi:
			case EFireMode::Burst:
				// Only allow firing on initial press in semi and burst modes
				if (GetIsFiring())
					return false;
				break;

			case EFireMode::Auto:
				// Allow holding down the trigger in auto mode
				break;
		}

		if (GetIsOnShootCooldown())
			return false;

		if (AmmoAttribute <= 0)
		{
			PrintWarning(f"{WeaponDefinition.GetDisplayName()} has no ammo! Cannot fire.", 0, FLinearColor(1.0, 0.5, 0.0));
			return false;
		}

		if (GetIsReady())
		{
			Hits = Trace(10000.0f);

			Print(f"{WeaponDefinition.GetDisplayName()} fired!", 0.5f, FLinearColor(0.15, 0.32, 0.52));
			OnFire.Broadcast(BulletHit);

			// Weapon Chip Subscribers

			if (BulletHit.HitCharacter != nullptr)
			{
				OnHit.Broadcast(BulletHit);
			}
			else if (BulletHit.IsKill)
			{
				OnKill.Broadcast(BulletHit);
			}
			else if (BulletHit.IsPrecisionHit)
			{
				OnPrecisionHit.Broadcast(BulletHit);
			}
			else if (BulletHit.IsPrecisionHit && BulletHit.IsKill)
			{
				OnPrecisionKill.Broadcast(BulletHit);
			}
			// endregion

			auto AbilitySystem = Pond::GetPondPlayerStateBase().AbilitySystem;
			FGameplayEffectSpecHandle CurrentAmmoHandle = AbilitySystem.MakeOutgoingSpec(UGE_Additive_CurrentAmmo, 1, FGameplayEffectContextHandle());
			if (CurrentAmmoHandle.IsValid() && AmmoAttribute > 0)
			{
				CurrentAmmoHandle.Spec.SetByCallerMagnitude(GameplayTags::Data_Guns_Ammo, -1);
				AbilitySystem.ApplyGameplayEffectSpecToSelf(CurrentAmmoHandle);

				MagazineState = FMagazineState(AmmoAttribute, MaxAmmoAttribute, AmmoAttribute <= 0);

				Print(f"Decremented Current Ammo! ({AmmoAttribute}/{MaxAmmoAttribute})", 1, FLinearColor::DPink);

				// region Magazine Chip Subscribers
				if (AmmoAttribute == 1)
				{
					OnLastBullet.Broadcast(MagazineState);
				}
				// endregion
			}

			RecoilIndex++;

			if (AmmoAttribute <= 0)
			{
				WeaponDefinition.ReloadStrategy.GunState = EGunState::NotReady;
				PrintWarning(f"{WeaponDefinition.GetDisplayName()} is empty!", 2, FLinearColor(1.0, 0.5, 0.0));
			}

			TimeSinceLastShot = 0;
			return true;
		}

		return false;
	}

	UFUNCTION(BlueprintEvent)
	private void StartADS(FInputActionValue ActionValue, float32 InElapsedTime, float32 InTriggeredTime,
				  const UInputAction SourceAction)
	{
	}

	UFUNCTION(BlueprintEvent)
	private void CancelledADS(FInputActionValue ActionValue, float32 InElapsedTime,
					  float32 InTriggeredTime, const UInputAction SourceAction)
	{
		IsAltMode = false;
	}

	UFUNCTION(BlueprintEvent)
	private void TriggeredADS(FInputActionValue ActionValue, float32 InElapsedTime,
					  float32 InTriggeredTime, const UInputAction SourceAction)
	{
		IsAltMode = true;
	}

	UFUNCTION(BlueprintEvent)
	private void EndADS(FInputActionValue ActionValue, float32 InElapsedTime, float32 InTriggeredTime,
				const UInputAction SourceAction)
	{
		IsAltMode = false;
	}

	UFUNCTION()
	private void Interim_Reload(FInputActionValue ActionValue, float32 InElapsedTime,
						float32 InTriggeredTime, const UInputAction SourceAction)
	{
		Reload();
	}

	UFUNCTION(BlueprintEvent)
	void Reload()
	{
		WeaponDefinition.ReloadStrategy.Reload();

		Gameplay::PlaySound2D(WeaponDefinition.ReloadSound);

		OnReload.Broadcast(FMagazineState(MaxAmmoAttribute, MaxAmmoAttribute, AmmoAttribute <= 0));
	}

	void Ready()
	{
		if (!GetIsReady() && AmmoAttribute > 0)
		{
			WeaponDefinition.ReloadStrategy.GunState = EGunState::Ready;
			BP_Ready();
			// Print(f"{GunName} readied! Magazine: {CurrentAmmo}/{MaxAmmo}", 2, FLinearColor(0.58, 0.95, 0.49));
		}
		else if (AmmoAttribute <= 0)
		{
			PrintWarning(f"No ammo to ready! Gun is empty.", 2, FLinearColor(1.0, 0.5, 0.0));
		}
	}

	UFUNCTION(BlueprintEvent, NotBlueprintCallable, Category = "Gun | Reload", DisplayName = "Reload")
	void BP_OnReload()
	{}

	UFUNCTION(BlueprintEvent, NotBlueprintCallable, Category = "Gun | Reload", DisplayName = "Ready")
	void BP_Ready()
	{}
};