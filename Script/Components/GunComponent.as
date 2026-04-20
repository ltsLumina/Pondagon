namespace UGunComponent
{
	const float TRACE_DISTANCE = 10000;
}

enum EGASInputID
{
	Shoot = 0,
	AltFire = 1,
	Reload = 2,
}

enum EFireMode
{
	Semi,
	Burst,
	Auto
}

// #region Mixin
UFUNCTION(BlueprintPure, Meta = (ReturnDisplayName = "Is Precision Hit"))
mixin bool IsPrecisionHit(FHitResult Hit)
{
	return Hit.BoneName == n"Head";
}
// #endregion

UCLASS(Meta = (PrioritizeCategories = "Debug"))
class UGunComponent : UActorComponent
{
	default bReplicates = true;
	default ComponentTickEnabled = false;
	default PrimaryComponentTick.bStartWithTickEnabled = false;

	UPROPERTY(Category = "Debug")
	EDrawDebugTrace DebugTrace = EDrawDebugTrace::Persistent;

	UPROPERTY(Category = "Debug", Meta = (EditCondition = "DebugTrace == EDrawDebugTrace::ForDuration", EditConditionHides))
	float DebugTraceDuration = 5.0f;

	UPROPERTY(Category = "Debug")
	bool DrawLines = true;

	UPROPERTY(Category = "Debug")
	bool DrawCones = true;

	UPROPERTY(Category = "Debug")
	bool PrintSpreadInfo = true;

	// - end debug

	UPROPERTY(Category = "Gun", EditDefaultsOnly, BlueprintReadOnly)
	UWeaponDefinition DefaultGun;

	UPROPERTY(Category = "Gun", NotVisible, BlueprintReadOnly)
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
		auto HeroDefinition = Cast<UHeroDefinition>(OwningHero.Definition);
		return HeroDefinition.WeaponDefinition;
	}

	UPROPERTY(NotVisible, BlueprintReadOnly)
	AScriptPondHero OwningHero;

	UPROPERTY(Category = "Hero | GAS", NotVisible, BlueprintReadOnly)
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
	UPROPERTY(Category = "Gun | Shooting", VisibleInstanceOnly, BlueprintReadOnly)
	float RPM;

	/**
	 * The cooldown time between shots, in seconds.
	 * This is calculated as the inverse of the fire rate.
	 */
	UPROPERTY(Category = "Gun | Shooting", VisibleInstanceOnly, BlueprintReadOnly, Meta = (Units = "Seconds"))
	float ShootCooldown = 0.1f;

	/**
	 * The time elapsed since the last shot was fired, in seconds.
	 */
	UPROPERTY(Category = "Gun | Shooting", VisibleInstanceOnly, BlueprintReadOnly, Meta = (Units = "Seconds"))
	float TimeSinceLastShot = 0.0f;

	// - shooting helpers

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
	 * The current index in the recoil pattern. This increments with each shot fired.
	 * It is used to determine the recoil offset applied to the gun.
	 */
	UPROPERTY(Category = "Gun | Recoil", VisibleInstanceOnly, BlueprintReadOnly, Replicated)
	int BulletIndex;

	UFUNCTION(BlueprintPure, Category = "Gun | Accuracy")
	bool IsBulletProtected(EPondMovementState MovementState)
	{
		bool IsInProtectedRange = BulletIndex < WeaponDefinition.ProtectedBullets;
		bool IsStill = MovementState == EPondMovementState::Still;
		bool PastStillThreshold = OwningHero.TimeSinceMoving > 0.5f;
		bool PastShootThreshold = TimeSinceLastShot > 0.75;

		bool Result = IsInProtectedRange && IsStill && (PastStillThreshold && PastShootThreshold);
		return Result;
	}

	UPROPERTY(Category = "Gun | Accuracy", VisibleInstanceOnly)
	FBulletSpreadData AccuracyCone;

	// - alt fire

	UPROPERTY(Category = "Gun | Alt Fire", VisibleInstanceOnly, BlueprintReadOnly)
	bool IsAltMode = false;

	// - Events

	UAngelscriptAbilitySystemComponent ASC;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		OwningHero = Cast<AScriptPondHero>(GetOwner());
	}

	void Initialize()
	{
		ComponentTickEnabled = true; // need to defer tick until owning hero is init'd.

		GenericGunAttributes = OwningHero.AbilitySystem.GetAttributeSet(UGenericGunAttributes);

		ASC = AbilitySystem::GetAngelscriptAbilitySystemComponent(GetOwner());

		if (GetOwner().HasAuthority())
			AuthGrantAbilities(ASC);

		OnInitialize();
	}

	UFUNCTION(BlueprintEvent)
	void OnInitialize()
	{}

	UFUNCTION(BlueprintAuthorityOnly)
	void AuthGrantAbilities(UAbilitySystemComponent InASC)
	{
		InASC.GiveAbility(WeaponDefinition.ShootGameplayAbility, 0, int(EGASInputID::Shoot));
		InASC.GiveAbility(WeaponDefinition.AltFireGameplayAbility, 0, int(EGASInputID::AltFire));
		InASC.GiveAbility(WeaponDefinition.ReloadGameplayAbility, 0, int(EGASInputID::Reload));

		for (auto& Enchant : CurrentGun.Enchantments)
		{
			InASC.GiveAbility(Enchant);
		}
	}

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		TimeSinceLastShot += DeltaSeconds;

		if (WeaponDefinition.AltModeUsesZoom)
		{
			if (IsAltMode)
				Timeline_ZoomIn(DeltaSeconds);
			else
				Timeline_ZoomOut(DeltaSeconds);
		}
	}

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
		FVector SpreadDir = (AimDirection + Right * OffsetX + Up * OffsetY).GetSafeNormal();

		OutSpreadData.ConeWidth = Math::Atan2(Math::Abs(OffsetX), 1.0f);
		OutSpreadData.ConeHeight = Math::Atan2(Math::Abs(OffsetY), 1.0f);
		OutSpreadData.ErrorAngle = Math::RadiansToDegrees(Math::Acos(SpreadDir.DotProduct(AimDirection)));

		return SpreadDir;
	}

	FVector TraceStart;
	FVector TraceEnd;

	FVector GetTargetPoint(float MaxDistance = UGunComponent::TRACE_DISTANCE, float32&out Dist = 0.f)
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

		Dist = Hit.Distance;

		Cosmetic_DrawDebugTargetPointTrace(TraceStart, TraceEnd, DebugTraceDuration);

		FVector TargetPoint = Hit.bBlockingHit ? Hit.Location : TraceEnd;
		return TargetPoint;
	}

	float Spread = 0;

	UFUNCTION(BlueprintPure, Category = "Gun | Accuracy")
	float GetSpread(EPondMovementState MovementState)
	{
		UCurveFloat Curve = WeaponDefinition.SpreadCurve != nullptr ? WeaponDefinition.SpreadCurve : LinearSpreadCurve;

		bool IsProtected = IsBulletProtected(MovementState);

		bool IsCrouched = MovementState == EPondMovementState::Crouch || MovementState == EPondMovementState::CrouchWalk;
		float FirstShotSpread = IsCrouched ? WeaponDefinition.CrouchSpread : WeaponDefinition.StandingSpread;
		float MaxSpread = IsCrouched ? WeaponDefinition.CrouchMaxSpread : WeaponDefinition.StandingMaxSpread;

		if (!IsProtected)
		{
			float Time = (1 + BulletIndex) / float(WeaponDefinition.MaxSpreadBullet);
			float Value = Curve.GetFloatValue(Time);
			Value = Math::Clamp(Value, 0, 1);
			Spread += Value;

			if (BulletIndex == 0)
				Spread += FirstShotSpread;
		}
		else
		{
			// protected bullet is slightly tighter
			Spread = FirstShotSpread * 0.5f;
		}

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

		Spread = Math::Clamp(Spread, 0, (MaxSpread + Penalty));

		if (PrintSpreadInfo)
		{
			FString ProtectedSuffix = IsProtected ? "(Protected)" : "";
			Print(f"{Spread=}° degrees {ProtectedSuffix}", 1, FLinearColor(0.5, 0.5, 1.0));
		}

		return Spread;
	}

	TArray<FHitResult> Hits;
	bool BlockingHit;
	FGameplayEventData Payload;

	/**
	 * Fires four traces, which each serve a separate purpose toward calculating where a bullet will hit.
	 * Each trace returns a point in space that is used to calculate the end result.
	 * - `TargetPoint`: The vector point hit from the player's eyes to the center of the player's view across `MaxDistance`units.
	 * - `SpreadPoint`: Vector point at which the bullet would hit when accounting for added spread from `BulletIndex` (recoil), `MovementError` (penalty) and crouch/standing coefficient.
	 * - `MagnetizedPoint` Vector point that the `BulletMagnetism` stat 'pulled' the `SpreadPoint` toward, based on the `ErrorAngle` of the `SpreadPoint`.
	 * - `FinalPoint`: The final point in space that the bullet will hit, accounting for `TargetPoint`, `SpreadPoint`, and `MagnetizedPoint` (if a target was hit by the magnetism capsule trace).
	 */
	void Fire(FHitResult&out Hit)
	{
		// The point the player was aiming at.
		float32 dist;
		FVector TargetPoint = GetTargetPoint(UGunComponent::TRACE_DISTANCE, dist);

		// Where the spread wants the bullet to go.
		float ConeExtents;
		FVector SpreadPoint = GetSpreadPoint(TargetPoint, ConeExtents);
		TArray<EObjectTypeQuery> foo;
		foo.Add(EObjectTypeQuery::Pawn);
		TArray<AActor> IgnoreActors;
		IgnoreActors.Add(GetOwner());

		FVector SpreadEnd = TraceStart + SpreadPoint * 10000.0f;
		FHitResult HeadHit;
		System::LineTraceSingle(TraceStart,
								SpreadEnd,
								ETraceTypeQuery::TraceTypeQuery3,
								false,
								IgnoreActors,
								EDrawDebugTrace::None,
								HeadHit,
								true,
								FLinearColor::Transparent);

		// MAGNETISM - Where the bullet gets dragged to, if applicable (an enemy was hit).
		FHitResult MagnetismHit;
		AActor TargetActor = SweepForTarget(MagnetismHit, dist);
		FVector MagnetizedPoint = GetMagnetizedPoint(TargetActor, MagnetismHit, SpreadPoint);

		// The final impact point, affected by magnetism or not.
		FVector ImpactPoint = TraceStart + (IsValid(TargetActor) && !HeadHit.IsPrecisionHit() ? MagnetizedPoint : SpreadPoint) * UGunComponent::TRACE_DISTANCE;
		TraceFinalHit(ImpactPoint, Hit);

		if (GetOwner().HasAuthority())
			BulletIndex++;

		TimeSinceLastShot = 0;
	}

	float GetAimAssistTraceRadius(float Dist)
	{
		float ConeHalfAngleDeg = GenericGunAttributes.AimAssist.CurrentValue;
		float ConeHalfAngleRad = Math::DegreesToRadians(ConeHalfAngleDeg);
		float Radius = Math::Tan(ConeHalfAngleRad) * Dist;
		
		return Radius;
	}

	AActor SweepForTarget(FHitResult&out MagnetismHit, float Dist)
	{
		TArray<EObjectTypeQuery> ObjTypes;
		ObjTypes.Add(EObjectTypeQuery::Pawn);

		TArray<AActor> IgnoreActors;
		IgnoreActors.Add(GetOwner());

		float Radius = GetAimAssistTraceRadius(Dist);

#if EDITOR
		DebugTrace = (GetOwner().AsPawn().IsLocallyControlled()) ? DebugTrace : EDrawDebugTrace::None;
#endif

		System::CapsuleTraceSingleForObjects(TraceStart,
											 TraceEnd,
											 Radius,
											 0,
											 ObjTypes,
											 false,
											 IgnoreActors,
											 DebugTrace,
											 MagnetismHit,
											 true,
											 FLinearColor::DPink,
											 FLinearColor::Red,
											 DebugTraceDuration);

		return MagnetismHit.Actor;
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

	FVector GetMagnetizedPoint(AActor&in MagnetismTarget, FHitResult MagnetismHit, FVector SpreadPoint)
	{
		FVector PulledDir;
		if (IsValid(MagnetismTarget))
		{
			float MaxPullDeg = GenericGunAttributes.AimAssist.CurrentValue;

			FVector DesiredDir = (MagnetismHit.ImpactPoint - TraceStart).GetSafeNormal();

			FBulletSpreadData AimAssistCone;
			AimAssistCone.ConeWidth = Math::RadiansToDegrees(Math::Atan2(Math::Abs(DesiredDir.Y), 1.0f));
			AimAssistCone.ConeHeight = Math::RadiansToDegrees(Math::Atan2(Math::Abs(DesiredDir.Z), 1.0f));
			AimAssistCone.ErrorAngle = Math::RadiansToDegrees(Math::Acos(Math::Clamp(DesiredDir.DotProduct(SpreadPoint), -1.0f, 1.0f)));

			PulledDir = SpreadPoint;
			if (AimAssistCone.ErrorAngle > KINDA_SMALL_NUMBER)
			{
				// Move only a fraction so we rotate by at most MaxPullDeg
				float Alpha = Math::Min(1.0f, MaxPullDeg / AimAssistCone.ErrorAngle);
				PulledDir = (SpreadPoint + (DesiredDir - SpreadPoint) * Alpha).GetSafeNormal();
			}
			float PullAngleDeg = Math::RadiansToDegrees(Math::Acos(Math::Clamp(SpreadPoint.DotProduct(PulledDir), -1.0f, 1.0f)));
			Cosmetic_DrawAimAssistCone(PulledDir, PullAngleDeg);
		}

		return PulledDir;
	}

	void Cosmetic_DrawAccuracyCone(FVector Direction, float AngleInDegrees)
	{
		if (!DrawCones)
			return;

		if (!(GetOwner().AsPawn()).IsLocallyControlled())
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
		if (!DrawCones)
			return;

		if (!(GetOwner().AsPawn()).IsLocallyControlled())
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

	private void TraceFinalHit(FVector FinalDir, FHitResult&out Hit)
	{
		TArray<AActor> ActorsToIgnore;
		ActorsToIgnore.Add(GetOwner()); // guncomponent is attached to character

		Hits.Empty();

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
			ASC.SendGameplayEvent(GameplayTags::Enchantment_Trigger_OnShot, Payload);
			Hit = FHitResult();

			return;
		}

		FHitResult LastHit = Hits.Last();
		Hit = LastHit;

		Payload.Instigator = OwningHero.Controller;
		Payload.Target = LastHit.Actor;
		Payload.TargetData = AbilitySystem::AbilityTargetDataFromHitResult(LastHit);

		ASC.SendGameplayEvent(GameplayTags::Enchantment_Trigger_OnShot, Payload);

		ShootSFX();
		HitSFX();

		bool Penetrated = false;
		CreateImpactDecal(Penetrated);

		if (LastHit.Actor != nullptr)
		{
			Gameplay::ApplyPointDamage(
				LastHit.Actor,
				-1,
				FinalDir,
				LastHit,
				OwningHero.Controller,
				OwningHero,
				TSubclassOf<UDamageType>(UDamageType));
		}
	}

	private void Cosmetic_DrawDebugTargetPointTrace(FVector InStart, FVector InEnd, float InDuration = 1.0f)
	{
		if (!(GetOwner().AsPawn()).IsLocallyControlled())
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
		if (!(GetOwner().AsPawn()).IsLocallyControlled())
			return;

		if (!DrawLines)
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
		if (!(GetOwner().AsPawn()).IsLocallyControlled())
			return;

		if (!DrawLines)
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
		auto Spec = FGameplayAbilitySpec(EnchantClass, 1, -1, nullptr);
		ASC.GiveAbilityAndActivateOnceWithEventData(Spec, FGameplayEventData());
		Log(f"Activating {EnchantClass.DefaultObject.DisplayName}");
	}

	void ShootSFX()
	{ /*
		 if (CurrentAmmo > 0)
			 Gameplay::PlaySoundAtLocation(WeaponDefinition.ShootSound, GetOwner().ActorLocation, FRotator::ZeroRotator, 1.0f, 1.0f, 0.0f, WeaponDefinition.DefaultAttenuation);
		 else
			 Gameplay::PlaySoundAtLocation(DryFireSound, GetActorLocation(), FRotator::ZeroRotator, 0.6f, 0.8f, 0.0f, DefaultAttenuation);
		 */
	}

	void HitSFX()
	{ /*
		 if (BulletHit.HitEnemy != nullptr && BulletHit.IsPrecisionHit)
		 {
			  if (Cast<AEnemyBase>(BulletHit.HitCharacter).Attributes.ShieldAttribute.CurrentValue > 0)
			  {
				  Gameplay::PlaySound2D(WeaponDefinition.HeadshotWithArmorSound);
			  else
			  }
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
		 */
	}

	void CreateImpactDecal(bool&out Penetrated)
	{
		for (FHitResult Hit : Hits)
		{
			if (Hit.Actor.IsA(AScriptPondCharacter) || Hit.Actor.IsA(AScriptPondHero))
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

		ASC.TryActivateAbilityByClass(WeaponDefinition.ShootGameplayAbility);
	}

	UFUNCTION(NotBlueprintCallable)
	private void Interim_AltFire(FInputActionValue ActionValue, float32 InElapsedTime,
						 float32 InTriggeredTime, const UInputAction SourceAction)
	{
		this.ElapsedTime = InElapsedTime;
		this.TriggeredTime = InTriggeredTime;
	}

	/**
	 * Generic shoot function.
	 * TODO: May want to make this only fire on authority to prevent BulletIndex from being manipulated by the client.
	 */
	UFUNCTION()
	bool Shoot(FHitResult&out Hit)
	{
		float FireRateAttribute = GenericGunAttributes.FireRate.CurrentValue;

		ShootCooldown = 1.0 / FireRateAttribute;
		RPM = FireRateAttribute * 60;

		// Assumes player has not fired for a while, reset bullet index
		BulletIndex = TimeSinceLastShot > 0.4f ? 0 : BulletIndex;

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

		Fire(Hit);

		// if (IsValid(Hit.Actor))
		// Print(f"{Hit.Actor.ActorNameOrLabel=}");

		return true;
	}

	float PreAimDownSightsFOV;
	bool HasStartedZooming = false;
	float TargetFOV = 0;

	/**
	 * Divide-by-zero helper.
	 */
	float GetZoomMultiplier() const
	{
		float ZoomValue = GenericGunAttributes.Zoom.CurrentValue;
		ThrowIf(ZoomValue <= 0, "Cannot divide by zero!");

		float Result = Math::Max(ZoomValue, 0.01f);
		return Result;
	}

	void Timeline_ZoomIn(float DeltaSeconds)
	{
		auto Camera = UCameraComponent::Get(GetOwner());
		if (!IsValid(Camera))
			return;

		if (!HasStartedZooming)
		{
			if (PreAimDownSightsFOV <= 0.0f)
				PreAimDownSightsFOV = Camera.FieldOfView;

			TargetFOV = PreAimDownSightsFOV / GetZoomMultiplier();
			HasStartedZooming = true;
		}

		Camera.FieldOfView = Math::FInterpTo(Camera.FieldOfView, TargetFOV, DeltaSeconds, 20);

		if (Math::IsNearlyEqual(Camera.FieldOfView, TargetFOV, 0.1f))
		{
			Camera.FieldOfView = TargetFOV;
			HasStartedZooming = false;
		}
	}

	void Timeline_ZoomOut(float DeltaSeconds)
	{
		auto Camera = UCameraComponent::Get(GetOwner());
		if (!IsValid(Camera))
			return;

		if (!HasStartedZooming)
		{
			if (PreAimDownSightsFOV <= 0.0f)
				PreAimDownSightsFOV = Camera.FieldOfView;

			TargetFOV = PreAimDownSightsFOV;
			HasStartedZooming = true;
		}

		Camera.FieldOfView = Math::FInterpTo(Camera.FieldOfView, TargetFOV, DeltaSeconds, 20);

		if (Math::IsNearlyEqual(Camera.FieldOfView, TargetFOV, 0.1f))
		{
			Camera.FieldOfView = TargetFOV;
			HasStartedZooming = false;
			PreAimDownSightsFOV = 0;
		}
	}

	UFUNCTION(NotBlueprintCallable)
	private void StartAimDownSights(FInputActionValue ActionValue, float32 InElapsedTime, float32 InTriggeredTime,
							const UInputAction SourceAction)
	{
		if (IsAltMode)
			return;

		auto Camera = UCameraComponent::Get(GetOwner());
		if (IsValid(Camera) && PreAimDownSightsFOV <= 0.0f)
			PreAimDownSightsFOV = Camera.FieldOfView;
		HasStartedZooming = false;

		IsAltMode = true;
		UPondCharacterMovementComponent::Get(GetOwner()).StartAimDownSights();
		OwningHero.AdjustSensitivity(0.1f);

		ASC.TryActivateAbilityByClass(WeaponDefinition.AltFireGameplayAbility);
		ASC.PressInputID(int(EGASInputID::AltFire));
	}

	UFUNCTION(NotBlueprintCallable)
	private void EndAimDownSights(FInputActionValue ActionValue, float32 InElapsedTime, float32 InTriggeredTime,
						  const UInputAction SourceAction)
	{
		if (!IsAltMode)
			return;

		HasStartedZooming = false;
		if (PreAimDownSightsFOV > 0.0f)
			TargetFOV = PreAimDownSightsFOV;

		IsAltMode = false;
		UPondCharacterMovementComponent::Get(GetOwner()).StopAimDownSights();
		OwningHero.RestoreSensitivity();

		ASC.ReleaseInputID(int(EGASInputID::AltFire));
	}

	UFUNCTION(NotBlueprintCallable)
	private void Interim_Reload(FInputActionValue ActionValue, float32 InElapsedTime,
						float32 InTriggeredTime, const UInputAction SourceAction)
	{
		ASC.TryActivateAbilityByClass(WeaponDefinition.ReloadGameplayAbility);
	}
};

asset LinearSpreadCurve of UCurveFloat
{
	/*
		------------------------------------------------------------------
	1.0 |                                                            .·''|
		|                                                        .·''    |
		|                                                    .·''        |
		|                                                .·''            |
		|                                            .·''                |
		|                                        .·''                    |
		|                                    .··'                        |
		|                                .··'                            |
		|                            .··'                                |
		|                        .··'                                    |
		|                    .··'                                        |
		|                ..·'                                            |
		|            ..·'                                                |
		|        ..·'                                                    |
		|    ..·'                                                        |
	0.0 |..·'                                                            |
		------------------------------------------------------------------
		-0.3                                                           1.0
	*/
	AddLinearCurveKey(-0.3, 0.0);
	AddLinearCurveKey(1.0, 1.0);
}
