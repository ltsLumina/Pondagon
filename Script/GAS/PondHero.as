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
	UPROPERTY(DefaultComponent, Attach = "CharacterMesh0")
	USkeletalMeshComponent FirstPersonMesh;

	UPROPERTY(DefaultComponent, Attach = "FirstPersonMesh")
	UCameraComponent FirstPersonCamera;
	
	UPROPERTY(Category = "AS Components", BlueprintReadOnly)
	UGunComponent GunComponent;
	default GunComponent = UGunComponent::Get(this);

	UPROPERTY(Category = "Player", VisibleAnywhere)
	EPondMovementState MovementState;
	default MovementState = EPondMovementState::Still;

	UPROPERTY(Category = "Player", VisibleAnywhere)
	EPondMovementState PreviousMovementState;
	default PreviousMovementState = EPondMovementState::Run;

	UPROPERTY(Category = "Hero | Info", VisibleAnywhere)
	FText HeroName;
	default HeroName = FText::FromString("Hero");

	float GetHealthAttribute() override property
	{
		return Attributes.Health.CurrentValue;
	}

	float GetShieldAttribute() override property
	{
		return Attributes.Shield.CurrentValue;
	}

	UPROPERTY(Category = "Hero | Debug | Visuals")
	UParticleSystem DeathEffect;

	UPROPERTY(NotVisible, BlueprintReadOnly)
	UAbilitySystemComponent AbilitySystem;
	
	UPROPERTY(NotVisible, BlueprintReadOnly)
	UPondPlayerGASAttributes Attributes;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		AbilitySystem = Pond::GetPondPlayerStateBase().AbilitySystem;
		Attributes = Pond::GetPondPlayerStateBase().Attributes;	
	}

	void ApplyDamage(float Damage) override
	{
		float HealthDamage;
		float ShieldDamage;
		CalculateDamageTaken(HealthAttribute, ShieldAttribute, Damage, HealthDamage, ShieldDamage);

		FGameplayEffectSpecHandle HealthHandle = AbilitySystem.MakeOutgoingSpec(UGE_Damage_Health, 1, FGameplayEffectContextHandle());
		if (HealthHandle.IsValid() && GetHealthAttribute() > 0)
		{
			HealthHandle.Spec.SetByCallerMagnitude(GameplayTags::Data_Damage_Health, -HealthDamage);
			AbilitySystem.ApplyGameplayEffectSpecToSelf(HealthHandle);

			Print(f"Applied {Math::RoundToInt(HealthDamage)} HEALTH damage to {HeroName}", 1, FLinearColor::DPink);
		}

		FGameplayEffectSpecHandle ShieldHandle = AbilitySystem.MakeOutgoingSpec(UGE_Damage_Shield, 1, FGameplayEffectContextHandle());
		if (ShieldHandle.IsValid() && GetShieldAttribute() > 0)
		{
			ShieldHandle.Spec.SetByCallerMagnitude(GameplayTags::Data_Damage_Shield, -ShieldDamage);
			AbilitySystem.ApplyGameplayEffectSpecToSelf(ShieldHandle);

			if (ShieldAttribute <= 0)
			{
				OnShieldDepleted.Broadcast();
			}

			Print(f"Applied {Math::RoundToInt(ShieldDamage)} Shield damage to {HeroName}", 1, FLinearColor::Teal);
		}
	}

	void ApplyHealing(float HealAmount) override
	{
		if (HealthAttribute >= Attributes.MaxHealth.BaseValue)
			return;

		FGameplayEffectSpecHandle HealHandle = AbilitySystem.MakeOutgoingSpec(UGE_Restore_Health, 1, FGameplayEffectContextHandle());
		if (HealHandle.IsValid())
		{
			HealHandle.Spec.SetByCallerMagnitude(GameplayTags::Data_Damage_Health, HealAmount);
			AbilitySystem.ApplyGameplayEffectSpecToSelf(HealHandle);

			Print(f"Applied {HealAmount} health healing to {HeroName}", 5.0f, FLinearColor::Green);
		}
	}

	void ApplyShield(float NewAmount) override
	{
		float ShieldAmount = NewAmount;

		FGameplayEffectSpecHandle ShieldHandle = AbilitySystem.MakeOutgoingSpec(UGE_Override_Shield, 1, FGameplayEffectContextHandle());
		if (ShieldHandle.IsValid())
		{
			ShieldHandle.Spec.SetByCallerMagnitude(GameplayTags::Data_Damage_Shield, ShieldAmount);
			AbilitySystem.ApplyGameplayEffectSpecToSelf(ShieldHandle);

			Print(f"Applied {ShieldAmount} Shield to {HeroName}", 1.0f, FLinearColor::LucBlue);
		}
	}

	void Death() override
	{
		if (GameplayTags.HasTag(GameplayTags::Character_State_Dead))
			return;
		else
			GameplayTags.AddTag(GameplayTags::Character_State_Dead);

		FGameplayEffectQuery Query;
		for (FActiveGameplayEffectHandle Handle : AbilitySystem.GetActiveEffects(Query))
		{
			AbilitySystem.RemoveActiveGameplayEffect(Handle);
		}

		Gameplay::SpawnEmitterAtLocation(DeathEffect, ActorLocation, ActorRotation, FVector(1.5f), true);
		SetActorHiddenInGame(true);
		SetActorEnableCollision(false);

		OnDeath.Broadcast(DeathInfo);
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