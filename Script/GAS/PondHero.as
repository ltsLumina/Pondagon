enum EPondMovementState
{
	Still,
	Airborne,
	Crouch,
	Run,
	Walk,
	CrouchWalk
};

class APondHero : APondCharacter
{
	// Components
	UPROPERTY(DefaultComponent, Attach = "CharacterMesh0")
	USkeletalMeshComponent FirstPersonMesh;

	UPROPERTY(DefaultComponent, Attach = "FirstPersonMesh")
	UCameraComponent FirstPersonCamera;

	UPROPERTY(Category = "AS Components", BlueprintReadOnly)
	UGunComponent GunComponent;
	default GunComponent = UGunComponent::Get(this);
	//~Components

	// Details
	UPROPERTY(Category = "Player | Visuals")
	UParticleSystem DeathEffect;

	UPROPERTY(Category = "Player | Movement", VisibleInstanceOnly)
	EPondMovementState MovementState;
	default MovementState = EPondMovementState::Still;

	UPROPERTY(Category = "Player | Movement", VisibleInstanceOnly)
	EPondMovementState PreviousMovementState;
	default PreviousMovementState = EPondMovementState::Run;

	UPROPERTY(Category = "Character", VisibleInstanceOnly, BlueprintReadOnly)
	FDeathContext DeathContext;
	//~Details

	// #region Attribute Getters
	UFUNCTION(BlueprintPure)
	float GetCurrentHealth() property
	{
		return Attributes.Health.CurrentValue;
	}

	UFUNCTION(BlueprintPure)
	float GetBaseHealth() property
	{
		return Attributes.Health.BaseValue;
	}

	UFUNCTION(BlueprintPure)
	float GetCurrentShield() property
	{
		return Attributes.Shield.CurrentValue;
	}

	UFUNCTION(BlueprintPure)
	float GetBaseShield() property
	{
		return Attributes.Shield.BaseValue;
	}
	// #endregion

	// #region Getter Helpers
	UFUNCTION(BlueprintPure, BlueprintProtected)
	private APondPlayerState GetPondPlayerState() property
	{
		return Pond::GetPondPlayerStateBase();
	}

	UFUNCTION(BlueprintPure)
	UAngelscriptAbilitySystemComponent GetAbilitySystem() property
	{
		return PondPlayerState.AbilitySystem;
	}

	UFUNCTION(BlueprintPure)
	UPondPlayerGASAttributes GetAttributes() property
	{
		return PondPlayerState.Attributes;
	}
	// #endregion

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

		PrintWarning("Player died!");
		DestroyActor();
	}
};

namespace Pond
{
	UFUNCTION(BlueprintPure)
	APondHero GetPondHeroBase(APondCharacter PondCharacter)
	{
		return Cast<APondHero>(PondCharacter);
	}
}