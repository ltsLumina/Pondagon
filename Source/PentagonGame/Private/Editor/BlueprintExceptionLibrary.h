#pragma once

#include "Kismet/BlueprintFunctionLibrary.h"
#include "BlueprintExceptionLibrary.generated.h"

UCLASS()
class PONDAGON_API UBlueprintExceptionLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	UFUNCTION(ScriptCallable)
	static FString GetFormattedCallStack();
	
	UFUNCTION(ScriptCallable)
	static FString GetCallStack();
};
