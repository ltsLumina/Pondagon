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

	bool PrintMoveState = false;
	bool HasInitialized = false;

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		Super::Tick(DeltaSeconds);
		
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

	UFUNCTION()
	void Stun()
	{
		AbilitySystem.AddLooseGameplayTag(GameplayTags::Character_State_Stunned);
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