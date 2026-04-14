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
		auto Hero = Cast<APondHero>(Pawn);
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