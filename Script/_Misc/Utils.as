namespace Math
{
	UFUNCTION(BlueprintPure)
	float ToMeters(float DistanceInCm)
	{
		return DistanceInCm / 100.0f;
	}
}

namespace AbilitySystem
{
	UFUNCTION(BlueprintPure)
	UAngelscriptAbilitySystemComponent GetAngelscriptAbilitySystemComponent(AActor Actor)
	{
		return Cast<UAngelscriptAbilitySystemComponent>(AbilitySystem::GetAbilitySystemComponent(Actor));
	}
}