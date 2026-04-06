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
	AEnemyBase HitEnemy;

	UPROPERTY(BlueprintReadOnly)
	float Damage;

	UPROPERTY(BlueprintReadOnly)
	bool IsShieldBreak;

	UPROPERTY(BlueprintReadOnly)
	bool IsPrecisionHit;

	UPROPERTY(BlueprintReadOnly)
	bool IsKill;

	UPROPERTY(BlueprintReadOnly)
	TArray<EEnchantExecuteTrigger> ExecuteResults;

	UPROPERTY(BlueprintReadOnly)
	FHitResult Hit;

	FBulletHit(AController InInstigator, AEnemyBase InHitEnemy, float InDamage, bool InIsShieldBreak, bool InIsPrecisionKill, bool InIsKill, FHitResult InHitResult)
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
	UGenericGunAttributes GenericGunAttributes;

	UPROPERTY(Category = "Hero | GAS", EditConst)
	UAngelscriptAttributeSet SpecificGunAttributes;

	UFUNCTION(Category = "Gun | Ammo", BlueprintPure)
	int GetCurrentAmmo() property
	{
		return int(GenericGunAttributes.Ammo.CurrentValue);
	}

	UFUNCTION(Category = "Gun | Ammo", BlueprintPure)
	int GetCurrentMaxAmmo() property
	{
		return int(GenericGunAttributes.MaxAmmo.CurrentValue);
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

	void Initialize()
	{
		OwningHero = Cast<APondHero>(GetOwner());

		auto PS = Cast<AScriptPondPlayerState>(OwningHero.PlayerState);
		GenericGunAttributes = PS.GenericGunAttributes;
		SpecificGunAttributes = PS.SpecificGunAttributes;

		GenericGunAttributes.Ammo.Initialize(WeaponDefinition.Stats.Core.Magazine);
		GenericGunAttributes.MaxAmmo.Initialize(WeaponDefinition.Stats.Core.Magazine);

		ShootCooldown = 1.0 / WeaponDefinition.Stats.GetFireRate();
		RPM = WeaponDefinition.Stats.GetFireRate() * 60;

		UAbilitySystemComponent ASC = AbilitySystem::GetAbilitySystemComponent(OwningHero.PlayerState);
		if (GetOwner().HasAuthority())
			GrantAbilities(ASC);

		Ready();
	}

	UFUNCTION(Server)
	void GrantAbilities(UAbilitySystemComponent ASC)
	{
		ASC.GiveAbility(WeaponDefinition.FireGameplayAbility, 0, -1);
		ASC.GiveAbility(WeaponDefinition.ReloadGameplayAbility, 0, -1);
	}

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		TimeSinceLastShot += DeltaSeconds;

		// Assumes player has not fired for a while, reset recoil index
		if (TimeSinceLastShot > 0.4)
			RecoilIndex = 0;
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

		if (IsBulletProtected() && OwningHero.ResolveMovementState() == EPondMovementState::Still)
		{
			FVector FinalDirSansSpread = (AimDirection).GetSafeNormal();
			return FinalDirSansSpread;
		}

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
	EDrawDebugTrace DebugTrace = EDrawDebugTrace::None;
	float DebugTraceDuration = 1.0f;

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
								DebugTrace,
								Hit,
								true,
								FLinearColor::Red,
								FLinearColor::Green,
								DebugTraceDuration);

		Client_DrawDebugTargetPointTrace(TraceStart, TraceEnd, DebugTraceDuration);

		FVector TargetPoint = Hit.bBlockingHit ? Hit.Location : TraceEnd;
		return TargetPoint;
	}

	TArray<FHitResult> Hits;
	bool BlockingHit;
	TArray<EEnchantExecuteTrigger> SuccessfulConditions;

	TArray<FHitResult> Trace(float MaxDistance = 10000.0f, FBulletHit&out OutBulletHit = FBulletHit())
	{
		FVector AimDirection = (GetTargetPoint(MaxDistance) - TraceStart).GetSafeNormal();

		EPondMovementState State;

		FVector BulletDirection = ApplySpread(AimDirection, CurrentGun.GetSpread(OwningHero.ResolveMovementState()), SpreadData);

		FVector End = TraceStart + BulletDirection * MaxDistance;

		TArray<AActor> ActorsToIgnore;
		ActorsToIgnore.Add(GetOwner()); // guncomponent is attached to character

		// Perform spread trace (the point the bullet will hit)
		BlockingHit = System::LineTraceMulti(TraceStart,
											 End,
											 ETraceTypeQuery::TraceTypeQuery3,
											 false,
											 ActorsToIgnore,
											 DebugTrace,
											 Hits,
											 true, // doesn't ignore the owning actor!! (ignores this component)
											 FLinearColor::Yellow,
											 FLinearColor::Green,
											 DebugTraceDuration);

		Client_DrawDebugSpreadPointTrace(End, DebugTraceDuration);

		if (!BlockingHit)
		{
			Log("Trace did not hit anything!");
			ShootSFX();

			BulletHit = FBulletHit();
			BulletHit.ExecuteResults.Add(EEnchantExecuteTrigger::OnShot); // always onshot, even if we didnt hit anything
			return TArray<FHitResult>();
		}

		FHitResult LastHit = Hits.Last();

		auto Instigator = OwningHero.Controller;
		auto HitEnemy = Cast<AEnemyBase>(LastHit.Actor);
		bool WasEnemyHit = IsValid(HitEnemy);
		float Damage = WeaponDefinition.GetDamage();

		SuccessfulConditions.Empty();
		SuccessfulConditions.Add(EEnchantExecuteTrigger::OnShot);

		if (WasEnemyHit && !HitEnemy.Attributes.OnEnemyHit.IsBound())
			HitEnemy.Attributes.OnEnemyHit.AddUFunction(this, n"OnEnemyHit");

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

		BulletHit.ExecuteResults = SuccessfulConditions;

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
				BulletDirection,
				LastHit,
				OwningHero.Controller,
				OwningHero,
				TSubclassOf<UDamageType>(UDamageType));
		}

		OutBulletHit = BulletHit;
		return Hits;
	}

	UFUNCTION(Client, Unreliable)
	void Client_DrawDebugTargetPointTrace(FVector InStart, FVector InEnd, float InDuration = 1.0f)
	{
		FHitResult DummyHit;
		System::LineTraceSingle(
			InStart,
			InEnd,
			ETraceTypeQuery::TraceTypeQuery3,
			false,
			TArray<AActor>(),
			EDrawDebugTrace::ForDuration,
			DummyHit,
			true,
			FLinearColor::Red,
			FLinearColor::Green,
			InDuration);
	}

	UFUNCTION(Client, Unreliable)
	void Client_DrawDebugSpreadPointTrace(FVector SpreadEnd, float InDuration = 1.0f)
	{
		FVector Location;
		FRotator Rotation;
		OwningHero.Controller.GetPlayerViewPoint(Location, Rotation);
		FVector CameraLocation = Location;
		FVector CameraForward = Rotation.ForwardVector;

		FVector DebugTraceStart = CameraLocation;

		FHitResult DummyHit;
		System::LineTraceSingle(
			DebugTraceStart,
			SpreadEnd,
			ETraceTypeQuery::TraceTypeQuery3,
			false,
			TArray<AActor>(),
			EDrawDebugTrace::ForDuration,
			DummyHit,
			true,
			FLinearColor::Yellow,
			FLinearColor::Green,
			InDuration);
	}

	UFUNCTION(NotBlueprintCallable)
	private void OnEnemyHit(float DamageDealt, bool WasPrecision, bool Died)
	{
		if (Died && BulletHit.HitEnemy != nullptr)
			BulletHit.HitEnemy.Attributes.OnEnemyHit.Clear();

		if (DamageDealt > 0)
			SuccessfulConditions.Add(EEnchantExecuteTrigger::OnHit);
		if (Died)
			SuccessfulConditions.Add(EEnchantExecuteTrigger::OnKill);
		if (WasPrecision)
			SuccessfulConditions.Add(EEnchantExecuteTrigger::OnPrecisionHit);
		if (WasPrecision && Died)
			SuccessfulConditions.Add(EEnchantExecuteTrigger::OnPrecisionKill);

		bool bShouldLog = true;
		for (auto& Result : SuccessfulConditions)
		{
			if (IsValid(BulletHit.HitEnemy))
				LogIf(bShouldLog, n"Enchantments", f"Hit (\"{BulletHit.HitEnemy.ActorNameOrLabel}\") with condition \"{Result:n}\"");
		}

		auto ASC = AbilitySystem::GetAbilitySystemComponent(OwningHero.PlayerState);
		for (auto EnchantClass : CurrentGun.Enchantments)
		{
			auto AsWepEnchant = Cast<UWeaponEnchantment>(EnchantClass.DefaultObject);

			// if (!SuccessfulConditions.IsEmpty())
			//	Print(f"Attempting to activate (up to) {SuccessfulConditions.Num()} enchants!", 1.5f, FLinearColor::DPink);

			for (auto& Result : SuccessfulConditions)
			{
				if (Result == AsWepEnchant.Trigger)
				{
					auto Spec = FGameplayAbilitySpec(EnchantClass, 1, -1, nullptr);

					FGameplayEventData Payload;
					Payload.ContextHandle = ASC.MakeEffectContext();
					Payload.ContextHandle.AddHitResult(BulletHit.Hit, false);

					ASC.GiveAbilityAndActivateOnceWithEventData(Spec, Payload);
					Print(f"activating {AsWepEnchant.DisplayName}", 1.5f, FLinearColor(1.00, 0.07, 0.07));
				}
			}
		}
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
	 */
	UFUNCTION()
	bool Shoot(FBulletHit&out Hit)
	{
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
			Hits = Trace(10000.0f, Hit);

			RecoilIndex++;

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