UCLASS(Abstract)
class AScriptPondCharacter : APondCharacter
{
	default bReplicates = true;
	default bReplicateMovement = true;

	UPROPERTY(Category = "AS Components")
	UAngelscriptAbilitySystemComponent AbilitySystem;

	UPlayerAttributes Attributes;

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
	float GetHealth() property
	{
		return Attributes.Health.CurrentValue;
	}

	UFUNCTION(BlueprintPure)
	float GetShield() property
	{
		return Attributes.Shield.CurrentValue;
	}

	UFUNCTION(BlueprintPure)
	float GetMoveSpeed() property
	{
		return Attributes.MoveSpeed.CurrentValue;
	}
	// #endregion

	// #region
	UFUNCTION(BlueprintPure)
	bool GetIsAlive() property
	{
		return Attributes.Health.CurrentValue > 0;
	}
	// #endregion

	UFUNCTION(BlueprintOverride)
	void ConstructionScript()
	{
		check(Cast<UScriptPondCharacterMovementComponent>(CharacterMovement) != nullptr, f"CharacterMovementComponent on {GetName()} was an incorrect type!" 
																								+ "\n(Expected: UScriptPondCharacterMovementComponent | Actual: {CharacterMovement.GetName()})");
	}

	float TimeSinceMoving;

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		if (ResolveMovementState() == EPondMovementState::Still)
		{
			TimeSinceMoving += DeltaSeconds;
		}
		else TimeSinceMoving = 0;
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
}

namespace Pond
{
	UFUNCTION(BlueprintPure)
	AScriptPondCharacter GetPondCharacterBase(AActor Actor)
	{
		return Cast<AScriptPondCharacter>(Actor);
	}
}