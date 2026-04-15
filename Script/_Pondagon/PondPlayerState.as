class AScriptPondPlayerState : APondPlayerState
{
	UPROPERTY(NotVisible, BlueprintReadOnly)
	UInventoryComponent InventoryComponent;
	default InventoryComponent = UInventoryComponent::Get(this);
	//~Components

	UPROPERTY(Category = "Team", BlueprintReadOnly)
	int RespawnTokens = 1;

	UFUNCTION(BlueprintOverride)
	void ConstructionScript()
	{
		InventoryComponent = UInventoryComponent::Get(this);
	}

	bool HasInitialized;

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		if (Pawn != nullptr && !HasInitialized)
		{
			Initialize();
			HasInitialized = true;
		}
	}

	void Initialize()
	{
		auto Hero = Cast<AScriptPondHero>(Pawn);
		check(Hero != nullptr);
		check(!Hero.Definition.StartingData.IsEmpty());

		InventoryComponent.Initialize();
	}

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		AbilitySystem.OnAttributeChanged.AddUFunction(this, n"HealthChanged");
		AbilitySystem.OnAttributeChanged.AddUFunction(this, n"MaxHealthChanged");
		AbilitySystem.OnAttributeChanged.AddUFunction(this, n"MoveSpeedChanged");
		AbilitySystem.OnAttributeChanged.AddUFunction(this, n"MaxMoveSpeedChanged");

#if EDITOR
		float SpawnHealth = AbilitySystem.GetAttributeCurrentValue(UPlayerAttributes, UPlayerAttributes::HealthName);
		float SpawnShield = AbilitySystem.GetAttributeCurrentValue(UPlayerAttributes, UPlayerAttributes::ShieldName);
		Print(f"Player '{ActorNameOrLabel}' has spawned with {SpawnHealth} health and {SpawnShield} Shield.", 1.5f, FLinearColor::Green);
#endif
	}

	UFUNCTION(NotBlueprintCallable)
	private void HealthChanged(const FAngelscriptModifiedAttribute&in AttributeChangeData)
	{
	}

	UFUNCTION(NotBlueprintCallable)
	private void MaxHealthChanged(const FAngelscriptModifiedAttribute&in AttributeChangeData)
	{
	}

	UFUNCTION(NotBlueprintCallable)
	private void MoveSpeedChanged(const FAngelscriptModifiedAttribute&in AttributeChangeData)
	{
	}

	UFUNCTION(NotBlueprintCallable)
	private void MaxMoveSpeedChanged(const FAngelscriptModifiedAttribute&in AttributeChangeData)
	{
	}
};

namespace Pond
{
	UFUNCTION(BlueprintPure)
	AScriptPondPlayerState GetPondPlayerStateBase()
	{
		return Cast<AScriptPondPlayerState>(Gameplay::GetPlayerState(0));
	}
}