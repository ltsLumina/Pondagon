class UInventoryComponent : UActorComponent
{	
	UPROPERTY()
	TArray<UItemInstance> Backpack;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		auto PS = Cast<APlayerState>(GetOwner());
		auto Player = PS.Pawn;
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

	/**
	 *  @TODO Rename to SetWeapon, since this doesn't add *another* weapon to the inventory -- it replaces the current one.
	 */
	UFUNCTION()
	UWeaponInstance AddWeapon(UWeaponDefinition WeaponDef)
	{
		auto Instance = NewObject(this, UWeaponInstance, FName(f"{WeaponDef.ItemDefinition.DisplayName}"));
		Instance.Count = 1;

		// Owner Initialization
		auto PS = Cast<APlayerState>(GetOwner());
		if (!IsValid(PS) || !IsValid(PS.Pawn)) return nullptr;
		
		APondCharacter OwningCharacter = Cast<APondCharacter>(PS.Pawn);
		auto GunComponent = UGunComponent::Get(OwningCharacter);

		// Initialize the instance
		Instance.InitInstanceInfo(WeaponDef, OwningCharacter, GunComponent);

		// Register to GunComponent
		GunComponent.RegisterCurrentGun(Instance);

		Backpack.Add(Instance);
		return Instance;
	}

	/**
	 * @param WeaponDef The definition of which gun to create an instance of.
	 * @param AttachedEnchantments Array of Enchantments to attach when the gun is added.
	 */
	UFUNCTION(DisplayName = "Add Weapon (w/ Enchantments)")
	UWeaponInstance AddWeaponWithEnchantments(UWeaponDefinition WeaponDef, TArray<TSubclassOf<UWeaponEnchantment>> Enchantments)
	{
		auto Instance = AddWeapon(WeaponDef);
		if (!IsValid(Instance)) return nullptr;

		for (auto Mod : Enchantments)
		{
			if (!IsValid(Mod))
				continue;

			Instance.AddEnchantment(Mod);
		}

		return Instance;
	}
};