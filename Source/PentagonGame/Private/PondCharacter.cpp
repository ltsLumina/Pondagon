// Fill out your copyright notice in the Description page of Project Settings.


#include "PondCharacter.h"


// Sets default values
APondCharacter::APondCharacter()
{
	// Set this character to call Tick() every frame.  You can turn this off to improve performance if you don't need it.
	PrimaryActorTick.bCanEverTick = true;
}

// Called when the game starts or when spawned
void APondCharacter::BeginPlay()
{
	Super::BeginPlay();
}

// Called every frame
void APondCharacter::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
}

// Called to bind functionality to input
void APondCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
	Super::SetupPlayerInputComponent(PlayerInputComponent);
}

// Netcode Init

void APondCharacter::PossessedBy(AController* NewController)
{
	Super::PossessedBy(NewController);
	BP_PossessedBy(NewController);
}

void APondCharacter::OnRep_PlayerState()
{
	Super::OnRep_PlayerState();
	BP_OnRep_PlayerState();
}

void APondCharacter::OnRep_Controller()
{
	Super::OnRep_Controller();
	BP_OnRep_Controller();
}

