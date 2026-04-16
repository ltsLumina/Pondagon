class UScriptPondCharacterMovementComponent : UPondCharacterMovementComponent
{
	UPROPERTY()
	float SprintSpeedMultiplier = 1.4f;

	UPROPERTY()
	float ADSSpeedMultiplier = 0.5f;

	AScriptPondCharacter Char;
	UWeaponDefinition Definition;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		Char = Cast<AScriptPondCharacter>(GetOwner());
	}

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		// Poll for weapon definition.

		UGunComponent GunComponent = UGunComponent::Get(GetOwner());
		if (!IsValid(GunComponent)) return;

		if (GunComponent.WeaponDefinition != nullptr)
		{
			Definition = UGunComponent::Get(GetOwner()).WeaponDefinition;
		}
	}

	UFUNCTION(BlueprintOverride)
	float BP_GetMaxSpeed() const
	{
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

		if (IsValid(Definition))
		{
			if (RequestToStartSprinting)
			{
				return Char.GetMoveSpeed() * Definition.SprintMoveSpeedRatio;
			}

			if (RequestToStartADS)
			{
				return Char.GetMoveSpeed() * Definition.AltMoveSpeedRatio;
			}
		}

		return Char.GetMoveSpeed();
	}

	UFUNCTION(BlueprintOverride)
	bool CanAttemptJump() const
	{
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