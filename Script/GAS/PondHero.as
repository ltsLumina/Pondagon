enum EPondMovementState
{
	Still,
	Airborne,
	Crouch,
	Run,
	Walk,
	CrouchWalk
};

class APondHero : APondCharacter
{
	// Components
	UPROPERTY(DefaultComponent, Attach = "CharacterMesh0")
	USkeletalMeshComponent FirstPersonMesh;

	UPROPERTY(DefaultComponent, Attach = "FirstPersonMesh")
	UCameraComponent FirstPersonCamera;

	UPROPERTY(Category = "AS Components", BlueprintReadOnly)
	UGunComponent GunComponent;
	default GunComponent = UGunComponent::Get(this);
	//~Components

	// Details
	UPROPERTY(Category = "Player | Details")
	UEntityDefinition Definition;

	UPROPERTY(Category = "Player | Visuals")
	UParticleSystem DeathEffect;

	UPROPERTY(Category = "Player | Movement", VisibleInstanceOnly)
	EPondMovementState MovementState;
	default MovementState = EPondMovementState::Still;

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
	private APondPlayerState GetPondPlayerState() property
	{
		return Cast<APondPlayerState>(PlayerState);
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

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		GunComponent = UGunComponent::Get(this);
	}

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		Print(f"{MovementState=:n}", 0);
		Print(f"{PreviousMovementState=:n}", 0);
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
		MovementState = (MovementState != EPondMovementState::Still) ? MovementState : EPondMovementState::Run;

		// To Unreal Units (cm)
		const float ToUU = 100;
		float MoveSpeed = GunComponent.WeaponDefinition.GetMovementSpeed(MovementState, false) * ToUU;
		CharacterMovement.MaxWalkSpeed = MoveSpeed;
		CharacterMovement.MaxWalkSpeedCrouched = MoveSpeed;
	}

	UFUNCTION(NotBlueprintCallable)
	private void OnMove_Completed(FInputActionValue ActionValue, float32 ElapsedTime,
						  float32 TriggeredTime, const UInputAction SourceAction)
	{
		MovementState = EPondMovementState::Still;
	}

	bool CrouchFlag = false;

	UFUNCTION(NotBlueprintCallable)
	private void OnCrouch_Triggered(FInputActionValue ActionValue, float32 ElapsedTime,
							float32 TriggeredTime, const UInputAction SourceAction)
	{
		if (!CrouchFlag)
		{
			PreviousMovementState = MovementState;
			CrouchFlag = true;
		}

		MovementState = GetVelocity().IsNearlyZero() ? EPondMovementState::Crouch : EPondMovementState::CrouchWalk;
	}

	UFUNCTION(NotBlueprintCallable)
	private void OnCrouch_Cancelled(FInputActionValue ActionValue, float32 ElapsedTime,
							float32 TriggeredTime, const UInputAction SourceAction)
	{
		EndCurrentState();
	}

	UFUNCTION(NotBlueprintCallable)
	private void OnCrouch_Completed(FInputActionValue ActionValue, float32 ElapsedTime,
							float32 TriggeredTime, const UInputAction SourceAction)
	{
		EndCurrentState();
	}

	void EndCurrentState()
	{
		EPondMovementState LocalState = MovementState;
		MovementState = GetVelocity().IsNearlyZero() ? EPondMovementState::Still : (PreviousMovementState == EPondMovementState::Run ? EPondMovementState::Run : EPondMovementState::Still);
		PreviousMovementState = LocalState;

		CrouchFlag = false;
		PreviousMovementState = MovementState;
	}

	UFUNCTION(NotBlueprintCallable)
	private void OnJump_Started(FInputActionValue ActionValue, float32 ElapsedTime,
						float32 TriggeredTime, const UInputAction SourceAction)
	{
		MovementState = EPondMovementState::Airborne;
		PreviousMovementState = MovementState;
	}

	UFUNCTION(BlueprintOverride)
	void OnLanded(FHitResult Hit)
	{
		MovementState = EPondMovementState::Still;
	}
	// #endregion
};

namespace Pond
{
	UFUNCTION(BlueprintPure)
	APondHero GetPondHeroBase(APondCharacter PondCharacter)
	{
		return Cast<APondHero>(PondCharacter);
	}
}