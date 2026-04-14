// Fill out your copyright notice in the Description page of Project Settings.


#include "PondPlayerState.h"

#include "AngelscriptAbilitySystemComponent.h"

APondPlayerState::APondPlayerState(const FObjectInitializer& ObjectInitializer) : Super(ObjectInitializer)
{
	AbilitySystem = CreateDefaultSubobject<UAngelscriptAbilitySystemComponent>(TEXT("AbilitySystem"));
	AbilitySystem->SetIsReplicated(true);
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