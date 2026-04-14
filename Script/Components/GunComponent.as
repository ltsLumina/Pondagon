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
	AScriptEnemyBase HitEnemy;

	UPROPERTY(BlueprintReadOnly)
	float Damage;

	UPROPERTY(BlueprintReadOnly)
	bool IsShieldBreak;

	UPROPERTY(BlueprintReadOnly)
	bool IsPrecisionHit;

	UPROPERTY(BlueprintReadOnly)
	bool IsKill;

	UPROPERTY(BlueprintReadOnly)
	FHitResult Hit;

	FBulletHit(AController InInstigator, AScriptEnemyBase InHitEnemy, float InDamage, bool InIsShieldBreak, bool InIsPrecisionKill, bool InIsKill, FHitResult InHitResult)
	{
		Instigator = InInstigator;
		HitEnemy = InHitEnemy;
		Damage = InDamage;
		IsShieldBreak = InIsShieldBreak;
		IsPrecisionHit = InIsPrecisionKill;
		IsKill = InIsKill;
		Hit = InHitResult;
	}
};

// #region Mixin
UFUNCTION(BlueprintPure, Meta = (ReturnDisplayName = "Hit Result"))
mixin FHitResult GetHitResult(FBulletHit BulletHit)
{
	return BulletHit.Hit;
}
// #endregion

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
	default bReplicates = true;

	UPROPERTY(Category = "Gun", EditDefaultsOnly, BlueprintReadOnly)
	UWeaponDefinition DefaultGun;

	UPROPERTY(Category = "Gun", VisibleInstanceOnly, BlueprintReadOnly)
	UWeaponInstance CurrentGun;

	UFUNCTION(Category = "Gun", Meta = (DeterminesOutputType = "Instance"))
	UWeaponInstance RegisterCurrentGun(UWeaponInstance Instance)
	{
		CurrentGun = Instance;

		return CurrentGun;
	}

	UFUNCTION(BlueprintPure)
	UWeaponDefinition GetWeaponDefinition() property
	{
		return CurrentGun.WeaponDefinition;
	}

	UPROPERTY(NotVisible, BlueprintReadOnly)
	APondHero OwningHero;

	UPROPERTY(Category = "Gun | Scope", VisibleInstanceOnly)
	bool IsScoped;

	UPROPERTY(Category = "Hero | GAS", EditConst)
	const UGenericGunAttributes GenericGunAttributes;

	UFUNCTION(Category = "Gun | Ammo", BlueprintPure)
	int GetCurrentAmmo() property
	{
		float CurrentValue = OwningHero.AbilitySystem.GetAttributeCurrentValue(UGenericGunAttributes, UGenericGunAttributes::AmmoName);
		return int(CurrentValue);
	}

	UFUNCTION(Category = "Gun | Ammo", BlueprintPure)
	int GetCurrentMaxAmmo() property
	{
		float CurrentValue = OwningHero.AbilitySystem.GetAttributeCurrentValue(UGenericGunAttributes, UGenericGunAttributes::MaxAmmoName);
		return int(CurrentValue);
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
		return TimeSinceLastShot > 1.0 && BulletIndex == 0;
	}

	/**
	 * The current index in the recoil pattern. This increments with each shot fired.
	 * It is used to determine the recoil offset applied to the gun.
	 */
	UPROPERTY(Category = "Gun | Recoil", VisibleInstanceOnly, BlueprintReadOnly, ReplicatedUsing = "OnRep_BulletIndex")
	int BulletIndex;

	UFUNCTION()
	void OnRep_BulletIndex(int Old)
	{
		Print(f"{BulletIndex=}");
	}

	UFUNCTION(BlueprintPure, Category = "Gun | Accuracy")
	bool IsBulletProtected(EPondMovementState MovementState)
	{
		return BulletIndex < WeaponDefinition.ProtectedBullets && MovementState == EPondMovementState::Still && CanFireProtectedBullet;
	}

	UPROPERTY(Category = "Gun | Accuracy", VisibleInstanceOnly)
	FBulletSpreadData AccuracyCone;

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

	void Initialize()
	{
		OwningHero = Cast<APondHero>(GetOwner());
		ComponentTickEnabled = true; // need to defer tick until owning hero is init'd.

		GenericGunAttributes = OwningHero.AbilitySystem.GetAttributeSet(UGenericGunAttributes);

		if (GetOwner().HasAuthority())
			GrantAbilities(OwningHero.AbilitySystem);

		Ready();
	}

	UFUNCTION(BlueprintAuthorityOnly)
	void GrantAbilities(UAbilitySystemComponent ASC)
	{
		ASC.GiveAbility(WeaponDefinition.FireGameplayAbility, 0, -1);
		ASC.GiveAbility(WeaponDefinition.ReloadGameplayAbility, 0, -1);

		for (auto& Enchant : CurrentGun.Enchantments)
		{
			ASC.GiveAbility(Enchant);
		}
	}

	bool CanFireProtectedBullet = true;
	default ComponentTickEnabled = false;

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		TimeSinceLastShot += DeltaSeconds;

		// Assumes player has not fired for a while, reset recoil index
		BulletIndex = TimeSinceLastShot > 0.4f ? 0 : BulletIndex;

		if (IsValid(OwningHero))
			CanFireProtectedBullet = OwningHero.TimeSinceMoving > 0.85f;
	}

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

		if (IsBulletProtected(OwningHero.ResolveMovementState()))
		{
			FVector SpreadDirSansSpread = (AimDirection).GetSafeNormal();
			return SpreadDirSansSpread;
		}

		// Apply spread offset
		FVector SpreadDir = (AimDirection + Right * OffsetX + Up * OffsetY).GetSafeNormal();

		OutSpreadData.ConeWidth = Math::Atan2(Math::Abs(OffsetX), 1.0f);
		OutSpreadData.ConeHeight = Math::Atan2(Math::Abs(OffsetY), 1.0f);
		OutSpreadData.ErrorAngle = Math::RadiansToDegrees(Math::Acos(SpreadDir.DotProduct(AimDirection)));
		OutSpreadData.IsAccurate = AccuracyCone.ErrorAngle <= 0.01f;

		return SpreadDir;
	}

	FVector TraceStart;
	FVector TraceEnd;

	// for debug only.
	EDrawDebugTrace DebugTrace = EDrawDebugTrace::Persistent;
	float DebugTraceDuration = 61.5f;
	bool DrawCones = true;

	FVector GetTargetPoint(float MaxDistance = 10000.0f)
	{
		FVector Location;
		FRotator Rotation;
		OwningHero.Controller.GetPlayerViewPoint(Location, Rotation);
		FVector CameraLocation = Location;
		FVector CameraForward = Rotation.ForwardVector;

		TraceStart = CameraLocation;
		TraceEnd = CameraLocation + CameraForward * MaxDistance;

		// Get Target Point (the actual point the player is looking at)
		FHitResult Hit;
		System::LineTraceSingle(TraceStart,
								TraceEnd,
								ETraceTypeQuery::TraceTypeQuery3,
								false,
								TArray<AActor>(),
								EDrawDebugTrace::None,
								Hit,
								true,
								FLinearColor::Red,
								FLinearColor::Green,
								DebugTraceDuration);

		Cosmetic_DrawDebugTargetPointTrace(TraceStart, TraceEnd, DebugTraceDuration);

		FVector TargetPoint = Hit.bBlockingHit ? Hit.Location : TraceEnd;
		return TargetPoint;
	}

	UFUNCTION(BlueprintPure, Category = "Gun | Accuracy")
	float GetSpread(EPondMovementState MovementState)
	{
		float Spread = 0;

		bool IsCrouched = MovementState == EPondMovementState::Crouch || MovementState == EPondMovementState::CrouchWalk;
		float MaxSpread = IsCrouched ? WeaponDefinition.CrouchMaxSpread : WeaponDefinition.StandingMaxSpread;

		float Time = (1 + BulletIndex) / float(WeaponDefinition.MaxSpreadBullet);
		float Value = WeaponDefinition.SpreadCurve.GetFloatValue(Time);

		Spread += Math::Clamp(Value, 0, MaxSpread);

		float Penalty = 0;

		switch (MovementState)
		{
			case EPondMovementState::Airborne:
				Penalty = WeaponDefinition.AirbornePenalty;
				break;
			case EPondMovementState::Run:
				Penalty = WeaponDefinition.RunPenalty;
				break;
			case EPondMovementState::Walk:
				Penalty = WeaponDefinition.WalkPenalty;
				break;
			case EPondMovementState::CrouchWalk:
				Penalty = WeaponDefinition.CrouchPenalty;
				break;

			default:
				break;
		}

		Spread += Penalty;

		bool IsProtected = IsBulletProtected(MovementState);
		Spread = IsProtected ? WeaponDefinition.StandingSpread : Spread;
		FString ProtectedSuffix = IsProtected ? "(Protected)" : "";
		Print(f"{Spread=}° degrees {ProtectedSuffix}", 1, FLinearColor(0.5, 0.5, 1.0));
		return Spread;
	}

	TArray<FHitResult> Hits;
	bool BlockingHit;
	FGameplayEventData Payload;

	FTimerHandle Handle;

	/**
	 * Fires four traces, which each serve a separate purpose toward calculating where a bullet will hit.
	 * Each trace returns a point in space that is used to calculate the end result.
	 * - `TargetPoint`: The vector point hit from the player's eyes to the center of the player's view across `MaxDistance`units.
	 * - `SpreadPoint`: Vector point at which the bullet would hit when accounting for added spread from `BulletIndex` (recoil), `MovementError` (penalty) and crouch/standing coefficient.
	 * - `MagnetizedPoint` Vector point that the `BulletMagnetism` stat 'pulled' the `SpreadPoint` toward, based on the `ErrorAngle` of the `SpreadPoint`.
	 * - `FinalPoint`: The final point in space that the bullet will hit, accounting for `TargetPoint`, `SpreadPoint`, and `MagnetizedPoint` (if a target was hit by the magnetism capsule trace).
	 */
	void Fire()
	{
		FVector TargetPoint = GetTargetPoint(10000.0f);

		float ConeExtents;
		FVector SpreadPoint = GetSpreadPoint(TargetPoint, ConeExtents);

		FHitResult Hit;
		AActor TargetActor = SweepForTarget(Hit);
		FVector MagnetizedPoint = GetMagnetizedPoint(TargetActor, Hit, SpreadPoint);

		FVector ImpactPoint = TraceStart + (IsValid(TargetActor) ? MagnetizedPoint : SpreadPoint) * 10000.0f;
		TraceFinalHit(ImpactPoint);
	}

	AActor SweepForTarget(FHitResult&out Hit)
	{
		TArray<EObjectTypeQuery> ObjTypes;
		ObjTypes.Add(EObjectTypeQuery::Pawn);

		TArray<AActor> IgnoreActors;
		IgnoreActors.Add(GetOwner());

		float AssistRange = 2500.0f;
		float ConeHalfAngleDeg = GenericGunAttributes.AimAssist.CurrentValue;
		float ConeHalfAngleRad = Math::DegreesToRadians(ConeHalfAngleDeg);

		float Radius = Math::Tan(ConeHalfAngleRad) * AssistRange;

		System::CapsuleTraceSingleForObjects(TraceStart,
											 TraceEnd,
											 Radius,
											 Radius,
											 ObjTypes,
											 false,
											 IgnoreActors,
											 DebugTrace,
											 Hit,
											 true,
											 FLinearColor::DPink,
											 FLinearColor::Red,
											 DebugTraceDuration);

		if (Hit.Actor != nullptr)
			Print(f"Magnetism Target: {Hit.Actor.ActorNameOrLabel}", 0.5f);

		return Hit.Actor;
	}

	FVector GetSpreadPoint(FVector&in TargetPoint, float&out SpreadDeg)
	{
		FVector AimDirection = (TargetPoint - TraceStart).GetSafeNormal();

		SpreadDeg = GetSpread(OwningHero.ResolveMovementState());

		FVector BulletDirection = ApplySpread(AimDirection, SpreadDeg, AccuracyCone);
		Cosmetic_DrawAccuracyCone(AimDirection, SpreadDeg);

		FVector SpreadEnd = TraceStart + BulletDirection * 10000.0f;
		Cosmetic_DrawDebugSpreadPointTrace(TraceStart, SpreadEnd, DebugTraceDuration);

		return BulletDirection;
	}

	FVector GetAimDirection(FVector&in TargetPoint)
	{
		return (TargetPoint - TraceStart).GetSafeNormal();
	}

	FVector GetMagnetizedPoint(AActor&in MagnetismTarget, FHitResult&in Hit, FVector&in BulletDirection)
	{
		FVector PulledDir;
		if (IsValid(MagnetismTarget))
		{
			float MaxPullDeg = GenericGunAttributes.AimAssist.CurrentValue;

			FVector DesiredDir = (Hit.ImpactPoint - TraceStart).GetSafeNormal();

			FBulletSpreadData AimAssistCone;
			AimAssistCone.ConeWidth = Math::RadiansToDegrees(Math::Atan2(Math::Abs(DesiredDir.Y), 1.0f));
			AimAssistCone.ConeHeight = Math::RadiansToDegrees(Math::Atan2(Math::Abs(DesiredDir.Z), 1.0f));
			AimAssistCone.ErrorAngle = Math::RadiansToDegrees(Math::Acos(Math::Clamp(DesiredDir.DotProduct(BulletDirection), -1.0f, 1.0f)));

			PulledDir = BulletDirection;
			if (AimAssistCone.ErrorAngle > KINDA_SMALL_NUMBER)
			{
				// Move only a fraction so we rotate by at most MaxPullDeg
				float Alpha = Math::Min(1.0f, MaxPullDeg / AimAssistCone.ErrorAngle);
				PulledDir = (BulletDirection + (DesiredDir - BulletDirection) * Alpha).GetSafeNormal();
			}
			float PullAngleDeg = Math::RadiansToDegrees(Math::Acos(Math::Clamp(BulletDirection.DotProduct(PulledDir), -1.0f, 1.0f)));
			Cosmetic_DrawAimAssistCone(PulledDir, PullAngleDeg);
		}

		return PulledDir;
	}

	void Cosmetic_DrawAccuracyCone(FVector Direction, float AngleInDegrees)
	{
		if (!DrawCones) return;
		
		if (!GetOwner().HasAuthority())
			return;

		if (DebugTrace != EDrawDebugTrace::None)
			System::DrawDebugConeInDegrees(TraceStart,
										   Direction,
										   10000.0f,
										   AngleInDegrees,
										   AngleInDegrees,
										   12,
										   FLinearColor::Blue,
										   DebugTraceDuration);
	}

	void Cosmetic_DrawAimAssistCone(FVector Direction, float AngleInDegrees)
	{
		if (!DrawCones) return;

		if (!GetOwner().HasAuthority())
			return;

		if (DebugTrace != EDrawDebugTrace::None)
			System::DrawDebugConeInDegrees(TraceStart,
										   Direction,
										   10000.0f,
										   AngleInDegrees,
										   AngleInDegrees,
										   16,
										   FLinearColor::Purple,
										   DebugTraceDuration);
	}

	private void TraceFinalHit(FVector&in FinalDir)
	{
		TArray<AActor> ActorsToIgnore;
		ActorsToIgnore.Add(GetOwner()); // guncomponent is attached to character

		// Perform spread trace (the point the bullet will hit)
		BlockingHit = System::LineTraceMulti(TraceStart,
											 FinalDir,
											 ETraceTypeQuery::TraceTypeQuery3,
											 false,
											 ActorsToIgnore,
											 EDrawDebugTrace::None,
											 Hits,
											 true, // doesn't ignore the owning actor!! (ignores this component)
											 FLinearColor::Yellow,
											 FLinearColor::Green,
											 DebugTraceDuration);

		Cosmetic_DrawDebugFinalPointTrace(TraceStart, FinalDir, DebugTraceDuration);

		if (!BlockingHit)
		{
			Log("Trace did not hit anything!");
			ShootSFX();

			BulletHit = FBulletHit();
			return;
		}

		FHitResult LastHit = Hits.Last();

		auto Instigator = OwningHero.Controller;
		auto HitEnemy = Cast<AScriptEnemyBase>(LastHit.Actor);
		bool WasEnemyHit = IsValid(HitEnemy);
		float Damage = WeaponDefinition.GetDamage();

		BulletHit = FBulletHit();
		BulletHit.Instigator = Instigator;
		BulletHit.Damage = Damage;
		BulletHit.Hit = LastHit;
		BulletHit.IsPrecisionHit = WasEnemyHit && LastHit.BoneName == n"Head";

		BulletHit.HitEnemy = HitEnemy;
		if (WasEnemyHit)
		{
			BulletHit.IsShieldBreak = (HitEnemy.CurrentShield - Damage) <= 0;
			BulletHit.IsKill = (HitEnemy.CurrentHealth - Damage <= 0);
		}

		Payload.Instigator = OwningHero.Controller;
		Payload.Target = LastHit.Actor;
		Payload.EventMagnitude = Damage;
		Payload.TargetData = AbilitySystem::AbilityTargetDataFromHitResult(LastHit);

		auto ASC = AbilitySystem::GetAngelscriptAbilitySystemComponent(OwningHero.PlayerState);
		ASC.SendGameplayEvent(GameplayTags::Enchantment_Trigger_OnShot, Payload);

		ShootSFX();
		HitSFX();

		bool Penetrated = false;
		CreateImpactDecal(Penetrated);

		if (BulletHit.HitEnemy != nullptr)
		{
			float DamageAmount = BulletHit.Damage;

			Gameplay::ApplyPointDamage(
				BulletHit.HitEnemy,
				DamageAmount,
				FinalDir,
				LastHit,
				OwningHero.Controller,
				OwningHero,
				TSubclassOf<UDamageType>(UDamageType));
		}
	}

	private void Cosmetic_DrawDebugTargetPointTrace(FVector InStart, FVector InEnd, float InDuration = 1.0f)
	{
		if (!GetOwner().HasAuthority())
			return;

		FHitResult DummyHit;
		System::LineTraceSingle(
			InStart,
			InEnd,
			ETraceTypeQuery::TraceTypeQuery3,
			false,
			TArray<AActor>(),
			DebugTrace,
			DummyHit,
			true,
			FLinearColor::Red,
			FLinearColor::Green,
			InDuration);
	}

	private void Cosmetic_DrawDebugSpreadPointTrace(FVector InStart, FVector InEnd, float InDuration = 1.0f)
	{
		if (!GetOwner().HasAuthority())
			return;

		FHitResult DummyHit;
		System::LineTraceSingle(
			InStart,
			InEnd,
			ETraceTypeQuery::TraceTypeQuery3,
			false,
			TArray<AActor>(),
			DebugTrace,
			DummyHit,
			true,
			FLinearColor::Yellow,
			FLinearColor::Green,
			InDuration);
	}

	private void Cosmetic_DrawDebugFinalPointTrace(FVector InStart, FVector InEnd, float InDuration = 1.0f)
	{
		if (!GetOwner().HasAuthority())
			return;

		FHitResult DummyHit;
		System::LineTraceSingle(
			InStart,
			InEnd,
			ETraceTypeQuery::TraceTypeQuery3,
			false,
			TArray<AActor>(),
			DebugTrace,
			DummyHit,
			true,
			FLinearColor::LucBlue,
			FLinearColor::Green,
			InDuration);
	}

	void InvokeEnchantment(TSubclassOf<UEnchantment> EnchantClass)
	{
		auto ASC = AbilitySystem::GetAbilitySystemComponent(OwningHero.PlayerState);
		auto Spec = FGameplayAbilitySpec(EnchantClass, 1, -1, nullptr);
		ASC.GiveAbilityAndActivateOnceWithEventData(Spec, FGameplayEventData());
		Log(f"Activating {EnchantClass.DefaultObject.DisplayName}");
	}

	void ShootSFX()
	{
		if (CurrentAmmo > 0)
			Gameplay::PlaySoundAtLocation(WeaponDefinition.ShootSound, GetOwner().ActorLocation, FRotator::ZeroRotator, 1.0f, 1.0f, 0.0f, WeaponDefinition.DefaultAttenuation);
		// else
		// Gameplay::PlaySoundAtLocation(DryFireSound, GetActorLocation(), FRotator::ZeroRotator, 0.6f, 0.8f, 0.0f, DefaultAttenuation);
	}

	void HitSFX()
	{
		if (BulletHit.HitEnemy != nullptr && BulletHit.IsPrecisionHit)
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
		else if (BulletHit.HitEnemy != nullptr && !BulletHit.IsPrecisionHit)
		{
			Gameplay::PlaySound2D(WeaponDefinition.BodyshotSound);
		}
		else if (BulletHit.HitEnemy == nullptr)
		{
			float PitchMultiplier = Math::Clamp(1.0f - (BulletHit.Hit.Distance / 10000.0f), 0.75f, 1.0f); // Closer impacts sound higher pitched
			Gameplay::PlaySoundAtLocation(WeaponDefinition.GroundHitSound, BulletHit.Hit.Location, FRotator::ZeroRotator, 1.0f, PitchMultiplier, 0.0f, WeaponDefinition.DefaultAttenuation);
		}
	}

	void CreateImpactDecal(bool&out Penetrated)
	{
		for (FHitResult Hit : Hits)
		{
			if (Hit.Actor.IsA(AScriptPondCharacter) || Hit.Actor.IsA(APondHero))
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

		auto ASC = AbilitySystem::GetAngelscriptAbilitySystemComponent(OwningHero.PlayerState);
		ASC.TryActivateAbilityByClass(WeaponDefinition.FireGameplayAbility);
	}

	/**
	 * Generic shoot function.
	 * TODO: May want to make this only fire on authority to prevent BulletIndex from being manipulated by the client.
	 */
	UFUNCTION()
	bool Shoot()
	{
		float FireRateAttribute = GenericGunAttributes.FireRate.CurrentValue;

		ShootCooldown = 1.0 / FireRateAttribute;
		RPM = FireRateAttribute * 60;

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

		if (CurrentAmmo <= 0)
		{
			PrintWarning(f"{WeaponDefinition.GetDisplayName()} has no ammo! Cannot fire.", 0, FLinearColor(1.0, 0.5, 0.0));
			return false;
		}

		if (GetIsReady())
		{
			Fire();

			BulletIndex++;

			if (CurrentAmmo <= 0)
			{
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

	UFUNCTION(NotBlueprintCallable)
	private void Interim_Reload(FInputActionValue ActionValue, float32 InElapsedTime,
						float32 InTriggeredTime, const UInputAction SourceAction)
	{
		auto ASC = AbilitySystem::GetAbilitySystemComponent(OwningHero.PlayerState);
		ASC.TryActivateAbilityByClass(WeaponDefinition.ReloadGameplayAbility);
	}

	void Ready()
	{
		if (!GetIsReady() && CurrentAmmo > 0)
		{
			WeaponDefinition.ReloadStrategy.GunState = EGunState::Ready;
			BP_Ready();
			// Print(f"{GunName} readied! Magazine: {CurrentAmmo}/{MaxAmmo}", 2, FLinearColor(0.58, 0.95, 0.49));
		}
		else if (CurrentAmmo <= 0)
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