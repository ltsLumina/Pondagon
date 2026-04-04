enum ERarity
{
	Standard,  // Common
	Enhanced,  // Uncommon
	Deluxe,    // Rare
	Superior,  // Epic
	Prestige,  // Legendary
	Contraband // Mythic
}

enum EExecuteCondition
{
	OnShot,
	OnHit,
	OnKill,
	OnPrecisionHit,
	OnPrecisionKill,
	OnLastBullet,
	OnReload,
	OnShieldDepletion,
	NONE,
}

UCLASS(Abstract, HideDropdown, NotBlueprintable, Meta = (PrioritizeCategories = "Display"))
class UEnchantment : UGameplayAbility
{
	UPROPERTY(Category = "Display")
	FText DisplayName;

	UPROPERTY(Category = "Display", Meta = (Multiline))
	FText Description;

	UPROPERTY(Category = "Display")
	UTexture2D Icon;

	UPROPERTY(Category = "Display")
	ERarity Rarity;

	UPROPERTY(BlueprintReadOnly, DisplayName = "ASC (Ability System Component)", BlueprintGetter = "GetAngelscriptAbilitySystemComponent")
	protected UAngelscriptAbilitySystemComponent AbilitySystem;

	UFUNCTION(BlueprintPure)
	protected UAngelscriptAbilitySystemComponent GetAngelscriptAbilitySystemComponent()
	{
		ThrowIf(!IsValid(AbilitySystemComponentFromActorInfo), "AbilitySystemComponent in ActorInfo is nullptr!");
		return Cast<UAngelscriptAbilitySystemComponent>(AbilitySystemComponentFromActorInfo);
	}

	protected UAngelscriptAbilitySystemComponent GetASC() property
	{
		return GetAngelscriptAbilitySystemComponent();
	}
}

////// BASE CLASSES ///////

UCLASS(HideDropdown)
class UWeaponEnchantment : UEnchantment
{
	UPROPERTY(Category = "Enchantment")
	EExecuteCondition ExecuteCondition;
}