UCLASS(Abstract, Meta=(PrioritizeCategories="Entity"))
class AScriptPondCharacter : APondCharacter
{
	default bReplicates = true;
	default bReplicateMovement = true;

	UPROPERTY(Category = "Entity", EditDefaultsOnly)
	UEntityDefinition Definition;

	UPROPERTY(Category = "Entity", VisibleInstanceOnly)
	UAngelscriptAttributeSet Attributes;

	// #region Attribute Getters
	UFUNCTION(BlueprintPure)
	float GetHealth() property
	{
		float32 Result = 0;
		AbilitySystem.TryGetAttributeCurrentValue(Attributes.Class, n"Health", Result);
		return Result;
	}

	UFUNCTION(BlueprintPure)
	float GetShield() property
	{
		float32 Result = 0;
		AbilitySystem.TryGetAttributeCurrentValue(Attributes.Class, n"Shield", Result);
		return Result;
	}

	UFUNCTION(BlueprintPure)
	float GetMoveSpeed() property
	{
		float32 Result = 0;
		AbilitySystem.TryGetAttributeCurrentValue(Attributes.Class, n"MoveSpeed", Result);
		return Result;
	}
	// #endregion

	// #region
	UFUNCTION(BlueprintPure)
	bool GetIsAlive() property
	{
		return Health > 0;
	}
	// #endregion

	UFUNCTION(BlueprintOverride)
	void ConstructionScript()
	{
		check(Cast<UScriptPondCharacterMovementComponent>(CharacterMovement) != nullptr, f"CharacterMovementComponent on {GetName()} was an incorrect type!" + "\n(Expected: UScriptPondCharacterMovementComponent | Actual: {CharacterMovement.GetName()})");
	}

	UFUNCTION()
	void Death()
	{
		if (AbilitySystem.HasGameplayTag(GameplayTags::Character_State_Dead))
			return;
		else
			AbilitySystem.AddLooseGameplayTag(GameplayTags::Character_State_Dead);

		FGameplayEffectQuery Query;
		for (FActiveGameplayEffectHandle Handle : AbilitySystem.GetActiveEffects(Query))
		{
			AbilitySystem.RemoveActiveGameplayEffect(Handle);
		}

		PrintWarning(f"{ActorNameOrLabel} died!");
		DestroyActor();
	}
}

namespace Pond
{
	UFUNCTION(BlueprintPure)
	AScriptPondCharacter GetPondCharacterBase(AActor Actor)
	{
		return Cast<AScriptPondCharacter>(Actor);
	}
}