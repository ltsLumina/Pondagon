enum ERarity
{
	Standard,  // Common
	Enhanced,  // Uncommon
	Deluxe,    // Rare
	Superior,  // Epic
	Prestige,  // Legendary
	Contraband // Mythic
}


enum EEnchantmentCondition
{
	OnFire,
	OnHit,
	OnKill,
	OnPrecisionHit,
	OnPrecisionKill,
	OnLastBullet,
	OnReload,
	OnShieldDepletion,
}

UCLASS(Abstract, HideDropdown, NotBlueprintable, Meta = (PrioritizeCategories = "Display"))
class UEnchantment : UDataAsset
{
	UPROPERTY(Category = "Display")
	FText DisplayName;

	UPROPERTY(Category = "Display", Meta = (Multiline))
	FText Description;

	UPROPERTY(Category = "Display")
	UTexture2D Icon;

	UPROPERTY(Category = "Display")
	ERarity Rarity;
}

////// BASE CLASSES ///////

UCLASS(HideDropdown)
class UWeaponEnchantment : UEnchantment
{
	UPROPERTY(Category = "Enchantment")
	EEnchantmentCondition ExecuteCondition;

	UFUNCTION(BlueprintEvent)
	protected void Apply(FBulletHit InHit, FMagazineState InState)
	{}

	UFUNCTION(BlueprintEvent, DisplayName = "Shot")
	protected void OnShot(FBulletHit InHit)
	{}

	UFUNCTION(BlueprintEvent, DisplayName = "Hit")
	protected void OnHit(FBulletHit InHit)
	{}

	UFUNCTION(BlueprintEvent, DisplayName = "Kill")
	protected void OnKill(FBulletHit InHit)
	{}

	UFUNCTION(BlueprintEvent, DisplayName = "Precision Hit")
	protected void OnPrecisionHit(FBulletHit InHit)
	{}

	UFUNCTION(BlueprintEvent, DisplayName = "Precision Kill")
	protected void OnPrecisionKill(FBulletHit InHit)
	{}

	UFUNCTION(BlueprintEvent, DisplayName = "Last Bullet")
	protected void OnLastBullet(FBulletHit InHit)
	{}

	UFUNCTION(BlueprintEvent, DisplayName = "Reload")
	protected void OnReload(FMagazineState InState)
	{}

	UFUNCTION(BlueprintEvent)
	protected void OnShieldDepletion()
	{}

	// Helpers

	UFUNCTION(NotBlueprintCallable)
	private void UpdateHit(FBulletHit InHit)
	{
		Hit = InHit;
	}

	UFUNCTION(NotBlueprintCallable)
	private void UpdateState(FMagazineState InState)
	{
		State = InState;
	}
}