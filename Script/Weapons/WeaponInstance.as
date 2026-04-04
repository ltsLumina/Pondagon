class UWeaponInstance : UItemInstance
{
	UPROPERTY(Category = "Definition")
	UWeaponDefinition WeaponDefinition;

	/**
	 * The currently applied enchantments to this weapon.
	 */
	UPROPERTY(Category = "Enchantments")
	TArray<TSubclassOf<UEnchantment>> Enchantments;

	UPROPERTY(NotVisible, BlueprintReadOnly)
	APondCharacter OwningCharacter;

	UPROPERTY(NotVisible, BlueprintReadOnly)
	UGunComponent OwningGunComponent;

	UFUNCTION()
	void InitInstanceInfo(UWeaponDefinition InWeaponDefinition, AActor OwningActor, UActorComponent OwningComponent)
	{
		WeaponDefinition = InWeaponDefinition;
		OwningCharacter = Cast<APondCharacter>(OwningActor);
		OwningGunComponent = Cast<UGunComponent>(OwningComponent);
	}

	// - accuracy helpers

	UFUNCTION(BlueprintPure, Category = "Gun | Accuracy")
	float GetSpread(EPondMovementState MovementState)
	{
		float Spread;

		switch (MovementState)
		{
			case EPondMovementState::Still:
				Spread = WeaponDefinition.StandingSpread;
				break;
			case EPondMovementState::Airborne:
				Spread = WeaponDefinition.AirbornePenalty;
				break;
			case EPondMovementState::Crouch:
				Spread = WeaponDefinition.CrouchSpread;
				break;
			case EPondMovementState::Run:
				Spread = WeaponDefinition.RunPenalty;
				break;
			case EPondMovementState::Walk:
				Spread = WeaponDefinition.WalkPenalty;
				break;
			case EPondMovementState::CrouchWalk:
				Spread = WeaponDefinition.CrouchPenalty;
				break;
			default:
				Spread = WeaponDefinition.StandingSpread;
				break;
		}

		int RecoilIndex = OwningGunComponent.RecoilIndex;
		Spread += Math::Clamp(Math::Pow(RecoilIndex / 7.0f, 1.8f), 0.25f, 1.0f);

		Print(f"Spread: {Spread} degrees", 1, FLinearColor(0.5, 0.5, 1.0));
		return Spread;
	}

	// Enchanting

	UFUNCTION(Category = "Enchanting")
	bool AddEnchantment(TSubclassOf<UWeaponEnchantment> EnchantmentClass)
	{
		if (!Enchantments.AddUnique(EnchantmentClass))
		{
			PrintError("Cannot add enchantment! An existing one is already applied.");
			return false;
		}

		return true;
	}

	UFUNCTION(Category = "Enchanting")
	bool RemoveEnchantment(TSubclassOf<UEnchantment> EnchantClass)
	{
		if (Enchantments.Num() > 0)
		{
			Enchantments.Remove(EnchantClass);
			return true;
		}

		return false;
	}

	UFUNCTION(Category = "Enchanting")
	bool ReplaceEnchantment(UEnchantment EnchantToReplace, UEnchantment NewEnchant)
	{
		if (!IsValid(EnchantToReplace) || !IsValid(NewEnchant))
		{
			throw("Input parameters are null.");
			return false;
		}

		for (auto& AppliedEnchantment : Enchantments)
		{
			//if (AppliedEnchantment == EnchantToReplace)
			{
			//	AppliedEnchantment = Cast<UEnchantment>(NewEnchant);
		//		return true;
			}
		}

		return false;
	}
}