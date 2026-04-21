enum EPondMovementState
{
	Still,
	Airborne,
	Crouch,
	Run,
	Walk,
	CrouchWalk
};

class AScriptPondHero : AScriptPondCharacter
{
	default AbilitySystem.SetReplicationMode(EGameplayEffectReplicationMode::Mixed);

	// Components
	UPROPERTY(DefaultComponent, Attach = "CharacterMesh0")
	USkeletalMeshComponent FirstPersonMesh;

	UPROPERTY(DefaultComponent, Attach = "FirstPersonMesh")
	UCameraComponent FirstPersonCamera;

	UPROPERTY(Category = "AS Components", BlueprintReadOnly)
	UGunComponent GunComponent;
	default GunComponent = UGunComponent::Get(this);
	//~Components

	UPROPERTY(Category = "Input | Sensitivity", BlueprintReadOnly, Meta = (Units="x"))
	FVector2D Sensitivity = FVector2D(1,1);

	UFUNCTION()
	void SetSensitivity(FVector2D NewSensitivity)
	{
		Sensitivity = NewSensitivity;
	}

	FVector2D PreviousSens;

	UFUNCTION(Category = "Input | Sensitivity")
	void AdjustSensitivity(float Multiplier)
	{
		PreviousSens = Sensitivity;
		Sensitivity *= Multiplier;
	}

	UFUNCTION(Category = "Input | Sensitivity")
	void AdjustSensitivityAxis(float XMultiplier, float YMultiplier)
	{
		PreviousSens = Sensitivity;
		Sensitivity.X *= XMultiplier;
		Sensitivity.Y *= YMultiplier;
	}

	UFUNCTION(Category = "Input | Sensitivity")
	void RestoreSensitivity()
	{
		Sensitivity = PreviousSens;
	}

	UFUNCTION(BlueprintPure)
	EPondMovementState ResolveMovementState()
	{
		switch (CharacterMovement.MovementMode)
		{
			case EMovementMode::MOVE_Walking:
				// NOT MOVING
				if (CharacterMovement.Velocity.IsNearlyZero()) // TODO: maybe do IsWalkingOnGround()
				{
					if (CharacterMovement.IsCrouching())
					{
						return EPondMovementState::Crouch;
					}
					else
					{
						return EPondMovementState::Still;
					}
				}
				// IS MOVING
				else
				{
					if (CharacterMovement.IsCrouching())
					{
						return EPondMovementState::CrouchWalk;
					}
					else if (CharacterMovement.IsMovingOnGround())
					{
						return EPondMovementState::Run;
					}
				}
				break;

			case EMovementMode::MOVE_Falling:
			{
				// IS AIRBORNE
				if (CharacterMovement.IsFalling())
				{
					return EPondMovementState::Airborne;
				}
			}
			break;

			case EMovementMode::MOVE_None:
			case EMovementMode::MOVE_NavWalking:
			case EMovementMode::MOVE_Swimming:
			case EMovementMode::MOVE_Flying:
			case EMovementMode::MOVE_Custom:
			default:
				return EPondMovementState::Still;
		}

		return EPondMovementState::Still;
	}

	UPROPERTY(Category = "Player | Movement", VisibleInstanceOnly)
	EPondMovementState PreviousMovementState;
	default PreviousMovementState = EPondMovementState::Run;

	UFUNCTION(BlueprintOverride)
	void ConstructionScript()
	{
		Super::ConstructionScript();
		GunComponent = UGunComponent::Get(this);
	}

	UFUNCTION(BlueprintOverride)
	void Possessed(AController NewController)
	{
		AScriptPondPlayerState PS = Cast<AScriptPondPlayerState>(PlayerState);
		if (IsValid(PS))
		{
			// Set the ASC on the Server. Clients do this in OnRep_PlayerState()
			AbilitySystem = AbilitySystem::GetAngelscriptAbilitySystemComponent(PS);

			// AI won't have PlayerControllers so we can init again here just to be sure. No harm in initing twice for heroes that have PlayerControllers.
			AbilitySystem::GetAngelscriptAbilitySystemComponent(PS).InitAbilityActorInfo(PS, this);

			// Set the AttributeSet for convenience attribute functions
			Attributes = Cast<UPlayerAttributes>(AbilitySystem.RegisterAttributeSet(UPlayerAttributes));

			for (auto& Data : Definition.StartingData)
			{
				AbilitySystem.InitStats(Data.Key, Data.Value);
			}
		}

		// requires AbilitySystem ref
		Super::Possessed(NewController);
	}

	UFUNCTION(BlueprintOverride)
	void OnRep_PlayerState()
	{
		AScriptPondPlayerState PS = Cast<AScriptPondPlayerState>(PlayerState);
		if (IsValid(PS))
		{
			// Set the ASC for clients. Server does this in PossessedBy.
			AbilitySystem = AbilitySystem::GetAngelscriptAbilitySystemComponent(PS);

			// Init ASC Actor Info for clients. Server will init its ASC when it possesses a new Actor.
			AbilitySystem.InitAbilityActorInfo(PS, this);

			// Set the AttributeSet for convenience attribute functions
			Attributes = Cast<UPlayerAttributes>(AbilitySystem.RegisterAttributeSet(UPlayerAttributes));

			for (auto& Data : Definition.StartingData)
			{
				AbilitySystem.InitStats(Data.Key, Data.Value);
			}
		}
	}

	float TimeSinceMoving;
	bool PrintMoveState = false;
	bool HasInitialized = false;

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		if (ResolveMovementState() == EPondMovementState::Still)
		{
			TimeSinceMoving += DeltaSeconds;
		}
		else
			TimeSinceMoving = 0;

		if (PrintMoveState)
		{
			auto State = ResolveMovementState();
			Print(f"{State=:n}", 0);
			Print(f"{PreviousMovementState=:n}", 0);
		}

		if (PlayerState != nullptr && !HasInitialized)
		{
			GunComponent.Initialize();
			HasInitialized = true;

#if EDITOR
			float SpawnHealth = Health;
			float SpawnShield = Shield;
			Print(f"{ActorNameOrLabel} has spawned with {SpawnHealth} health and {SpawnShield} Shield.", 2.5f, FLinearColor::Green);
#endif
		}
	}

	// - Input Events

	UFUNCTION(NotBlueprintCallable)
    private void StartSprinting(FInputActionValue ActionValue, float32 ElapsedTime,
                                float32 TriggeredTime, const UInputAction SourceAction)
    {
		auto PondCharMove = Cast<UScriptPondCharacterMovementComponent>(CharacterMovement);
		PondCharMove.StartSprinting();
    }

	UFUNCTION(NotBlueprintCallable)
    private void StopSprinting(FInputActionValue ActionValue, float32 ElapsedTime,
                               float32 TriggeredTime, const UInputAction SourceAction)
    {
		auto PondCharMove = Cast<UScriptPondCharacterMovementComponent>(CharacterMovement);
		PondCharMove.StopSprinting();
    }
};

UFUNCTION(BlueprintPure)
mixin AScriptPondHero AsHero(AScriptPondCharacter PondCharacter)
{
	return Cast<AScriptPondHero>(PondCharacter);
}
