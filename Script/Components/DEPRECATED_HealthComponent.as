event void FOnHealthChanged(float NewHealth);
event void FOnDeath();

UCLASS(Deprecated, Meta=(DeprecationMessage="This class shall not be used in this project."))
class UHealthComponent : UActorComponent
{
    UPROPERTY(Category = "State")
    FGameplayTagContainer GameplayTagContainer;
    
	UPROPERTY(Category = "Health")
	float CurrentHealth;
	default CurrentHealth = MaxHealth;

	UPROPERTY(Category = "Health")
	float MaxHealth = 100;

	UPROPERTY(Category = "Health | Shield")
	float CurrentShields = 25;

	UPROPERTY(Category = "Health | Shield")
	float MaxShields = 25;


	UPROPERTY(Category = "Events")
	FOnHealthChanged OnHealthChanged;

	UPROPERTY(Category = "Events")
	FOnDeath OnDeath;

	UFUNCTION(Category = "Health")
	void TakeDamage(float Damage, bool&out IsShieldBreak)
	{
		float OverkillDamage = 0;

		if (CurrentShields > 0)
		{
			float NewShields = CurrentShields - Damage;
			CurrentShields = NewShields;

			if (CurrentShields <= 0)
			{
				OverkillDamage = Math::Abs(CurrentShields);
				CurrentShields = 0;

				IsShieldBreak = true;
			}
		}
		else
		{
			CurrentHealth -= Damage;

			if (CurrentHealth <= 0)
			{
				CurrentHealth = 0;
                GameplayTagContainer.AddTag(FGameplayTag::RequestGameplayTag(n"Runner.State.IsDead"));
                
                OnDeath.Broadcast();
                Print(f"Player died!", 3.0f, FLinearColor::Red);
                return;
			}
		}

		if (OverkillDamage > 0) // Apply any overkill damage
			CurrentHealth -= OverkillDamage;

		Print(f"New Shields: {CurrentShields}\nNew Health: {CurrentHealth}");
		OnHealthChanged.Broadcast(CurrentHealth);
	}

	UFUNCTION()
	void Heal(float Health)
	{
		CurrentHealth += Health;
		OnHealthChanged.Broadcast(CurrentHealth);
	}
};