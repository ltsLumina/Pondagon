// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "AbilitySystemInterface.h"
#include "AngelscriptAbilitySystemComponent.h"

#include "GameFramework/PlayerState.h"
#include "PondPlayerState.generated.h"

/**
 * 
 */
UCLASS(Blueprintable, BlueprintType)
class PENTAGONGAME_API APondPlayerState : public APlayerState, public IAbilitySystemInterface, public IGameplayTagAssetInterface
{
	GENERATED_BODY()
	
public:
	APondPlayerState(const FObjectInitializer& ObjectInitializer = FObjectInitializer::Get());
	
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "AbilitySystem")
	TObjectPtr<UAngelscriptAbilitySystemComponent> AbilitySystem;
	
	virtual void BeginPlay() override;
	
	virtual void PostNetInit() override;
	UFUNCTION(BlueprintCallable, BlueprintImplementableEvent)
	void BP_PostNetInit();

	/************************************************************************/
	/* IAbilitySystemInterface                                              */
	/************************************************************************/
	virtual UAbilitySystemComponent* GetAbilitySystemComponent() const override;

	/************************************************************************/
	/* IGameplayTagAssetInterface                                           */
	/************************************************************************/
	virtual void GetOwnedGameplayTags(FGameplayTagContainer& TagContainer) const override;
};
