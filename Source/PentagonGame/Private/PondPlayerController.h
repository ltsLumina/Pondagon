// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "PondPlayerController.generated.h"

/**
 * 
 */
UCLASS(Blueprintable, BlueprintType)
class PONDAGON_API APondPlayerController : public APlayerController
{
	GENERATED_BODY()

public:
	/**
	 * <summary>
	 * Server-side possession. Use for server init that requires a pawn.
	 * </summary>
	 * <param name="InPawn"></param>
	 */
	virtual void OnPossess(APawn* InPawn) override;
	UFUNCTION(BlueprintCallable, BlueprintImplementableEvent)
	void BP_OnPossess(APawn* InPawn);

	virtual void AcknowledgePossession(class APawn* P) override;
	/**
	 * <summary>
	 * Most reliable client hook for input setup. LocalPlayer and EnhancedInput subsystems are valid here.
	 * </summary>
	 * <param name="P"></param>
	 */
	UFUNCTION(BlueprintCallable, BlueprintImplementableEvent)
	void BP_AcknowledgePossession(class APawn* P);

	/**
	 * <summary>
	 * PlayerState arrives late — use as fallback alongside AcknowledgePossession.
	 * </summary>
	 */
	virtual void OnRep_PlayerState() override;
	UFUNCTION(BlueprintCallable, BlueprintImplementableEvent)
	void BP_OnRep_PlayerState();
	
	DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnPlayerStateReady, APlayerState*, PlayerState);
	
	UPROPERTY(BlueprintAssignable)
	FOnPlayerStateReady OnPlayerStateReady;
};
