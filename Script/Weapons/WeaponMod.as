UCLASS(Abstract, HideDropdown, NotBlueprintable, Meta = (PrioritizeCategories = "Display"))
class UWeaponMod : UDataAsset
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

enum ERarity
{
	Standard,
	Enhanced,
	Deluxe,
	Superior,
	Prestige,
	Contraband
}

////// BASE CLASSES ///////

UCLASS(HideDropdown)
class UUniversalChipMod : UWeaponMod
{
	UPROPERTY(Category = "Chip")
	EChipExecuteCondition ExecuteCondition;

	UPROPERTY(NotVisible, BlueprintReadOnly)
	FBulletHit Hit;

	UPROPERTY(NotVisible, BlueprintReadOnly)
	FMagazineState State;

	UFUNCTION(BlueprintEvent)
	protected void Apply(FBulletHit InHit, FMagazineState InState)
	{
	}

	UFUNCTION(BlueprintEvent, DisplayName = "Shot")
	protected void OnShot(FBulletHit InHit)
	{
	}

	UFUNCTION(BlueprintEvent, DisplayName = "Hit")
	protected void OnHit(FBulletHit InHit)
	{
	}

	UFUNCTION(BlueprintEvent, DisplayName = "Kill")
	protected void OnKill(FBulletHit InHit)
	{
	}

	UFUNCTION(BlueprintEvent, DisplayName = "Precision Hit")
	protected void OnPrecisionHit(FBulletHit InHit)
	{
	}

	UFUNCTION(BlueprintEvent, DisplayName = "Precision Kill")
	protected void OnPrecisionKill(FBulletHit InHit)
	{
	}

	UFUNCTION(BlueprintEvent, DisplayName = "Last Bullet")
	protected void OnLastBullet(FBulletHit InHit)
	{
	}

	UFUNCTION(BlueprintEvent, DisplayName = "Reload")
	protected void OnReload(FMagazineState InState)
	{
	}

	UFUNCTION(BlueprintEvent)
	protected void OnShieldDepletion()
	{
	}

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

enum EChipExecuteCondition
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