class AScriptEnemyBase : AScriptPondCharacter
{
	default AbilitySystem.SetReplicationMode(EGameplayEffectReplicationMode::Minimal);

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		Attributes = Cast<UEnemyAttributes>(AbilitySystem.RegisterAttributeSet(UEnemyAttributes));
	}

	UFUNCTION(BlueprintOverride)
	void Possessed(AController NewController)
	{
		check(!Definition.StartingData.IsEmpty());

		Attributes = Cast<UEnemyAttributes>(AbilitySystem.RegisterAttributeSet(UEnemyAttributes));

		AbilitySystem.InitAbilityActorInfo(NewController, this);
		for (auto& Data : Definition.StartingData)
		{			
			//AbilitySystem.RegisterAttributeSet(Data.Key);
			AbilitySystem.InitStats(Data.Key, Data.Value);
		}

#if EDITOR
		float SpawnHealth = Health;
		float SpawnShield = Shield;
		Print(f"Enemy '{ActorNameOrLabel}' has spawned with {SpawnHealth} health and {SpawnShield} Shield.", 1.5f, FLinearColor::Green);
#endif
	}

	UFUNCTION(BlueprintOverride)
	void PointDamage(float Damage, const UDamageType DamageType, FVector HitLocation, FVector HitNormal,
					 UPrimitiveComponent HitComponent, FName BoneName, FVector ShotFromDirection,
					 AController InstigatedBy, AActor DamageCauser, FHitResult HitInfo)
	{
		Print("hit enemy!", 1.0f, FLinearColor::Yellow);
	}
};

UFUNCTION(BlueprintPure)
AScriptEnemyBase AsEnemy(AScriptPondCharacter PondCharacter)
{
	return Cast<AScriptEnemyBase>(PondCharacter);
}
