class UScriptPondCharacterMovementComponent : UPondCharacterMovementComponent
{
	UPROPERTY()
	float SprintSpeedMultiplier = 1.4f;

	UPROPERTY()
	float ADSSpeedMultiplier = 0.5f;

	UFUNCTION(BlueprintOverride)
	float BP_GetMaxSpeed() const
	{		
		AScriptPondCharacter Char = Cast<AScriptPondCharacter>(GetOwner());
		if (!IsValid(Char))
		{
			throw(f"No owner found on '{GetOwner().ActorNameOrLabel}'");
			return GetMaxSpeed();
		}

		if (!Char.IsAlive)
		{
			return 0.0f;
		}

		if (Char.AbilitySystem.HasGameplayTag(GameplayTags::Character_State_Stunned))
		{
			return 0.0f;
		}

		if (RequestToStartSprinting)
		{
			return Char.GetMoveSpeed() * SprintSpeedMultiplier;
		}

		if (RequestToStartADS)
		{
			return Char.GetMoveSpeed() * ADSSpeedMultiplier;
		}

		return Char.GetMoveSpeed();
	}

	UFUNCTION(BlueprintOverride)
	bool CanAttemptJump() const
	{
		AScriptPondCharacter Char = Cast<AScriptPondCharacter>(GetOwner());
		if (!IsValid(Char))
		{
			throw(f"No owner found on '{GetOwner().ActorNameOrLabel}'");
			return false;
		}

		if (!Char.IsAlive)
		{
			return false;
		}

		if (Char.AbilitySystem.HasGameplayTag(GameplayTags::Character_State_Stunned))
		{
			return false;
		}

		return true;
	}
}