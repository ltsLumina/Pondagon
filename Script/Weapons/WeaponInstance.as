class UWeaponInstance : UItemInstance
{
	UPROPERTY(Category = "Definition")
	UWeaponDefinition WeaponDefinition;

	UPROPERTY(Category = "Mods")
	TArray<UUniversalChipMod> Mods;

	UPROPERTY(NotVisible, BlueprintReadOnly)
	APondCharacter OwningCharacter;

	UPROPERTY(NotVisible, BlueprintReadOnly)
	UGunComponent OwningGunComponent;

	// - accuracy helpers

	UFUNCTION(BlueprintPure, Category = "Gun | Accuracy")
	float GetSpread()
	{
		EPondMovementState MoveState = Pond::GetPondHeroBase(OwningCharacter).MovementState;
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

		int RecoilIndex = UGunComponent::Get(Pond::GetPondCharacterBase(OwningCharacter)).RecoilIndex;
		Spread = Math::Clamp(Math::Pow(RecoilIndex / 7.0f, 1.8f), 0.25f, 1.0f);

		Print(f"Spread: {Spread} degrees", 1, FLinearColor(0.5, 0.5, 1.0));
		return Spread;
	}

	UFUNCTION()
	bool AddChip(TSubclassOf<UUniversalChipMod> ChipClass)
	{
		auto ModInst = NewObject(this, ChipClass);

		if (!Mods.AddUnique(ModInst))
		{
			PrintError("Cannot add mod! An existing one is already applied.");
			return false;
		}

		OwningGunComponent.OnFire.AddUFunction(ModInst, n"UpdateHit");
		OwningGunComponent.OnReload.AddUFunction(ModInst, n"UpdateState");

		switch (ModInst.ExecuteCondition)
		{
			case EChipExecuteCondition::OnFire:
				OwningGunComponent.OnFire.AddUFunction(ModInst, n"OnShot");
				break;
			case EChipExecuteCondition::OnHit:
				OwningGunComponent.OnFire.AddUFunction(ModInst, n"OnHit");
				break;
			case EChipExecuteCondition::OnKill:
				OwningGunComponent.OnKill.AddUFunction(ModInst, n"OnKill");
				break;
			case EChipExecuteCondition::OnPrecisionHit:
				OwningGunComponent.OnPrecisionHit.AddUFunction(ModInst, n"OnPrecisionHit");
				break;
			case EChipExecuteCondition::OnPrecisionKill:
				OwningGunComponent.OnPrecisionKill.AddUFunction(ModInst, n"OnPrecisionKill");
				break;
			case EChipExecuteCondition::OnLastBullet:
				OwningGunComponent.OnFire.AddUFunction(ModInst, n"OnLastBullet");
				break;
			case EChipExecuteCondition::OnReload:
				OwningGunComponent.OnReload.AddUFunction(ModInst, n"OnReload");
				break;
			case EChipExecuteCondition::OnShieldDepletion:
				break;
		}

		return true;
	}

	UFUNCTION()
	bool RemoveMod(UWeaponMod Mod)
	{
		if (Mods.Num() > 0)
		{
			Mods.Remove(Cast<UUniversalChipMod>(Mod));
			return true;
		}

		return false;
	}

	UFUNCTION()
	bool ReplaceMod(UWeaponMod ModToReplace, UWeaponMod Mod)
	{
		if (!IsValid(ModToReplace) || !IsValid(Mod))
		{
			throw("Input paramters are null.");
			return false;
		}

		for (auto& EquippedMod : Mods)
		{
			if (EquippedMod == ModToReplace)
			{
				EquippedMod = Cast<UUniversalChipMod>(Mod);
				return true;
			}
		}

		return false;
	}
}