// Fill out your copyright notice in the Description page of Project Settings.


#include "PondPlayerState.h"


void APondPlayerState::BeginPlay()
{
	Super::BeginPlay();
}

void APondPlayerState::PostNetInit()
{
	Super::PostNetInit();
	BP_PostNetInit();
}
