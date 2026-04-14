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
	AScriptPondCharacter OwningCharacter;

	UPROPERTY(NotVisible, BlueprintReadOnly)
	UGunComponent OwningGunComponent;

	UFUNCTION()
	void InitInstanceInfo(UWeaponDefinition InWeaponDefinition, AActor OwningActor, UActorComponent OwningComponent)
	{
		WeaponDefinition = InWeaponDefinition;
		OwningCharacter = Cast<AScriptPondCharacter>(OwningActor);
		OwningGunComponent = Cast<UGunComponent>(OwningComponent);
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