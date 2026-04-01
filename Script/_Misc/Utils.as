namespace Math
{
	UFUNCTION(BlueprintPure)
	float ToMeters(float DistanceInCm)
	{
		return DistanceInCm / 100.0f;
	}
}