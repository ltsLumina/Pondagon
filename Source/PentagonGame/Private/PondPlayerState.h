// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerState.h"
#include "PondPlayerState.generated.h"

/**
 * 
 */
UCLASS(Blueprintable, BlueprintType)
class PONDAGON_API APondPlayerState : public APlayerState
{
	GENERATED_BODY()
	
public:
	virtual void BeginPlay() override;
	
	virtual void PostNetInit() override;
	UFUNCTION(BlueprintCallable, BlueprintImplementableEvent)
	void BP_PostNetInit();
};
