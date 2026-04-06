enum EPondMovementState
{
	Still,
	Airborne,
	Crouch,
	Run,
	Walk,
	CrouchWalk
};

class APondHero : AScriptPondCharacter
{
	default bReplicates = true;
	default bReplicateMovement = true;

	// Components
	UPROPERTY(DefaultComponent, Attach = "CharacterMesh0")
	USkeletalMeshComponent FirstPersonMesh;

	UPROPERTY(DefaultComponent, Attach = "FirstPersonMesh")
	UCameraComponent FirstPersonCamera;

	UPROPERTY(Category = "AS Components", BlueprintReadOnly)
	UGunComponent GunComponent;
	default GunComponent = UGunComponent::Get(this);

	UFUNCTION(BlueprintOverride)
	void ConstructionScript()
	{
		GunComponent = UGunComponent::Get(this);
	}
	//~Components

	// Details
	UPROPERTY(Category = "Player | Details")
	UEntityDefinition Definition;

	UPROPERTY(Category = "Player | Visuals")
	UParticleSystem DeathEffect;

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
	//~Details

	// #region Attribute Getters
	UFUNCTION(BlueprintPure)
	float GetCurrentHealth() property
	{
		return Attributes.Health.CurrentValue;
	}

	UFUNCTION(BlueprintPure)
	float GetBaseHealth() property
	{
		return Attributes.Health.BaseValue;
	}

	UFUNCTION(BlueprintPure)
	float GetCurrentShield() property
	{
		return Attributes.Shield.CurrentValue;
	}

	UFUNCTION(BlueprintPure)
	float GetBaseShield() property
	{
		return Attributes.Shield.BaseValue;
	}
	// #endregion

	// #region Getter Helpers
	UFUNCTION(BlueprintPure, BlueprintProtected)
	private AScriptPondPlayerState GetPondPlayerState() property
	{
		return Cast<AScriptPondPlayerState>(PlayerState);
	}

	UFUNCTION(BlueprintPure)
	UAngelscriptAbilitySystemComponent GetAbilitySystem() property
	{
		return PondPlayerState.AbilitySystem;
	}

	UFUNCTION(BlueprintPure)
	UPlayerAttributes GetAttributes() property
	{
		return PondPlayerState.PlayerAttributes;
	}
	// #endregion

	bool PrintMoveState = false;
	bool HasInitialized = false;

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
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
		}
	}

	UFUNCTION()
	void Death()
	{
		if (AbilitySystem.HasGameplayTag(GameplayTags::Character_State_Dead))
			return;
		else
			AbilitySystem.AddLooseGameplayTag(GameplayTags::Character_State_Dead);

		FGameplayEffectQuery Query;
		for (FActiveGameplayEffectHandle Handle : AbilitySystem.GetActiveEffects(Query))
		{
			AbilitySystem.RemoveActiveGameplayEffect(Handle);
		}

		PrintWarning("Player died!");
		DestroyActor();
	}

	// #region Movement State Handling
	UFUNCTION(NotBlueprintCallable)
	private void OnMove_Triggered(FInputActionValue ActionValue, float32 ElapsedTime,
						  float32 TriggeredTime, const UInputAction SourceAction)
	{
	}

	UFUNCTION(NotBlueprintCallable)
	private void OnMove_Completed(FInputActionValue ActionValue, float32 ElapsedTime,
						  float32 TriggeredTime, const UInputAction SourceAction)
	{
	}

	UFUNCTION(NotBlueprintCallable)
	private void OnCrouch_Triggered(FInputActionValue ActionValue, float32 ElapsedTime,
							float32 TriggeredTime, const UInputAction SourceAction)
	{
	}

	UFUNCTION(NotBlueprintCallable)
	private void OnCrouch_Cancelled(FInputActionValue ActionValue, float32 ElapsedTime,
							float32 TriggeredTime, const UInputAction SourceAction)
	{
	}

	UFUNCTION(NotBlueprintCallable)
	private void OnCrouch_Completed(FInputActionValue ActionValue, float32 ElapsedTime,
							float32 TriggeredTime, const UInputAction SourceAction)
	{
	}

	UFUNCTION(NotBlueprintCallable)
	private void OnJump_Started(FInputActionValue ActionValue, float32 ElapsedTime,
						float32 TriggeredTime, const UInputAction SourceAction)
	{
	}
	// #endregion
};

namespace Pond
{
	UFUNCTION(BlueprintPure)
	APondHero GetPondHeroBase(AScriptPondCharacter PondCharacter)
	{
		return Cast<APondHero>(PondCharacter);
	}
}