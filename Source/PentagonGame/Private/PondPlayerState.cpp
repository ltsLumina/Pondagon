// Fill out your copyright notice in the Description page of Project Settings.


#include "PondPlayerState.h"

#include "AngelscriptAbilitySystemComponent.h"

APondPlayerState::APondPlayerState(const FObjectInitializer& ObjectInitializer) : Super(ObjectInitializer)
{
	AbilitySystem = CreateDefaultSubobject<UAngelscriptAbilitySystemComponent>(TEXT("AbilitySystem"));
	AbilitySystem->SetIsReplicated(true);
	
	// Mixed mode means we only are replicated the GEs to ourself, not the GEs to simulated proxies. If another PondPlayerState (Hero) receives a GE,
	// we won't be told about it by the Server. Attributes, GameplayTags, and GameplayCues will still replicate to us.
	AbilitySystem->SetReplicationMode(EGameplayEffectReplicationMode::Mixed);
	
	// Set PlayerState's NetUpdateFrequency to the same as the Character.
	// Default is very low for PlayerStates and introduces perceived lag in the ability system.
	// 100 is probably way too high for a shipping game, you can adjust to fit your needs.
	NetUpdateFrequency = 100.0f;
}

void APondPlayerState::BeginPlay()
{
	Super::BeginPlay();
}

void APondPlayerState::PostNetInit()
{
	Super::PostNetInit();
	BP_PostNetInit();
}

UAbilitySystemComponent* APondPlayerState::GetAbilitySystemComponent() const
{
	return AbilitySystem;
}

void APondPlayerState::GetOwnedGameplayTags(FGameplayTagContainer& TagContainer) const
{
	if(AbilitySystem)
	{
		AbilitySystem->GetOwnedGameplayTags(TagContainer);
	}
}