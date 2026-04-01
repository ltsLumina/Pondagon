class UInventoryComponent : UActorComponent
{	
	UPROPERTY()
	TArray<UItemInstance> Backpack;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		auto Player = Gameplay::GetPlayerCharacter(0);
		if (!IsValid(Player)) return;
		auto GunComponent = UGunComponent::Get(Player);

		check(Player != nullptr);
		check(GunComponent != nullptr);
		check(GunComponent.DefaultGun != nullptr, "Default Gun is nullptr! Assign it in the Hero's GunComponent.");
		
		AddWeapon(GunComponent.DefaultGun);
	}

	UFUNCTION()
	UItemInstance AddItem(UItemDefinition ItemDef, int Amount = 1)
	{
		auto Instance = NewObject(this, UItemInstance, FName(f"{ItemDef.DisplayName}"));

		Instance.Definition = ItemDef;
		Instance.Count = Amount;

		return Instance;
	}

	UFUNCTION()
	UWeaponInstance AddWeapon(UWeaponDefinition WeaponDef)
	{
		auto Instance = NewObject(this, UWeaponInstance, FName(f"{WeaponDef.ItemDefinition.DisplayName}"));

		Instance.WeaponDefinition = WeaponDef;
		Instance.Count = 1;

		// Owner Initialization
		APondCharacter OwningCharacter = Cast<APondCharacter>(Gameplay::GetPlayerCharacter(0));
		auto GunComponent = UGunComponent::Get(OwningCharacter);

		Instance.OwningCharacter = OwningCharacter;
		Instance.OwningGunComponent = GunComponent;

		// Assign as gun to GunComponent
		GunComponent.CurrentGun = Instance;

		Backpack.Add(Instance);
		return Instance;
	}

	/**
	 * @param WeaponDef The definition of which gun to create an instance of.
	 * @param AttachedMods Array of mods to attach when the gun is added.
	 */
	UFUNCTION(DisplayName = "Add Weapon (w/ Mods)")
	UWeaponInstance AddWeaponWithMods(UWeaponDefinition WeaponDef, TArray<TSubclassOf<UUniversalChipMod>> Chips)
	{
		auto Instance = NewObject(this, UWeaponInstance, FName(f"{WeaponDef.ItemDefinition.DisplayName}"));

		Instance.WeaponDefinition = WeaponDef;
		Instance.Count = 1;

		for (auto Mod : Chips)
		{
			if (!IsValid(Mod))
				continue;

			Instance.AddChip(Mod);
		}

		return Instance;
	}
};