// Copyright 'Team PONDAGON' - All rights reserved.

#pragma once

#include "CoreMinimal.h"
#include "AngelscriptGASCharacter.h"

#include "EnemyBase.generated.h"

UCLASS()
class PENTAGONGAME_API AEnemyBase : public AAngelscriptGASCharacter
{
	GENERATED_BODY()

public:
	// Sets default values for this character's properties
	AEnemyBase();

protected:
	// Called when the game starts or when spawned
	virtual void BeginPlay() override;

public:
	// Called every frame
	virtual void Tick(float DeltaTime) override;

	// Called to bind functionality to input
	virtual void SetupPlayerInputComponent(class UInputComponent* PlayerInputComponent) override;
};
