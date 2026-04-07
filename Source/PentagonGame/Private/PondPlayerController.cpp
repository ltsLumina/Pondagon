// Fill out your copyright notice in the Description page of Project Settings.


#include "PondPlayerController.h"

void APondPlayerController::OnPossess(APawn* InPawn)
{
	Super::OnPossess(InPawn);
	BP_OnPossess(InPawn);
}

void APondPlayerController::AcknowledgePossession(class APawn* P)
{
	Super::AcknowledgePossession(P);
	BP_AcknowledgePossession(P);
}

void APondPlayerController::OnRep_PlayerState()
{
	Super::OnRep_PlayerState();
	BP_OnRep_PlayerState();
	OnPlayerStateReady.Broadcast(PlayerState);
}
