class UWeaponInstance : UItemInstance
{
	UPROPERTY(Category = "Definition")
	UWeaponDefinition WeaponDefinition;

	/**
	 * The currently applied enchantments to this weapon.
	 */
	UPROPERTY(Category = "Enchantments")
	TArray<UEnchantment> Enchantments;

	UPROPERTY(NotVisible, BlueprintReadOnly)
	APondCharacter OwningCharacter;

	UPROPERTY(NotVisible, BlueprintReadOnly)
	UGunComponent OwningGunComponent;

	// - accuracy helpers

	UFUNCTION(BlueprintPure, Category = "Gun | Accuracy")
	float GetSpread(EPondMovementState MovementState)
	{
		float Spread;

		switch (MoveState)
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
		Spread = Math::Clamp(Math::Pow(RecoilIndex / 7.0f, 1.8f), 0.25f, 1.0f);

		Print(f"Spread: {Spread} degrees", 1, FLinearColor(0.5, 0.5, 1.0));
		return Spread;
	}

	// Enchanting

	UFUNCTION(Category = "Enchanting")
	bool AddEnchantment(TSubclassOf<UWeaponEnchantment> ChipClass)
	{
		auto ModInst = NewObject(this, ChipClass);

		if (!Enchantments.AddUnique(ModInst))
		{
			PrintError("Cannot add mod! An existing one is already applied.");
			return false;
		}

		switch (ModInst.ExecuteCondition)
		{
			case EEnchantmentCondition::OnFire:
				OwningGunComponent.OnFire.AddUFunction(ModInst, n"OnShot");
				break;
			case EEnchantmentCondition::OnHit:
				OwningGunComponent.OnFire.AddUFunction(ModInst, n"OnHit");
				break;
			case EEnchantmentCondition::OnKill:
				OwningGunComponent.OnKill.AddUFunction(ModInst, n"OnKill");
				break;
			case EEnchantmentCondition::OnPrecisionHit:
				OwningGunComponent.OnPrecisionHit.AddUFunction(ModInst, n"OnPrecisionHit");
				break;
			case EEnchantmentCondition::OnPrecisionKill:
				OwningGunComponent.OnPrecisionKill.AddUFunction(ModInst, n"OnPrecisionKill");
				break;
			case EEnchantmentCondition::OnLastBullet:
				OwningGunComponent.OnFire.AddUFunction(ModInst, n"OnLastBullet");
				break;
			case EEnchantmentCondition::OnReload:
				OwningGunComponent.OnReload.AddUFunction(ModInst, n"OnReload");
				break;
			case EEnchantmentCondition::OnShieldDepletion:
				break;

			default:
				PrintError(f"No Enchantment Execute Condition found on {ModInst.DisplayName}!");
				break;
		}

		return true;
	}

	UFUNCTION(Category = "Enchanting")
	bool RemoveEnchantment(UEnchantment Enchant)
	{
		if (Enchantments.Num() > 0)
		{
			Enchantments.Remove(Cast<UEnchantment>(Enchant));
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
			if (AppliedEnchantment == EnchantToReplace)
			{
				AppliedEnchantment = Cast<UEnchantment>(NewEnchant);
				return true;
			}
		}

		return false;
	}
}