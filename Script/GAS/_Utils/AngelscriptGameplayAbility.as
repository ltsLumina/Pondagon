UCLASS(Abstract, HideDropdown)
class UAngelscriptGameplayAbility : UGameplayAbility
{
    UPROPERTY(BlueprintReadOnly, DisplayName = "ASC (Ability System Component)", BlueprintGetter = "GetAngelscriptAbilitySystemComponent")
	protected UAngelscriptAbilitySystemComponent AbilitySystem;

	UFUNCTION(BlueprintPure)
	protected UAngelscriptAbilitySystemComponent GetAngelscriptAbilitySystemComponent()
	{
		ThrowIf(!IsValid(AbilitySystemComponentFromActorInfo), "AbilitySystemComponent in ActorInfo is nullptr!");
		return Cast<UAngelscriptAbilitySystemComponent>(AbilitySystemComponentFromActorInfo);
	}
};