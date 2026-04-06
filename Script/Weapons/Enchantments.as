enum ERarity
{
	Standard,  // Common
	Enhanced,  // Uncommon
	Deluxe,	   // Rare
	Superior,  // Epic
	Prestige,  // Legendary
	Contraband // Mythic
}

enum EEnchantExecuteTrigger
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

UCLASS(Abstract, HideDropdown, NotBlueprintable, Meta = (PrioritizeCategories = "Enchantment | Display", "Enchantment | Spec"))
class UEnchantment : UGameplayAbility
{
	// Enchantments are always server authoritative and called as a result of a gameplay ability. Therefore, they are marked as ServerOnly.
	default NetSecurityPolicy = EGameplayAbilityNetSecurityPolicy::ServerOnly;

	UPROPERTY(Category = "Enchantment | Display")
	FText DisplayName;

	UPROPERTY(Category = "Enchantment | Display", Meta = (Multiline))
	FText Description;

	UPROPERTY(Category = "Enchantment | Display")
	UTexture2D Icon;

	UPROPERTY(Category = "Enchantment | Display")
	ERarity Rarity;

	UPROPERTY(Category = "Enchantment | Execution")
	EEnchantExecuteTrigger Trigger;

	/**
	 * List of triggers to execute as a result of this enchantment activating.
	 */
	UPROPERTY(Category = "Enchantment | Execution")
	TArray<EEnchantExecuteTrigger> Triggers;

	/**
	 * Does this ability deal damage?
	 * If true, a SetByCaller tag (SetByCaller.Damage) will be set to the value of damage.
	 */
	UPROPERTY(Category = "Enchantment | Spec", Meta = (InlineEditConditionToggle))
	bool bDealsDamage;

	/**
	 * GameplayEffect that performs damage calculation and applies damage.
	 */
	UPROPERTY(Category = "Enchantment | Spec", Meta = (EditCondition = "bDealsDamage"))
	TSubclassOf<UGameplayEffect> DamageEffectClass;

	/**
	 * Float magnitude of damage to deal.
	 */
	UPROPERTY(Category = "Enchantment | Spec", Meta = (EditCondition = "DamageEffectClass != nullptr && bDealsDamage", EditConditionHides))
	float Damage;

	/**
	 * FGameplayEffectSpecHandle which is initialized after ability has been committed (only if bDealsDamage == true).
	 * Use this whenever you need to manage the damage spec.
	 */
	UPROPERTY(Category = "Enchantment | Spec", NotVisible, BlueprintReadOnly)
	protected FGameplayEffectSpecHandle DamageEffectHandle;

	UPROPERTY(BlueprintReadOnly, DisplayName = "ASC (Ability System Component)", BlueprintGetter = "GetAngelscriptAbilitySystemComponent")
	protected UAngelscriptAbilitySystemComponent AbilitySystem;

	UFUNCTION(BlueprintOverride)
	void CommitExecute()
	{
		if (!bDealsDamage) return;

		DamageEffectHandle = MakeOutgoingGameplayEffectSpec(DamageEffectClass, 1);
		DamageEffectHandle.Spec.SetByCallerMagnitude(GameplayTags::SetByCaller_Damage, Damage);
	}

	UFUNCTION(BlueprintOverride)
	void OnEndAbility(bool bWasCancelled)
	{	
		if (bWasCancelled)
			return;

		// if the ability ended naturally and expectantly

		auto PS = ASC.AbilityActorInfo.OwnerActor;
		auto Char = Cast<APlayerState>(PS).Pawn;

		auto GunComp = UGunComponent::Get(Char);
		for (auto& Enchant : GunComp.CurrentGun.Enchantments)
		{
			for (auto& InTrigger : Triggers)
			{
				if (Cast<UWeaponEnchantment>(Enchant.DefaultObject).Trigger == InTrigger)
				{
					Log(f"Enchant '{DisplayName}' is invoking '{Enchant.DefaultObject.DisplayName}'");
					GunComp.InvokeEnchantment(Enchant);
				}
			}
		}
		
	}

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

UCLASS(HideDropdown)
class UWeaponEnchantment : UEnchantment
{
	
}